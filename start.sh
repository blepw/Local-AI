#!/bin/bash

# ===============================================================================================================
#  [ Goal ]
# - the goal of this script is to Automate the process of using ollama Ai models with an htmls,cs,js web server,  
# depending on a default model , or a model that suits the user according to hardware information 
#  [ How ]  
# - User runs start.sh or start.bat based on their operating system , that script downloads and checks for 
# prerequisites then gets system information and determines which model would be the best . The user then 
# chooses if they want to use the DEFAULT_MODEL , model by typing the name or available model . 
# The script then checks if that model is installed , if not it installs it using Ollama. 
# after that the user chooses what to use and creates a web server using server.py and everything else 
# needed for the functionality and user interface ( script.js , index.html , style.css ) 
# [More info]
# - Uses model_config.json to categorize the best model for hardware
# All the functionalities of the website are in script.js (button functions , logic)
# User can set their model of choose by name in DEFAULT_MODEL 
# UI_DIR is the 'location' of those files needed to run the webserver. (uses dirname instead of setting the path)
# ================================================================================================================


UI_DIR="$(dirname "$0")"
MODEL_CONFIG="model_config.json"
DEFAULT_MODEL="codellama:7b"
PORT=8080         


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'


echo_color() {
    echo -e "${2}${1}${NC}"
}


check_internet() {
    if ping -c 2 -W 2 8.8.8.8 > /dev/null 2>&1; then
        echo_color "[✓] Internet connection detected " "$RED"
        return 0
    else
        echo_color "[✗] No internet connection" "$RED" >&2
        return 1
    fi
}


check_internet


