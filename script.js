class OllamaChat {
    constructor() {
        // Settings / vars 
        this.apiUrl = localStorage.getItem('ollamaApiUrl') || '';
        this.currentModel = localStorage.getItem('currentModel') || '';
        this.temperature = parseFloat(localStorage.getItem('temperature')) || 0.7;
        this.maxTokens = parseInt(localStorage.getItem('maxTokens')) || 2048;
        this.streamResponses = localStorage.getItem('streamResponses') !== 'false';
        this.autoScroll = localStorage.getItem('autoScroll') !== 'false';
        this.theme = localStorage.getItem('theme') || 'dark';

        this.currentChatId = 'chat_' + Date.now();
        this.chats = JSON.parse(localStorage.getItem('chats') || '{}');
        this.isGenerating = false;
        this.abortController = null;
        this.isResizing = false;

        this.init();
        this.testConnection();
    }

    // Connection test via request - response 
    async testConnection() {
        console.log('Testing connection to:', this.apiUrl || '/api');
        try {
            // Use correct API path
            const apiPath = this.getApiPath('/api/tags');
            const response = await fetch(apiPath);
            console.log('Connection response status:', response.status);

            if (response.ok) {
                const data = await response.json();
                console.log('Available models:', data.models);

                if (data.models && data.models.length > 0) {
                    const availableModel = data.models[0].name;
                    this.currentModel = availableModel;
                    localStorage.setItem('currentModel', availableModel);
                    this.updateModelDisplay();
                }
                return true;
            } else {
                console.error('Connection failed with status:', response.status);
                this.showConnectionError();
                return false;
            }
        } catch (error) {
            console.error("Cannot connect to Ollama:", error);
            this.showConnectionError();
            return false;
        }
    }

    // Helper function to build correct API paths
    getApiPath(endpoint) {
        if (this.apiUrl) {
            return `${this.apiUrl}${endpoint}`;
        } else {
            return endpoint;
        }
    }

    showConnectionError() {
        document.getElementById('connectionStatus').textContent = 'Disconnected';
        document.getElementById('connectionStatus').style.color = 'var(--error-color)';
        document.querySelector('.status-indicator').classList.remove('active');
        document.getElementById('currentModelDisplay').textContent = 'Model not connected';
        document.getElementById('currentModelDisplay').style.color = 'var(--error-color)';

        // Show error message in chat
        const chatMessages = document.getElementById('chatMessages');
        const welcomeMessage = document.querySelector('.welcome-message');
        if (welcomeMessage) {
            welcomeMessage.innerHTML = `
                <h3><i class="fas fa-exclamation-triangle"></i> Connection Error</h3>
                <p>Cannot connect to Ollama API at: ${this.apiUrl || '/api'}</p>
                <p>Please make sure:</p>
                <ol style="text-align: left; margin: 20px auto; max-width: 500px;">
                    <li>Ollama is installed and running</li>
                    <li>Run <code>ollama serve</code> in terminal</li>
                    <li>The API URL is correct in Settings</li>
                    <li>Check if Ollama is running: <code>curl ${this.getApiPath('/api/tags')}</code></li>
                </ol>
                <button onclick="window.chatApp.showSettings()" style="margin-top: 20px; padding: 10px 20px; background: var(--accent-color); border: none; border-radius: 6px; color: var(--text-color); cursor: pointer;">
                    <i class="fas fa-cog"></i> Open Settings
                </button>
            `;
        }
    }

    init() {
        this.applyTheme();
        this.loadChats();
        this.setupEventListeners();
        this.setupResizer();
        this.updateModelDisplay();

        const urlParams = new URLSearchParams(window.location.search);
        const chatId = urlParams.get('chat');
        if (chatId && this.chats[chatId]) {
            this.loadChat(chatId);
        }
    }

    // Resize 
    setupResizer() {
        const resizer = document.getElementById('sidebarResizer');
        const sidebar = document.querySelector('.sidebar');
        
        // Don't enable resizer on mobile
        if (window.innerWidth > 768) {
            let startX, startWidth;

            resizer.addEventListener('mousedown', (e) => {
                this.isResizing = true;
                startX = e.clientX;
                startWidth = parseInt(getComputedStyle(sidebar).width, 10);
                document.body.style.cursor = 'col-resize';
                document.body.style.userSelect = 'none';

                const onMouseMove = (e) => {
                    if (!this.isResizing) return;
                    const width = startWidth + e.clientX - startX;
                    if (width >= 200 && width <= 500) {
                        sidebar.style.width = `${width}px`;
                    }
                };

                const onMouseUp = () => {
                    this.isResizing = false;
                    document.body.style.cursor = '';
                    document.body.style.userSelect = '';
                    document.removeEventListener('mousemove', onMouseMove);
                    document.removeEventListener('mouseup', onMouseUp);
                };

                document.addEventListener('mousemove', onMouseMove);
                document.addEventListener('mouseup', onMouseUp);
            });
        }
    }

    updateModelDisplay() {
        document.getElementById('currentModelDisplay').textContent = `Powered by ${this.formatModelName(this.currentModel)}`;
        document.getElementById('currentModelDisplay').style.color = '';
    }

    // applies theme
    applyTheme() {
        document.body.classList.remove('light-theme');
        if (this.theme === 'light') {
            document.body.classList.add('light-theme');
        }
        document.getElementById('theme').value = this.theme;
    }

    setupEventListeners() {
        // Mobile sidebar toggle
        document.querySelector('.sidebar-header').addEventListener('click', (e) => {
            if (window.innerWidth <= 768) {
                const sidebar = document.querySelector('.sidebar');
                sidebar.classList.toggle('expanded');
                e.stopPropagation();
            }
        });

        // Close sidebar when clicking outside on mobile
        document.addEventListener('click', (e) => {
            if (window.innerWidth <= 768) {
                const sidebar = document.querySelector('.sidebar');
                if (sidebar.classList.contains('expanded') && 
                    !sidebar.contains(e.target) && 
                    !e.target.closest('.sidebar')) {
                    sidebar.classList.remove('expanded');
                }
            }
        });

        document.getElementById('sendBtn').addEventListener('click', () => this.sendMessage());
        document.getElementById('messageInput').addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                this.sendMessage();
            }
        });

        // Buttons in html 
        document.getElementById('stopBtn').addEventListener('click', () => this.stopGeneration());
        document.getElementById('newChatBtn').addEventListener('click', () => this.newChat());
        document.getElementById('clearChatBtn').addEventListener('click', () => this.clearChat());
        document.getElementById('copyChatBtn').addEventListener('click', () => this.copyChat());
        document.getElementById('exportChatBtn').addEventListener('click', () => this.exportFullChat());
        document.getElementById('clearAllChatsBtn').addEventListener('click', () => this.clearAllChats());

        document.getElementById('settingsBtn').addEventListener('click', () => this.showSettings());
        document.getElementById('saveSettings').addEventListener('click', () => this.saveSettings());
        document.querySelectorAll('.close-modal').forEach(btn => {
            btn.addEventListener('click', () => this.hideSettings());
        });

        document.getElementById('temperature').addEventListener('input', (e) => {
            document.getElementById('tempValue').textContent = e.target.value;
        });

        const textarea = document.getElementById('messageInput');
        textarea.addEventListener('input', () => {
            textarea.style.height = 'auto';
            textarea.style.height = Math.min(textarea.scrollHeight, 200) + 'px';
        });

        setInterval(() => this.updateConnectionStatus(), 30000);
        
        // Handle window resize
        window.addEventListener('resize', () => {
            if (window.innerWidth > 768) {
                const sidebar = document.querySelector('.sidebar');
                sidebar.classList.remove('expanded');
            }
        });
    }

    // connection status 
    async updateConnectionStatus() {
        try {
            const apiPath = this.getApiPath('/api/tags');
            const response = await fetch(apiPath);
            if (response.ok) {
                document.getElementById('connectionStatus').textContent = 'Connected';
                document.getElementById('connectionStatus').style.color = '';
                document.querySelector('.status-indicator').classList.add('active');
                return true;
            }
        } catch (error) {
            console.error('Connection check failed:', error);
        }
        document.getElementById('connectionStatus').textContent = 'Disconnected';
        document.getElementById('connectionStatus').style.color = 'var(--error-color)';
        document.querySelector('.status-indicator').classList.remove('active');
        return false;
    }

    async sendMessage() {
        const input = document.getElementById('messageInput');
        const message = input.value.trim();

        if (!message || this.isGenerating) return;

        // Close sidebar on mobile when sending message
        if (window.innerWidth <= 768) {
            document.querySelector('.sidebar').classList.remove('expanded');
        }

        this.addMessage('user', message);
        input.value = '';
        input.style.height = 'auto';

        const assistantMessageId = 'msg_' + Date.now();
        const assistantMessageDiv = this.createMessageElement('assistant', '', assistantMessageId);

        try {
            if (this.streamResponses) {
                await this.streamResponse(message, assistantMessageDiv);
            } else {
                await this.generateResponse(message, assistantMessageDiv);
            }
        } catch (error) {
            console.error('Error sending message:', error);
            const messageContent = assistantMessageDiv.querySelector('.message-content');
            messageContent.innerHTML = `
                <span style="color: var(--error-color)">Error: ${error.message}</span>
                <br>
                <small>Check console for details and ensure Ollama is running.</small>
            `;
        }

        this.saveCurrentChat();
    }

    async streamResponse(prompt, messageElement) {
        this.isGenerating = true;
        this.abortController = new AbortController();
        document.getElementById('stopBtn').disabled = false;

        const messageContent = messageElement.querySelector('.message-content');
        messageContent.innerHTML = '<div class="typing-indicator"><span></span><span></span><span></span></div>';

        const apiPath = this.getApiPath('/api/generate');
        console.log('Sending request to:', apiPath);
        console.log('Request payload:', {
            model: this.currentModel,
            prompt: prompt,
            stream: true,
            options: {
                temperature: this.temperature,
                num_predict: this.maxTokens
            }
        });

        try {
            const response = await fetch(apiPath, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                },
                body: JSON.stringify({
                    model: this.currentModel,
                    prompt: prompt,
                    stream: true,
                    options: {
                        temperature: this.temperature,
                        num_predict: this.maxTokens
                    }
                }),
                signal: this.abortController.signal
            });

            console.log('Response status:', response.status);

            if (!response.ok) {
                const errorText = await response.text();
                console.error('API error response:', errorText);
                throw new Error(`API request failed: ${response.status} ${response.statusText}`);
            }

            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let fullResponse = '';

            messageContent.innerHTML = '';

            while (true) {
                const { done, value } = await reader.read();
                if (done) break;

                const chunk = decoder.decode(value);
                console.log('Received chunk:', chunk);
                const lines = chunk.split('\n').filter(line => line.trim());

                for (const line of lines) {
                    try {
                        const data = JSON.parse(line);
                        if (data.response) {
                            fullResponse += data.response;
                            messageContent.innerHTML = this.formatResponse(fullResponse);

                            if (this.autoScroll) {
                                messageElement.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
                            }
                        } else if (data.error) {
                            throw new Error(data.error);
                        }
                    } catch (e) {
                        console.error('Error parsing chunk:', e, 'Line:', line);
                    }
                }
            }

            this.addMessageActions(messageElement);
            this.saveCurrentChat();

        } catch (error) {
            if (error.name === 'AbortError') {
                messageContent.innerHTML += '<br><em>Generation stopped by user.</em>';
            } else {
                console.error('Stream error:', error);
                messageContent.innerHTML = '<span style="color: var(--error-color)">Error: ' + error.message + '</span>';
                messageContent.innerHTML += '<br><small>Check if Ollama is running: ollama serve</small>';
            }
        } finally {
            this.isGenerating = false;
            document.getElementById('stopBtn').disabled = true;
            this.abortController = null;
        }
    }

    async generateResponse(prompt, messageElement) {
        this.isGenerating = true;
        document.getElementById('stopBtn').disabled = false;

        const messageContent = messageElement.querySelector('.message-content');
        messageContent.innerHTML = '<div class="typing-indicator"><span></span><span></span><span></span></div>';

        const apiPath = this.getApiPath('/api/generate');
        console.log('Sending non-stream request to:', apiPath);

        try {
            const response = await fetch(apiPath, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Accept': 'application/json'
                },
                body: JSON.stringify({
                    model: this.currentModel,
                    prompt: prompt,
                    stream: false,
                    options: {
                        temperature: this.temperature,
                        num_predict: this.maxTokens
                    }
                })
            });

            console.log('Response status:', response.status);

            if (!response.ok) {
                const errorText = await response.text();
                console.error('API error response:', errorText);
                throw new Error(`API request failed: ${response.status} ${response.statusText}`);
            }

            const data = await response.json();
            console.log('Response data:', data);

            if (data.response) {
                messageContent.innerHTML = this.formatResponse(data.response);
            } else if (data.error) {
                throw new Error(data.error);
            } else {
                throw new Error('No response received from Ollama');
            }

            this.addMessageActions(messageElement);
            this.saveCurrentChat();

        } catch (error) {
            console.error('Generate error:', error);
            messageContent.innerHTML = '<span style="color: var(--error-color)">Error: ' + error.message + '</span>';
            messageContent.innerHTML += '<br><small>Check if Ollama is running: ollama serve</small>';
        } finally {
            this.isGenerating = false;
            document.getElementById('stopBtn').disabled = true;
        }
    }

    async regenerateMessage(messageId) {
        const messageElement = document.getElementById(messageId);
        if (!messageElement) return;

        const allMessages = Array.from(document.querySelectorAll('.message'));
        const currentIndex = allMessages.findIndex(msg => msg.id === messageId);

        if (currentIndex > 0) {
            const userMessageElement = allMessages[currentIndex - 1];
            if (userMessageElement.classList.contains('user')) {
                const userPrompt = userMessageElement.querySelector('.message-content').textContent;

                messageElement.remove();

                const newMessageId = 'msg_' + Date.now();
                const newMessageDiv = this.createMessageElement('assistant', '', newMessageId);

                try {
                    if (this.streamResponses) {
                        await this.streamResponse(userPrompt, newMessageDiv);
                    } else {
                        await this.generateResponse(userPrompt, newMessageDiv);
                    }
                } catch (error) {
                    console.error('Regeneration error:', error);
                }

                this.saveCurrentChat();
            }
        }
    }

    // UI Functions 

    deleteChat(chatId, event) {
        event.stopPropagation();

        if (confirm('Are you sure you want to delete this chat?')) {
            delete this.chats[chatId];

            if (chatId === this.currentChatId) {
                this.newChat();
            }

            localStorage.setItem('chats', JSON.stringify(this.chats));
            this.loadChats();
        }
    }

    clearAllChats() {
        if (Object.keys(this.chats).length === 0) {
            alert('No chats to clear.');
            return;
        }

        if (confirm('Are you sure you want to delete ALL chat history? This cannot be undone.')) {
            this.chats = {};
            localStorage.setItem('chats', JSON.stringify(this.chats));
            this.newChat();
            this.loadChats();
        }
    }

    // Export chat
    /*
    ========================================
    LOCAL AI CHAT EXPORT
    ========================================

    Model: codellama:7b
    Date: 1/11/2026, 5:16:53 PM
    Chat ID: chat_1768144484552
    Chat Title: whats 2 + 2
    Messages: 2
    Temperature: 0.7
    Max Tokens: 2048
    ========================================

    [1] USER
    Time: 1/11/2026, 5:14:48 PM
    Message ID: msg_1768144488583
    ----------------------------------------
    whats 2 + 2

    [2] USER
    Time: 1/11/2026, 5:15:19 PM
    Message ID: msg_1768144519600
    ----------------------------------------
    write a simple python script that calculates n powers , example 5^2 = 5 * 5 = 25
    */

    async exportFullChat() {
        const chat = this.chats[this.currentChatId];
        if (!chat || chat.messages.length === 0) {
            alert('No messages to export.');
            return;
        }

        let chatText = `========================================\n`;
        chatText += `LOCAL AI CHAT EXPORT\n`;
        chatText += `========================================\n\n`;
        chatText += `Model: ${this.currentModel}\n`;
        chatText += `Date: ${new Date().toLocaleString()}\n`;
        chatText += `Chat ID: ${chat.id}\n`;
        chatText += `Chat Title: ${chat.title}\n`;
        chatText += `Messages: ${chat.messages.length}\n`;
        chatText += `Temperature: ${this.temperature}\n`;
        chatText += `Max Tokens: ${this.maxTokens}\n`;
        chatText += `========================================\n\n`;

        chat.messages.forEach((msg, index) => {
            chatText += `[${index + 1}] ${msg.role === 'user' ? 'USER' : 'AI'}\n`;
            chatText += `Time: ${new Date(msg.timestamp).toLocaleString()}\n`;
            chatText += `Message ID: ${msg.id}\n`;
            chatText += `----------------------------------------\n`;
            chatText += `${msg.content}\n\n`;
        });

        const blob = new Blob([chatText], { type: 'text/plain' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `local_ai_chat_${this.currentChatId}_${Date.now()}.txt`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    // Stop 
    stopGeneration() {
        if (this.abortController) {
            this.abortController.abort();
        }
        this.isGenerating = false;
        document.getElementById('stopBtn').disabled = true;
    }

    formatResponse(text) {
        text = text.replace(/```(\w+)?\n([\s\S]*?)```/g, (match, lang, code) => {
            const language = lang || 'text';
            return `<div class="code-block">
                <div class="code-header">
                    <span>${language}</span>
                    <button class="copy-code-btn" onclick="copyToClipboard(this)">Copy</button>
                </div>
                <pre><code class="language-${language}">${this.escapeHtml(code.trim())}</code></pre>
            </div>`;
        });

        text = text.replace(/`([^`]+)`/g, '<code>$1</code>');
        text = text.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" rel="noopener noreferrer">$1</a>');

        text = text.split('\n\n').map(para => {
            if (para.trim()) {
                return `<p>${para.replace(/\n/g, '<br>')}</p>`;
            }
            return '';
        }).join('');

        return text;
    }

    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    addMessage(role, content) {
        const messageId = 'msg_' + Date.now();
        const messageDiv = this.createMessageElement(role, content, messageId);

        if (!this.chats[this.currentChatId]) {
            this.chats[this.currentChatId] = {
                id: this.currentChatId,
                title: content.substring(0, 50) + (content.length > 50 ? '...' : ''),
                messages: [],
                created: Date.now(),
                model: this.currentModel
            };
        }

        this.chats[this.currentChatId].messages.push({
            id: messageId,
            role,
            content,
            timestamp: Date.now()
        });
    }

    createMessageElement(role, content, messageId) {
        const chatMessages = document.getElementById('chatMessages');

        const welcomeMessage = document.querySelector('.welcome-message');
        if (welcomeMessage) {
            welcomeMessage.remove();
        }

        const messageDiv = document.createElement('div');
        messageDiv.className = `message ${role}`;
        messageDiv.id = messageId;

        const avatarIcon = role === 'user' ? 'fas fa-user' : 'fas fa-robot';
        const avatarLabel = role === 'user' ? 'You' : 'AI';

        messageDiv.innerHTML = `
            <div class="message-header">
                <div class="avatar ${role}">
                    <i class="${avatarIcon}"></i>
                </div>
                <h4>${avatarLabel}</h4>
                <span class="message-time">${new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</span>
            </div>
            <div class="message-content">${role === 'user' ? this.escapeHtml(content) : this.formatResponse(content)}</div>
        `;

        chatMessages.appendChild(messageDiv);

        if (this.autoScroll) {
            messageDiv.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
        }

        return messageDiv;
    }

    addMessageActions(messageElement) {
        const actionsDiv = document.createElement('div');
        actionsDiv.className = 'message-actions';
        actionsDiv.innerHTML = `
            <button onclick="copyMessage('${messageElement.id}')"><i class="fas fa-copy"></i> Copy</button>
            <button onclick="regenerateMessage('${messageElement.id}')"><i class="fas fa-redo"></i> Regenerate</button>
        `;
        messageElement.appendChild(actionsDiv);
    }

    // New chat function 
    newChat() {
        this.currentChatId = 'chat_' + Date.now();
        this.chats[this.currentChatId] = {
            id: this.currentChatId,
            title: 'New Chat',
            messages: [],
            created: Date.now(),
            model: this.currentModel
        };

        this.clearChatUI();
        this.loadChats();
        this.updateURL();
        document.getElementById('chatTitle').textContent = 'New Chat';
    }

    // clear chat 
    clearChat() {
        if (!this.chats[this.currentChatId] || this.chats[this.currentChatId].messages.length === 0) {
            return;
        }

        if (confirm('Are you sure you want to clear this chat?')) {
            this.chats[this.currentChatId].messages = [];
            this.clearChatUI();
            this.saveCurrentChat();
        }
    }

    clearChatUI() {
        document.getElementById('chatMessages').innerHTML = `
            <div class="welcome-message">
                <h3><i class="fas fa-laptop-code"></i> Welcome to Local AI Chat</h3>
                <p>Your private AI assistant running locally on your machine.</p>
                <p>Try asking:</p>
                <ul class="suggestions">
                    <li onclick="document.getElementById('messageInput').value = this.textContent; document.getElementById('sendBtn').click();">"Write a Python function to reverse a string"</li>
                    <li onclick="document.getElementById('messageInput').value = this.textContent; document.getElementById('sendBtn').click();">"Explain quantum computing in simple terms"</li>
                    <li onclick="document.getElementById('messageInput').value = this.textContent; document.getElementById('sendBtn').click();">"Help me debug this JavaScript code"</li>
                    <li onclick="document.getElementById('messageInput').value = this.textContent; document.getElementById('sendBtn').click();">"What are the benefits of using Docker?"</li>
                </ul>
            </div>
        `;
    }

    // Copy chat to clipboard 
    async copyChat() {
        const chat = this.chats[this.currentChatId];
        if (!chat || chat.messages.length === 0) {
            alert('No chat to copy.');
            return;
        }

        let chatText = '';
        chat.messages.forEach(msg => {
            chatText += `${msg.role === 'user' ? 'You' : 'AI'}:\n${msg.content}\n\n`;
        });

        try {
            await navigator.clipboard.writeText(chatText);
            alert('Chat copied to clipboard!');
        } catch (error) {
            console.error('Failed to copy:', error);
        }
    }

    loadChats() {
        const chatList = document.getElementById('chatList');
        chatList.innerHTML = '';

        const chats = Object.values(this.chats)
            .sort((a, b) => b.created - a.created);

        if (chats.length === 0) {
            chatList.innerHTML = '<div class="empty-history">No chat history</div>';
            return;
        }

        chats.forEach(chat => {
            const chatItem = document.createElement('div');
            chatItem.className = `chat-item ${chat.id === this.currentChatId ? 'active' : ''}`;
            chatItem.innerHTML = `
                <div class="chat-item-content">
                    <i class="fas fa-comment"></i> 
                    <span class="chat-item-title">${chat.title}</span>
                    <br>
                    <small class="chat-item-info">
                        ${new Date(chat.created).toLocaleDateString()} • 
                        ${chat.messages.length} messages • 
                        ${this.formatModelName(chat.model || this.currentModel)}
                    </small>
                </div>
                <button class="chat-item-delete" onclick="window.chatApp.deleteChat('${chat.id}', event)">
                    <i class="fas fa-times"></i>
                </button>
            `;
            chatItem.addEventListener('click', (e) => {
                if (!e.target.closest('.chat-item-delete')) {
                    this.loadChat(chat.id);
                    // Close sidebar on mobile after selecting chat
                    if (window.innerWidth <= 768) {
                        document.querySelector('.sidebar').classList.remove('expanded');
                    }
                }
            });
            chatList.appendChild(chatItem);
        });
    }

    loadChat(chatId) {
        this.currentChatId = chatId;
        const chat = this.chats[chatId];

        if (!chat) return;

        const chatMessages = document.getElementById('chatMessages');
        chatMessages.innerHTML = '';

        chat.messages.forEach(msg => {
            const messageDiv = this.createMessageElement(msg.role, msg.content, msg.id);
            const timeElement = messageDiv.querySelector('.message-time');
            if (timeElement) {
                timeElement.textContent = new Date(msg.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
            }
        });

        document.getElementById('chatTitle').textContent = chat.title;
        this.loadChats();
        this.updateURL();

        if (chat.messages.length === 0) {
            this.clearChatUI();
        }
    }

    saveCurrentChat() {
        const chat = this.chats[this.currentChatId];
        if (!chat) return;

        if (chat.messages.length === 1) {
            const firstMessage = chat.messages[0].content;
            chat.title = firstMessage.substring(0, 50) + (firstMessage.length > 50 ? '...' : '');
        }

        chat.model = this.currentModel;

        localStorage.setItem('chats', JSON.stringify(this.chats));
        this.loadChats();
    }

    updateURL() {
        const url = new URL(window.location);
        url.searchParams.set('chat', this.currentChatId);
        window.history.replaceState({}, '', url);
    }

    formatModelName(model) {
        if (!model) return 'Unknown Model';
        return model.split(':')[0]
            .replace(/[.-]/g, ' ')
            .replace(/(^\w|\s\w)/g, m => m.toUpperCase());
    }

    // Show , hide and save SETTINGS 
    showSettings() {
        document.getElementById('settingsModal').classList.add('active');
        document.getElementById('apiUrl').value = this.apiUrl;
        document.getElementById('temperature').value = this.temperature;
        document.getElementById('tempValue').textContent = this.temperature;
        document.getElementById('maxTokens').value = this.maxTokens;
        document.getElementById('streamResponses').checked = this.streamResponses;
        document.getElementById('autoScroll').checked = this.autoScroll;
        document.getElementById('theme').value = this.theme;
    }

    hideSettings() {
        document.getElementById('settingsModal').classList.remove('active');
    }

    saveSettings() {
        this.apiUrl = document.getElementById('apiUrl').value;
        this.temperature = parseFloat(document.getElementById('temperature').value);
        this.maxTokens = parseInt(document.getElementById('maxTokens').value);
        this.streamResponses = document.getElementById('streamResponses').checked;
        this.autoScroll = document.getElementById('autoScroll').checked;
        this.theme = document.getElementById('theme').value;

        localStorage.setItem('ollamaApiUrl', this.apiUrl);
        localStorage.setItem('temperature', this.temperature);
        localStorage.setItem('maxTokens', this.maxTokens);
        localStorage.setItem('streamResponses', this.streamResponses);
        localStorage.setItem('autoScroll', this.autoScroll);
        localStorage.setItem('theme', this.theme);

        this.applyTheme();
        this.testConnection();
        this.hideSettings();
    }
}

// Global functions for button actions
function copyMessage(messageId) {
    const messageElement = document.getElementById(messageId);
    const content = messageElement.querySelector('.message-content').textContent;

    navigator.clipboard.writeText(content).then(() => {
        const originalText = messageElement.querySelector('.message-actions button').innerHTML;
        messageElement.querySelector('.message-actions button').innerHTML = '<i class="fas fa-check"></i> Copied!';
        setTimeout(() => {
            messageElement.querySelector('.message-actions button').innerHTML = originalText;
        }, 2000);
    });
}

function copyToClipboard(button) {
    const code = button.parentElement.nextElementSibling.textContent;
    navigator.clipboard.writeText(code).then(() => {
        const originalText = button.textContent;
        button.textContent = 'Copied!';
        setTimeout(() => {
            button.textContent = originalText;
        }, 2000);
    });
}

function regenerateMessage(messageId) {
    if (window.chatApp) {
        window.chatApp.regenerateMessage(messageId);
    } else {
        console.error('Chat app not initialized');
    }
}

// Initialize the chat when page loads
document.addEventListener('DOMContentLoaded', () => {
    window.chatApp = new OllamaChat();
});

// CORS fix 
(function () {
    const originalFetch = window.fetch;
    window.fetch = function (url, options = {}) {
        // Log all fetch requests for debugging
        console.log('Fetch request to:', url, options);

        if (url.includes('localhost:11434') || url.includes('127.0.0.1:11434')) {
            if (!options.headers) options.headers = {};
            options.headers['Content-Type'] = 'application/json';
        }
        return originalFetch.call(this, url, options);
    };
})();

// Debug function to test Ollama manually
window.testOllama = async function () {
    try {
        const response = await fetch('/api/tags');
        console.log('Manual test response:', response);
        const data = await response.json();
        console.log('Available models:', data);
        alert(`Ollama is running! Models: ${data.models ? data.models.map(m => m.name).join(', ') : 'none'}`);
    } catch (error) {
        console.error('Manual test failed:', error);
        alert(`Ollama connection failed: ${error.message}`);
    }
};