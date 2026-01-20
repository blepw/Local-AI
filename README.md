# Local-AI

Automate the process of using Ollama AI models with a local HTML / CSS / JavaScript web interface and a Python backend.
The system detects hardware, selects the best model, installs it if missing, and starts a local web server.

---

## Goal of the project

- Automate Ollama AI model usage
- Select the best model based on hardware
- Provide a local web interface
- Support Windows and Linux
- One-command startup

---

## How It Works

- User runs the startup script
- Prerequisites are checked
- Hardware information is collected
- Best model is selected using `model_config.json`
- User may override the model 
- Ollama installs the model if missing 
- Python web server starts 
- Web UI becomes available locally (localhost / LAN)
- Logs server errors and shows output in  `server_errors.log`


---

## CLI Automation

<p align="center">
  <img src="https://github.com/user-attachments/assets/2baad462-34a5-4ecd-9d7a-6b9ef0c288c7" width="48%" />
  <img src="https://github.com/user-attachments/assets/24554e6a-ebe2-4dae-806b-46e105c5a76e" width="48%" />
</p>

---

## Web Interface (Pc)

<p align="center">
  <img src="https://github.com/user-attachments/assets/2320f1d5-dae8-4fbd-9cf4-4407e18122e3" width="100%" />
</p>

---

## Execution

```text
Windows:
start.bat

Linux:
bash start.sh
```

## Project Structure 

```text
Local-AI/
├── start.sh
├── start.bat
├── server.py
├── model_config.json
│── index.html
│── style.css
└── script.js
```


## To-do 
- Catch and fix , Error: listen tcp 127.0.0.1:11434: bind: address already in use 
- Make the UI , phone friendly 