# Function to install prerequisites
install_prerequisites() {
    echo_color "[!] Checking prerequisites..." "$CYAN"
    echo ""
    
    local missing_prereqs=()
    local os_type=""
    
    # Detect OS
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_type="linux"
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            if [[ "$ID" == "ubuntu" || "$ID" == "debian" ]]; then
                os_type="debian"
            elif [[ "$ID" == "centos" || "$ID" == "rhel" || "$ID" == "fedora" ]]; then
                os_type="rhel"
            elif [[ "$ID" == "arch" || "$ID" == "manjaro" ]]; then
                os_type="arch"
            fi
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        os_type="macos"
    else
        os_type="unknown"
    fi
    
    # Check for Ollama
    echo_color "Checking Ollama..." "$BLUE"
    if ! command -v ollama &> /dev/null; then
        echo_color "[!] Ollama not found - REQUIRED" "$RED"
        echo_color "==========================================" "$RED"
        echo_color "Please install Ollama manually:" "$YELLOW"
        echo_color "1. Visit https://ollama.com" "$YELLOW"
        echo_color "2. Download and install for your OS" "$YELLOW"
        echo_color "3. Run 'ollama serve' in terminal" "$YELLOW"
        echo_color "4. Restart this script" "$YELLOW"
        echo_color "==========================================" "$RED"
        echo ""
        missing_prereqs+=("ollama")
    else
        echo_color "[✓] Ollama is installed" "$GREEN"
        # Check if Ollama is running
        if ! curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
            echo_color "Starting Ollama service..." "$YELLOW"
            ollama serve > /dev/null 2>&1 &
            sleep 5
        fi
    fi
    echo ""

    
    # Check for Python 3
    echo_color "Checking Python3 ..." "$BLUE"
    if ! command -v python3 &> /dev/null; then
        echo_color "[!] Python3 not found" "$YELLOW"
        if [[ "$os_type" == "debian" ]]; then
            echo_color "Installing Python3 via apt..." "$YELLOW"
            sudo apt update && sudo apt install -y python3 python3-pip
        elif [[ "$os_type" == "rhel" ]]; then
            echo_color "Installing Python3 via yum..." "$YELLOW"
            sudo yum install -y python3 python3-pip
        elif [[ "$os_type" == "arch" ]]; then
            echo_color "Installing Python3 via pacman..." "$YELLOW"
            sudo pacman -Sy python python-pip
        elif [[ "$os_type" == "macos" ]]; then
            echo_color "Installing Python3 via Homebrew..." "$YELLOW"
            brew install python
        else
            echo_color "Please install Python3 manually:" "$RED"
            echo_color "Visit https://python.org" "$RED"
        fi
        # check installation 
        if command -v python3 &> /dev/null; then
            echo_color "[✓] Python3 installed successfully" "$GREEN"
        else
            echo_color "[✗] Failed to install Python3" "$RED"
            missing_prereqs+=("python3")
        fi
    else
        echo_color "[✓] Python3 is installed" "$GREEN"
    fi
    echo ""
    

    # Check for curl
    echo_color "Checking curl..." "$BLUE"
    if ! command -v curl &> /dev/null; then
        echo_color "[!] curl not found" "$YELLOW"
        if [[ "$os_type" == "debian" ]]; then
            echo_color "Installing curl via apt..." "$YELLOW"
            sudo apt install -y curl
        elif [[ "$os_type" == "rhel" ]]; then
            echo_color "Installing curl via yum..." "$YELLOW"
            sudo yum install -y curl
        elif [[ "$os_type" == "arch" ]]; then
            echo_color "Installing curl via pacman..." "$YELLOW"
            sudo pacman -Sy curl
        elif [[ "$os_type" == "macos" ]]; then
            echo_color "Installing curl via Homebrew..." "$YELLOW"
            brew install curl
        fi
        # check installation 
        if command -v curl &> /dev/null; then
            echo_color "[✓] curl installed successfully" "$GREEN"
        else
            echo_color "[✗] Failed to install curl" "$RED"
            missing_prereqs+=("curl")
        fi
    else
        echo_color "[✓] curl is installed" "$GREEN"
    fi
    echo ""
    

    # Check for jq
    echo_color "Checking jq (optional but recommended for JSON parsing)..." "$BLUE"
    if ! command -v jq &> /dev/null; then
        echo_color "[!] jq not found" "$YELLOW"
        if [[ "$os_type" == "debian" ]]; then
            echo_color "Installing jq via apt..." "$YELLOW"
            sudo apt install -y jq
        elif [[ "$os_type" == "rhel" ]]; then
            echo_color "Installing jq via yum..." "$YELLOW"
            sudo yum install -y jq
        elif [[ "$os_type" == "arch" ]]; then
            echo_color "Installing jq via pacman..." "$YELLOW"
            sudo pacman -Sy jq
        elif [[ "$os_type" == "macos" ]]; then
            echo_color "Installing jq via Homebrew..." "$YELLOW"
            brew install jq
        else
            echo_color "Install jq manually: https://stedolan.github.io/jq/download/" "$RED"
        fi
        # Verify installation
        if command -v jq &> /dev/null; then
            echo_color "[✓] jq installed successfully" "$GREEN"
        else
            echo_color "[✗] jq installation failed but script will continue" "$RED"
        fi
    else
        echo_color "[✓] jq is installed" "$GREEN"
    fi
    echo ""
    

    if [[ ${#missing_prereqs[@]} -gt 0 ]]; then
        echo_color "[!] Missing prerequisites:" "$RED"
        for prereq in "${missing_prereqs[@]}"; do
            echo_color "  - $prereq" "$RED"
        done
        echo_color "[!] Please install missing prerequisites and restart the script." "$YELLOW"
        return 1
    else
        echo_color "[✓] All prerequisites are installed!" "$GREEN"
        return 0
    fi
}


get_system_info() {
    local info="{}"
    
    # OS info
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_VERSION="$VERSION_ID"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS_NAME="macOS"
        OS_VERSION=$(sw_vers -productVersion)
    else
        OS_NAME=$(uname -s)
        OS_VERSION=$(uname -r)
    fi
    
    # CPU info
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        CPU_MODEL=$(lscpu | grep "Model name" | cut -d: -f2 | xargs)
        CPU_CORES=$(nproc)
        RAM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}' | sed 's/Gi/GB/' | sed 's/Mi/MB/')
        RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        CPU_MODEL=$(sysctl -n machdep.cpu.brand_string)
        CPU_CORES=$(sysctl -n hw.ncpu)
        RAM_GB=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))
        RAM_TOTAL="${RAM_GB}GB"
    else
        CPU_MODEL="Unknown"
        CPU_CORES=1
        RAM_GB=8
        RAM_TOTAL="8GB"
    fi
    
    # Disk info
    if command -v df &> /dev/null; then
        DISK_TOTAL=$(df -h / | awk 'NR==2 {print $2}')
    else
        DISK_TOTAL="Unknown"
    fi
    

    # GPU info if available
    if command -v nvidia-smi &> /dev/null; then
        GPU_INFO=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
        HAS_GPU="true"
    elif command -v lspci &> /dev/null; then
        GPU_INFO=$(lspci | grep -i vga | head -1 | cut -d: -f3-)
        HAS_GPU="true"
    else
        GPU_INFO="None"
        HAS_GPU="false"
    fi
    

    # JSON string
    info=$(jq -n \
        --arg os "$OS_NAME" \
        --arg os_version "$OS_VERSION" \
        --arg cpu "$CPU_MODEL" \
        --arg cores "$CPU_CORES" \
        --arg ram_gb "$RAM_GB" \
        --arg ram_total "$RAM_TOTAL" \
        --arg disk "$DISK_TOTAL" \
        --arg gpu "$GPU_INFO" \
        --arg has_gpu "$HAS_GPU" \
        '{
            "os": $os,
            "os_version": $os_version,
            "cpu": $cpu,
            "cpu_cores": ($cores | tonumber),
            "ram_gb": ($ram_gb | tonumber),
            "ram_total": $ram_total,
            "disk": $disk,
            "gpu": $gpu,
            "has_gpu": ($has_gpu | test("true"))
        }' 2>/dev/null)
    

    # no jq fallback 
    if [[ -z "$info" ]]; then
        info="{
            \"os\": \"$OS_NAME\",
            \"os_version\": \"$OS_VERSION\",
            \"cpu\": \"$CPU_MODEL\",
            \"cpu_cores\": $CPU_CORES,
            \"ram_gb\": $RAM_GB,
            \"ram_total\": \"$RAM_TOTAL\",
            \"disk\": \"$DISK_TOTAL\",
            \"gpu\": \"$GPU_INFO\",
            \"has_gpu\": $HAS_GPU
        }"
    fi
    
    echo "$info"
}



