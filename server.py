from urllib.parse import urlparse, parse_qs
from datetime import datetime
import urllib.request
import urllib.error
import socketserver
import http.server
import traceback
import socket
import json
import sys
import os


PORT = 8080
HOST = '0.0.0.0'
LOG_FILE = 'server_errors.log'
OLLAMA_HOST = 'http://localhost:11434'


def log_error(error_msg, exc_info=None, request_path=None, client_address=None):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    
    log_entry = f"\n{'='*60}\n"
    log_entry += f"Timestamp: {timestamp}\n"
    log_entry += f"Error: {error_msg}\n"
    
    if request_path:
        log_entry += f"Request Path: {request_path}\n"
    
    if client_address:
        log_entry += f"Client Address: {client_address}\n"
    
    if exc_info:
        exc_type, exc_value, exc_traceback = exc_info
        tb_lines = traceback.format_exception(exc_type, exc_value, exc_traceback)
        log_entry += f"Traceback:\n{''.join(tb_lines)}\n"
    
    log_entry += f"{'='*60}\n"
    
    try:
        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(log_entry)
    except Exception as e:
        print(f"Failed to write to log file: {e}")
    
    print(log_entry)


def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(('8.8.8.8', 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception as e:
        log_error(f"Failed to get local IP: {e}", sys.exc_info())
        return '127.0.0.1'


class CORSRequestHandler(http.server.SimpleHTTPRequestHandler):    
    def translate_path(self, path):
        """Strip query string from path before serving files"""
        if '?' in path:
            path = path.split('?')[0]
        return super().translate_path(path)
    
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, DELETE')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, Authorization')
        super().end_headers()
    
    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()
    
    def do_GET(self):
        # Handle API requests
        if self.path.startswith('/api/'):
            try:
                # Forward to Ollama
                url = f"{OLLAMA_HOST}{self.path}"
                
                req = urllib.request.Request(url, method='GET')
                response = urllib.request.urlopen(req)
                
                self.send_response(response.getcode())
                
                # Copy headers
                for key, value in response.headers.items():
                    self.send_header(key, value)
                
                self.end_headers()
                self.wfile.write(response.read())
                
            except Exception as e:
                log_error(f"GET proxy failed: {e}", sys.exc_info(), self.path, self.client_address)
                self.send_error(500, "Proxy Error")
        
        else:
            # Serve files
            if self.path == '/':
                self.path = '/index.html'
            super().do_GET()
    
    def do_POST(self):
        if self.path.startswith('/api/'):
            try:
                content_length = int(self.headers.get('Content-Length', 0))
                post_data = self.rfile.read(content_length) if content_length > 0 else None
                
                url = f"{OLLAMA_HOST}{self.path}"
                req = urllib.request.Request(url, data=post_data, method='POST')
                req.add_header('Content-Type', 'application/json')
                
                response = urllib.request.urlopen(req)
                self.send_response(response.getcode())

                for key, value in response.headers.items():
                    self.send_header(key, value)
                
                self.end_headers()
                self.wfile.write(response.read())
                
            except Exception as e:
                log_error(f"POST proxy failed: {e}", sys.exc_info(), self.path, self.client_address)
                self.send_error(500, "Proxy Error")
        else:
            self.send_error(404, "Not Found")


os.chdir(os.path.dirname(os.path.abspath(__file__)))

print("\n" + "="*50)
print("[!] Starting Ollama Web Server")
print("="*50)


required_files = ['index.html', 'style.css', 'script.js']
missing_files = []
for file in required_files:
    if os.path.exists(file):
        print(f"[✓] {file}")
    else:
        print(f"[✗] {file} - MISSING!")
        missing_files.append(file)

if missing_files:
    print(f"\n[!] ERROR: Missing files: {', '.join(missing_files)}")
    print("[!] Make sure all files are in the same directory as server.py")
    sys.exit(1)


try:
    with open(LOG_FILE, 'w', encoding='utf-8') as f:
        f.write(f"Server Error Log - Started at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
except:
    pass


local_ip = get_local_ip()
print(f"[!] Ollama API: {OLLAMA_HOST}")
print(f"[!] All /api/* requests will be proxied to Ollama")
try:
    with socketserver.TCPServer((HOST, PORT), CORSRequestHandler) as httpd:
        print(f"[✓] Server started on port {PORT}")
        httpd.serve_forever()
except OSError as e:
    if "Address already in use" in str(e):
        print(f"[!] ERROR: Port {PORT} is already in use!")
        print(f"[!] Run: sudo fuser -k {PORT}/tcp")
        print(f"[!] Or: kill $(lsof -ti:{PORT})")
    else:
        print(f"[!] Server error: {e}")
except KeyboardInterrupt:
    print("\n\n[!] Server stopped by user")
except Exception as e:
    log_error(f"Server fatal error: {e}", sys.exc_info())
    print(f"\n\n [!] Server crashed: {e}")
    print(f"     Check {LOG_FILE} for details")