# select model based on info
select_model() {
    local system_info="$1"
    
    # Extract values from system info
    if command -v jq &> /dev/null; then
        RAM_GB=$(echo "$system_info" | jq -r '.ram_gb')
        HAS_GPU=$(echo "$system_info" | jq -r '.has_gpu')
        CPU_CORES=$(echo "$system_info" | jq -r '.cpu_cores')
    else
        # Simple parsing without jq
        RAM_GB=$(echo "$system_info" | grep -o '"ram_gb":[0-9]*' | cut -d: -f2)
        HAS_GPU=$(echo "$system_info" | grep -o '"has_gpu":true' | wc -l)
        CPU_CORES=$(echo "$system_info" | grep -o '"cpu_cores":[0-9]*' | cut -d: -f2)
    fi
    
    # Check if config file exists
    if [[ -f "$MODEL_CONFIG" ]]; then
        echo_color "[!] Using model configuration from: $MODEL_CONFIG" "$CYAN"
        
        if command -v jq &> /dev/null; then
            # Try to find matching model based on RAM
            local selected_model=$(jq -r --argjson ram "$RAM_GB" '
                .models[] | 
                select(.min_ram <= $ram and .max_ram >= $ram) |
                .name' "$MODEL_CONFIG" | head -1)
            
            if [[ -n "$selected_model" ]]; then
                echo "$selected_model"
                return
            fi
        else
            echo_color "[!] jq not found. Using simple model selection." "$RED"
        fi
    fi
    
    # default model selection using ram
    echo_color "[!] Auto-selecting model based on your system:" "$CYAN"
    echo_color "  RAM: ${RAM_GB}GB, GPU: ${HAS_GPU}, Cores: ${CPU_CORES}" "$CYAN"
    
    if [[ $RAM_GB -ge 32 ]] && [[ "$HAS_GPU" == "true" ]]; then
        echo "codellama:34b"  # Large 
    elif [[ $RAM_GB -ge 16 ]]; then
        echo "codellama:13b"  # Medium 
    elif [[ $RAM_GB -ge 8 ]]; then
        echo "codellama:7b"   # Small 
    else
        echo "tinyllama:1.1b" # Tiny
    fi
}


show_available_models() {
    if [[ -f "$MODEL_CONFIG" ]]; then
        echo_color "[!] Model availability by RAM size:" "$CYAN"
        
        if command -v jq &> /dev/null; then
            local count_4gb=0
            local count_8gb=0
            local count_16gb=0
            local count_32gb=0
            local count_64gb=0
            local count_128gb=0
            local count_256gb=0
            local count_512gb=0
            
            # Get total num of models
            local total_models=$(jq '.models | length' "$MODEL_CONFIG")
            
            # Count models for each cat
            for ((i=0; i<total_models; i++)); do
                local max_ram=$(jq -r ".models[$i].max_ram" "$MODEL_CONFIG")
                
                # determine category based on max ram
                if [[ $max_ram -le 4 ]]; then
                    ((count_4gb++))
                elif [[ $max_ram -le 8 ]]; then
                    ((count_8gb++))
                elif [[ $max_ram -le 16 ]]; then
                    ((count_16gb++))
                elif [[ $max_ram -le 32 ]]; then
                    ((count_32gb++))
                elif [[ $max_ram -le 64 ]]; then
                    ((count_64gb++))
                elif [[ $max_ram -le 128 ]]; then
                    ((count_128gb++))
                elif [[ $max_ram -le 256 ]]; then
                    ((count_256gb++))
                else
                    ((count_512gb++))
                fi
            done
            
            # Only display categories that have models
            if [[ $count_4gb -gt 0 ]]; then
                echo "  • $count_4gb models for 4GB RAM systems"
            fi
            if [[ $count_8gb -gt 0 ]]; then
                echo "  • $count_8gb models for 8GB RAM systems"
            fi
            if [[ $count_16gb -gt 0 ]]; then
                echo "  • $count_16gb models for 16GB RAM systems"
            fi
            if [[ $count_32gb -gt 0 ]]; then
                echo "  • $count_32gb models for 32GB RAM systems"
            fi
            if [[ $count_64gb -gt 0 ]]; then
                echo "  • $count_64gb models for 64GB RAM systems"
            fi
            if [[ $count_128gb -gt 0 ]]; then
                echo "  • $count_128gb models for 128GB+ RAM systems"
            fi
            if [[ $count_256gb -gt 0 ]]; then
                echo "  • $count_256gb models for 256GB+ RAM systems"
            fi
            if [[ $count_512gb -gt 0 ]]; then
                echo "  • $count_512gb models for 512GB+ RAM systems"
            fi
            echo ""
            echo "  Total: $total_models models available"
            
        else
            echo_color "[!] jq not found - cannot read model configuration" "$YELLOW"
            echo_color "Install jq to see available models: sudo apt install jq" "$YELLOW"
            echo ""
            echo_color "[!] Using default model selection based on your system RAM" "$YELLOW"
        fi
    else
        echo_color "[!]  Model configuration file not found: $MODEL_CONFIG" "$YELLOW"
        echo_color "   Create a model_config.json file or use auto-selection" "$YELLOW"
        echo ""
        echo_color "[!] Using default model selection based on your system RAM" "$YELLOW"
    fi
    echo ""
}


# clears screen after basic setup , prereq checks , hardware info 
clear 


echo "|=================================================|"
echo_color " Starting Local AI System..." "$BLUE         "     
echo "|=================================================|"
echo ""

# Check for prerequisites
read -p "[!] Check and install prerequisites? (Y/n) >" check_prereqs
if [[ "$check_prereqs" != "n" && "$check_prereqs" != "N" ]]; then
    install_prerequisites
    if [ $? -ne 0 ]; then
        echo_color "Some prerequisites are missing. The script may not work correctly." "$YELLOW"
        read -p "Continue anyway? (y/N): " continue_anyway
        if [[ "$continue_anyway" != "y" && "$continue_anyway" != "Y" ]]; then
            exit 1
        fi
    fi
    echo ""
fi


# Check if in correct directory
if [ ! -f "index.html" ] || [ ! -f "style.css" ] || [ ! -f "script.js" ]; then
    echo_color "ERROR: Run this script from your Local_AI folder!" "$RED"
    echo "Expected files: index.html, style.css, script.js"
    exit 1
fi
 
echo_color "[!] Detecting your system configuration..." "$CYAN"
echo " " 
SYSTEM_INFO=$(get_system_info)

echo_color "========================================" "$PURPLE"
echo_color "SYSTEM DETECTED:" "$PURPLE"
echo_color "========================================" "$PURPLE"
echo "$SYSTEM_INFO" | jq -r '
    "OS: \(.os) \(.os_version)
CPU: \(.cpu) (\(.cpu_cores) cores)
RAM: \(.ram_total) (\(.ram_gb)GB)
Disk: \(.disk)
GPU: \(.gpu)"' 2>/dev/null || echo "$SYSTEM_INFO"

echo_color "========================================" "$PURPLE"
echo ""

echo_color "[!] MODEL AVAILABILITY BY RAM REQUIREMENTS:" "$CYAN"
show_available_models
echo_color "[!] Choose an option > " "$BLUE"
echo "  1) Use recommended model for my system (auto-select)"
echo "  2) Use default model: $DEFAULT_MODEL"
echo "  3) Choose from available models"
echo "  4) Enter custom model name"
echo ""
read -p "[!] Enter choice [1-4] > " model_choice


case $model_choice in
    1)
        MODEL=$(select_model "$SYSTEM_INFO")
        echo_color "[!] Selected model: $MODEL" "$GREEN"
        ;;
    2)
        MODEL="$DEFAULT_MODEL"
        echo_color "[!] Using default model: $MODEL" "$GREEN"
        ;;

    3)
        if [[ -f "$MODEL_CONFIG" ]] && command -v jq &> /dev/null; then
            echo_color "[!] Available models:" "$CYAN"
            models=($(jq -r '.models[].name' "$MODEL_CONFIG" 2>/dev/null))
            if [[ ${#models[@]} -eq 0 ]]; then
                echo_color "[!]  No models found in configuration file" "$YELLOW"
                echo_color "   Using default model selection" "$YELLOW"
                MODEL="$DEFAULT_MODEL"
            else
                select model_name in "${models[@]}"; do
                    if [[ -n "$model_name" ]]; then
                        MODEL="$model_name"
                        break
                    fi
                done
            fi
        else
            echo_color "[!]  Cannot read model configuration" "$YELLOW"
            if [[ ! -f "$MODEL_CONFIG" ]]; then
                echo_color "   Config file not found: $MODEL_CONFIG" "$YELLOW"
            fi
            if ! command -v jq &> /dev/null; then
                echo_color "   jq not installed (sudo apt install jq)" "$YELLOW"
            fi
            echo_color "   Using default model: $DEFAULT_MODEL" "$YELLOW"
            MODEL="$DEFAULT_MODEL"
        fi
        echo_color "[!] Selected model: $MODEL" "$GREEN"
        ;;

    4)
        read -p "Enter model name (e.g., 'llama2:13b'): " custom_model
        if [[ -n "$custom_model" ]]; then
            MODEL="$custom_model"
            echo_color "[!] Using custom model: $MODEL" "$GREEN"
        else
            MODEL="$DEFAULT_MODEL"
            echo_color "[!] No model entered, using default: $MODEL" "$YELLOW"
        fi
        ;;
    *)
        MODEL=$(select_model "$SYSTEM_INFO")
        echo_color "[!] Auto-selected model: $MODEL" "$GREEN"
        ;;
esac


# kills ollama,python & server services
echo ""
echo_color "[-] Stopping any running services..." "$YELLOW"
pkill -f "ollama serve" 2>/dev/null
pkill -f "python3" 2>/dev/null
pkill -f "server.py" 2>/dev/null


# Kills port 8080 
echo_color "[-] Killing any process on port $PORT..." "$YELLOW"
sudo fuser -k $PORT/tcp 2>/dev/null || true
lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
ss -tulpn | grep :$PORT | awk '{print $7}' | cut -d'=' -f2 | cut -d',' -f1 | xargs kill -9 2>/dev/null || true
fuser -k $PORT/tcp 2>/dev/null || true
sleep 4


# starts ollama 
echo_color "[-] Starting Ollama AI server..." "$YELLOW"
ollama serve &
OLLAMA_PID=$!
sleep 6


# Verify Ollama is running
if curl -s http://localhost:11434/api/tags >/dev/null; then
    echo_color "[✓] Ollama is running" "$GREEN"
else
    echo_color "[✗] Ollama failed to start!" "$RED"
    echo "Try running manually: ollama serve"
    exit 1
fi



# Step 3: Check if model exists and download if it doesn't
echo_color "[!] Checking model: $MODEL" "$YELLOW"
if ollama list | grep -q "$MODEL"; then
    echo_color "[✓] Model is available" "$GREEN"
else
    echo_color "[!] Downloading model (may take a while)..." "$YELLOW"
    ollama pull "$MODEL"
    if [ $? -eq 0 ]; then
        echo_color "[✓] Model downloaded successfully" "$GREEN"
    else
        echo_color "[!] Model download failed. Trying smaller model..." "$YELLOW"
        # Try fallback models
        for fallback in "codellama:7b" "qwen2.5:7b" "tinyllama:1.1b"; do
            echo_color "[!] Trying: $fallback" "$YELLOW"
            ollama pull "$fallback"
            if [ $? -eq 0 ]; then
                MODEL="$fallback"
                echo_color "[✓] Using fallback model: $MODEL" "$GREEN"
                break
            fi
        done
    fi
fi


# Step 4: Start web server
echo ""
echo_color "[!] Starting web interface on port $PORT..." "$YELLOW"

# Check if server.py exists
if [ ! -f "server.py" ]; then
    echo_color "[✗] ERROR: server.py not found!" "$RED"
    echo_color "  Please create server.py with the code provided" "$RED"
    exit 1
fi


# Check if server.py has POST support
if grep -q "def do_POST" server.py; then
    echo_color "✓ Using custom server.py with API proxy support" "$GREEN"
    python3 server.py &
    WEB_PID=$!
    sleep 3
    
    # Verify server started
    if curl -s http://localhost:$PORT >/dev/null; then
        echo " "
        echo_color "[✓] Web server is running " "$GREEN"
    else
        echo_color "[!] Web server might have issues" "$YELLOW"
        echo " " 
    fi
else
    echo_color "[✗] ERROR: server.py missing POST method!" "$RED"
    echo_color "  Make sure server.py has 'def do_POST' method" "$RED"
    exit 1
fi


# Step 5: Show connection info
IP=$(hostname -I | awk '{print $1}')
[ -z "$IP" ] && IP="127.0.0.1"


echo_color "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓" "$GREEN"
echo_color "┃       LOCAL AI CHAT SERVER         ┃" "$GREEN"
echo_color "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛" "$GREEN"
echo ""
echo_color "|-- [-] AI Engine (Ollama)" "$BLUE"
echo "|   URL:    http://localhost:11434"
echo "|   Model:  $MODEL"
echo "|   Status: Running"
echo "|"
echo_color "|-- [-] Web Interface" "$BLUE"
echo "|   This computer:  http://localhost:$PORT"
echo "|   Local network:  http://$IP:$PORT"
echo "|   API Proxy:      ✓ Enabled (cross-device works)"
echo "|"
echo_color "|-- [-] Quick Start" "$BLUE"
echo "|   1) Open browser to: http://localhost:$PORT"
echo "|   2) Type your first prompt"
echo "|   3) Press Enter"
echo "|"
echo_color "|-- [-] To Stop" "$YELLOW"
echo "|_  Press Ctrl+C in this terminal"
echo ""

# fix Error: listen tcp 127.0.0.1:11434: bind: address already in use

trap 'echo_color "\n[!] Stopping services..." "$YELLOW"; kill $OLLAMA_PID $WEB_PID 2>/dev/null; sleep 2; echo_color "[✓] All services stopped" "$GREEN"; exit 0' INT TERM
echo_color "[!] Services are running. Press Ctrl+C to stop." "$YELLOW"
echo ""

# wait until ctrl+c 
wait

