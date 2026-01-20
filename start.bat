@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion


for /f %%a in ('echo prompt $E ^| cmd') do set "ESC=%%a"
set "RED=%ESC%[91m"
set "GREEN=%ESC%[92m"
set "YELLOW=%ESC%[93m"
set "BLUE=%ESC%[94m"
set "PURPLE=%ESC%[95m"
set "CYAN=%ESC%[96m"
set "NC=%ESC%[0m"

set "UI_DIR=%~dp0"
set "MODEL_CONFIG=model_config.json"
set "DEFAULT_MODEL=codellama:7b"
set "PORT=8080"


:echo_color
    if "%~2"=="" (
        echo %ESC%[94m[!]%ESC%[0m %~1
    ) else (
        echo %~2%~1%ESC%[0m
    )
    exit /b 0


:check_internet
    ping -n 2 -w 2000 8.8.8.8 > nul
    if %errorlevel% equ 0 (
        call :echo_color "[✓] Internet connection detected" "%GREEN%"
        exit /b 0
    ) else (
        call :echo_color "[✗] No internet connection" "%RED%"
        exit /b 1
    )


:check_prerequisites
    call :echo_color "Checking prerequisites..." "%CYAN%"
    echo.
    
    set "missing_prereqs="
    
    :: Check for Python
    call :echo_color "Checking Python..." "%BLUE%"
    where python >nul 2>nul
    if %errorlevel% neq 0 (
        call :echo_color "[!] Python not found" "%RED%"
        call :echo_color "==========================================" "%YELLOW%"
        call :echo_color "Please install Python manually:" "%YELLOW%"
        call :echo_color "1. Visit https://python.org" "%YELLOW%"
        call :echo_color "2. Download and install Python 3.x" "%YELLOW%"
        call :echo_color "3. Make sure 'Add Python to PATH' is checked" "%YELLOW%"
        call :echo_color "4. Restart this script" "%YELLOW%"
        call :echo_color "==========================================" "%YELLOW%"
        echo.
        set "missing_prereqs=!missing_prereqs!python "
    ) else (
        call :echo_color "[✓] Python is installed" "%GREEN%"
    )
    echo.
    
    :: Check for curl
    call :echo_color "Checking curl..." "%BLUE%"
    where curl >nul 2>nul
    if %errorlevel% neq 0 (
        call :echo_color "[!] curl not found" "%YELLOW%"
        call :echo_color "Installing curl via winget..." "%YELLOW%"
        winget install curl.curl 2>nul
        where curl >nul 2>nul
        if %errorlevel% equ 0 (
            call :echo_color "[✓] curl installed successfully" "%GREEN%"
        ) else (
            call :echo_color "[✗] Failed to install curl" "%RED%"
            call :echo_color "Download manually from: https://curl.se/windows/" "%YELLOW%"
            set "missing_prereqs=!missing_prereqs!curl "
        )
    ) else (
        call :echo_color "[✓] curl is installed" "%GREEN%"
    )
    echo.
    
    :: Check for jq
    call :echo_color "Checking jq (optional but recommended for JSON parsing)..." "%BLUE%"
    where jq >nul 2>nul
    if %errorlevel% neq 0 (
        call :echo_color "[!] jq not found" "%YELLOW%"
        call :echo_color "Installing jq via winget..." "%YELLOW%"
        winget install jqlang.jq 2>nul
        where jq >nul 2>nul
        if %errorlevel% equ 0 (
            call :echo_color "[✓] jq installed successfully" "%GREEN%"
        ) else (
            call :echo_color "[✗] jq installation failed but script will continue" "%RED%"
            call :echo_color "Download manually: https://stedolan.github.io/jq/download/" "%YELLOW%"
        )
    ) else (
        call :echo_color "[✓] jq is installed" "%GREEN%"
    )
    echo.
    
    :: Check for Ollama
    call :echo_color "Checking Ollama..." "%BLUE%"
    where ollama >nul 2>nul
    if %errorlevel% neq 0 (
        call :echo_color "[!] Ollama not found - REQUIRED" "%RED%"
        call :echo_color "==========================================" "%YELLOW%"
        call :echo_color "Please install Ollama manually:" "%YELLOW%"
        call :echo_color "1. Visit https://ollama.com" "%YELLOW%"
        call :echo_color "2. Download Windows installer" "%YELLOW%"
        call :echo_color "3. Run the installer and follow prompts" "%YELLOW%"
        call :echo_color "4. Restart this script" "%YELLOW%"
        call :echo_color "==========================================" "%YELLOW%"
        echo.
        set "missing_prereqs=!missing_prereqs!ollama "
    ) else (
        call :echo_color "[✓] Ollama is installed" "%GREEN%"
        :: Check if Ollama is running
        curl -s http://localhost:11434/api/tags >nul 2>nul
        if %errorlevel% neq 0 (
            call :echo_color "Starting Ollama service..." "%YELLOW%"
            start /b "" ollama serve
            timeout /t 5 /nobreak >nul
        )
    )
    echo.
    
    if not "!missing_prereqs!"=="" (
        call :echo_color "[!] Missing prerequisites:" "%RED%"
        for %%p in (!missing_prereqs!) do (
            call :echo_color "  - %%p" "%RED%"
        )
        call :echo_color "[!] Please install missing prerequisites and restart the script." "%YELLOW%"
        exit /b 1
    ) else (
        call :echo_color "[✓] All prerequisites are installed!" "%GREEN%"
        exit /b 0
    )


:get_system_info
    setlocal enabledelayedexpansion
    
    :: Get OS info
    ver | find "Windows" >nul
    if %errorlevel% equ 0 (
        for /f "tokens=4-5" %%i in ('ver') do set "OS_NAME=%%i %%j"
        for /f "tokens=2 delims=[]" %%i in ('systeminfo ^| findstr /B /C:"OS Name:"') do set "OS_VERSION=%%i"
    )
    
    :: Get CPU info
    for /f "tokens=2 delims==" %%i in ('wmic cpu get name /value') do set "CPU_MODEL=%%i"
    for /f "tokens=2 delims==" %%i in ('wmic cpu get NumberOfCores /value') do set "CPU_CORES=%%i"
    
    :: Get RAM info
    for /f "tokens=2" %%i in ('wmic computersystem get TotalPhysicalMemory /value ^| find "="') do (
        set /a RAM_BYTES=%%i
        set /a RAM_GB=!RAM_BYTES!/1073741824
        set "RAM_TOTAL=!RAM_GB!GB"
    )
    
    :: Get disk info
    for /f "tokens=3" %%i in ('wmic logicaldisk where "DeviceID='C:'" get Size /value ^| find "="') do (
        set /a DISK_BYTES=%%i
        set /a DISK_GB=!DISK_BYTES!/1073741824
        set "DISK_TOTAL=!DISK_GB!GB"
    )
    
    :: Get GPU info
    wmic path win32_VideoController get name 2>nul | findstr /v "Name" | head -1 >gpu.tmp
    set /p GPU_INFO=<gpu.tmp
    del gpu.tmp
    if "!GPU_INFO!"=="" (
        set "GPU_INFO=None"
        set "HAS_GPU=false"
    ) else (
        set "HAS_GPU=true"
    )
    
    :: Create JSON string
    (
        echo {
        echo   "os": "!OS_NAME!",
        echo   "os_version": "!OS_VERSION!",
        echo   "cpu": "!CPU_MODEL!",
        echo   "cpu_cores": !CPU_CORES!,
        echo   "ram_gb": !RAM_GB!,
        echo   "ram_total": "!RAM_TOTAL!",
        echo   "disk": "!DISK_TOTAL!",
        echo   "gpu": "!GPU_INFO!",
        echo   "has_gpu": !HAS_GPU!
        echo }
    ) > system_info.json
    
    type system_info.json
    exit /b 0


:: Function to select model based on system info
:select_model
    setlocal enabledelayedexpansion
    
    :: Parse RAM from JSON
    for /f "tokens=2 delims=:," %%i in ('findstr "ram_gb" system_info.json') do (
        set "RAM_GB=%%i"
        set "RAM_GB=!RAM_GB:"=!"
        set "RAM_GB=!RAM_GB: =!"
    )
    
    :: Check if config file exists
    if exist "%MODEL_CONFIG%" (
        call :echo_color "Using model configuration from: %MODEL_CONFIG%" "%CYAN%"
        
        where jq >nul 2>nul
        if %errorlevel% equ 0 (
            for /f "delims=" %%m in ('jq -r ".models[] ^| select(.min_ram ^<= %RAM_GB% and .max_ram ^>= %RAM_GB%) ^| .name" "%MODEL_CONFIG%" 2^>nul ^| head -1') do (
                set "selected_model=%%m"
            )
            
            if not "!selected_model!"=="" (
                echo !selected_model!
                endlocal
                exit /b 0
            )
        ) else (
            call :echo_color "[!] jq not found. Using simple model selection." "%RED%"
        )
    )
    
    :: Default model selection using RAM
    call :echo_color "Auto-selecting model based on your system:" "%CYAN%"
    call :echo_color "  RAM: %RAM_GB%GB" "%CYAN%"
    
    if %RAM_GB% geq 32 (
        echo codellama:34b
    ) else if %RAM_GB% geq 16 (
        echo codellama:13b
    ) else if %RAM_GB% geq 8 (
        echo codellama:7b
    ) else (
        echo tinyllama:1.1b
    )
    endlocal
    exit /b 0


:: Function to show available models
:show_available_models
    if exist "%MODEL_CONFIG%" (
        call :echo_color "Model availability by RAM size:" "%CYAN%"
        
        where jq >nul 2>nul
        if %errorlevel% equ 0 (
            set /a count_4gb=0
            set /a count_8gb=0
            set /a count_16gb=0
            set /a count_32gb=0
            set /a count_64gb=0
            
            :: Get total number of models
            for /f %%t in ('jq ".models ^| length" "%MODEL_CONFIG%"') do set "total_models=%%t"
            
            :: Count models for each category
            for /l %%i in (0,1,!total_models!) do (
                for /f "delims=" %%r in ('jq -r ".models[%%i].max_ram" "%MODEL_CONFIG%"') do set "max_ram=%%r"
                
                if !max_ram! leq 4 (
                    set /a count_4gb+=1
                ) else if !max_ram! leq 8 (
                    set /a count_8gb+=1
                ) else if !max_ram! leq 16 (
                    set /a count_16gb+=1
                ) else if !max_ram! leq 32 (
                    set /a count_32gb+=1
                ) else (
                    set /a count_64gb+=1
                )
            )
            
            :: Display categories that have models
            if !count_4gb! gtr 0 echo   • !count_4gb! models for 4GB RAM systems
            if !count_8gb! gtr 0 echo   • !count_8gb! models for 8GB RAM systems
            if !count_16gb! gtr 0 echo   • !count_16gb! models for 16GB RAM systems
            if !count_32gb! gtr 0 echo   • !count_32gb! models for 32GB RAM systems
            if !count_64gb! gtr 0 echo   • !count_64gb! models for 64GB+ RAM systems
            echo.
            echo   Total: !total_models! models available
        ) else (
            call :echo_color "[!] jq not found - cannot read model configuration" "%YELLOW%"
            call :echo_color "Install jq with: winget install jqlang.jq" "%YELLOW%"
            echo.
            call :echo_color "[!] Using default model selection based on your system RAM" "%YELLOW%"
        )
    ) else (
        call :echo_color "[!] Model configuration file not found: %MODEL_CONFIG%" "%YELLOW%"
        call :echo_color "   Create a model_config.json file or use auto-selection" "%YELLOW%"
        echo.
        call :echo_color "[!] Using default model selection based on your system RAM" "%YELLOW%"
    )
    echo.
    exit /b 0


cls
echo ^|=================================================^|
call :echo_color "Starting Local AI System..." "%BLUE%"
echo ^|=================================================^|
echo.

:: Check for prerequisites
set /p check_prereqs="[!] Check and install prerequisites? (Y/n) >"
if /i not "!check_prereqs!"=="n" (
    call :check_prerequisites
    if errorlevel 1 (
        call :echo_color "Some prerequisites are missing. The script may not work correctly." "%YELLOW%"
        set /p continue_anyway="Continue anyway? (y/N): "
        if /i not "!continue_anyway!"=="y" (
            exit /b 1
        )
    )
    echo.
)


:: Check files 
if not exist "index.html" (
    call :echo_color "ERROR: Run this script from your Local_AI folder!" "%RED%"
    call :echo_color "Expected files: index.html, style.css, script.js" "%RED%"
    exit /b 1
)

if not exist "style.css" (
    call :echo_color "ERROR: style.css not found!" "%RED%"
    exit /b 1
)

if not exist "script.js" (
    call :echo_color "ERROR: script.js not found!" "%RED%"
    exit /b 1
)


call :echo_color "Detecting your system configuration..." "%CYAN%"
echo.
call :get_system_info > system_info_temp.json
set /p SYSTEM_INFO=<system_info_temp.json

call :echo_color "========================================" "%PURPLE%"
call :echo_color "SYSTEM DETECTED:" "%PURPLE%"
call :echo_color "========================================" "%PURPLE%"

where jq >nul 2>nul
if %errorlevel% equ 0 (
    jq -r '"OS: \(.os) \(.os_version)\nCPU: \(.cpu) (\(.cpu_cores) cores)\nRAM: \(.ram_total) (\(.ram_gb)GB)\nDisk: \(.disk)\nGPU: \(.gpu)"' system_info_temp.json
) else (
    type system_info_temp.json
)

call :echo_color "========================================" "%PURPLE%"
echo.
call :echo_color "MODEL AVAILABILITY BY RAM REQUIREMENTS:" "%CYAN%"
call :show_available_models
call :echo_color "[!] Choose an option > " "%BLUE%"
echo   1) Use recommended model for my system (auto-select)
echo   2) Use default model: %DEFAULT_MODEL%
echo   3) Choose from available models
echo   4) Enter custom model name
echo.
set /p model_choice="[!] Enter choice [1-4] > "

if "!model_choice!"=="1" (
    for /f "delims=" %%m in ('call :select_model') do set "MODEL=%%m"
    call :echo_color "[!] Selected model: !MODEL!" "%GREEN%"
) else if "!model_choice!"=="2" (
    set "MODEL=%DEFAULT_MODEL%"
    call :echo_color "[!] Using default model: !MODEL!" "%GREEN%"
) else if "!model_choice!"=="3" (
    if exist "%MODEL_CONFIG%" (
        where jq >nul 2>nul
        if %errorlevel% equ 0 (
            call :echo_color "[!] Available models:" "%CYAN%"
            setlocal
            set "index=1"
            for /f "delims=" %%m in ('jq -r ".models[].name" "%MODEL_CONFIG%" 2^>nul') do (
                echo   !index!) %%m
                set "model_!index!=%%m"
                set /a index+=1
            )
            set /a total_models=index-1
            if !total_models! equ 0 (
                call :echo_color "[!] No models found in configuration file" "%YELLOW%"
                call :echo_color "   Using default model selection" "%YELLOW%"
                set "MODEL=%DEFAULT_MODEL%"
            ) else (
                set /p model_select="Select model [1-!total_models!]: "
                for /f "tokens=2 delims==" %%i in ('set model_!model_select! 2^>nul') do set "MODEL=%%i"
            )
            endlocal
        ) else (
            call :echo_color "[!] Cannot read model configuration" "%YELLOW%"
            call :echo_color "   jq not installed (winget install jqlang.jq)" "%YELLOW%"
            call :echo_color "   Using default model: %DEFAULT_MODEL%" "%YELLOW%"
            set "MODEL=%DEFAULT_MODEL%"
        )
    ) else (
        call :echo_color "[!] Model configuration file not found" "%YELLOW%"
        call :echo_color "   Using default model: %DEFAULT_MODEL%" "%YELLOW%"
        set "MODEL=%DEFAULT_MODEL%"
    )
    call :echo_color "[!] Selected model: !MODEL!" "%GREEN%"
) else if "!model_choice!"=="4" (
    set /p custom_model="Enter model name (e.g., 'llama2:13b'): "
    if not "!custom_model!"=="" (
        set "MODEL=!custom_model!"
        call :echo_color "[!] Using custom model: !MODEL!" "%GREEN%"
    ) else (
        set "MODEL=%DEFAULT_MODEL%"
        call :echo_color "[!] No model entered, using default: !MODEL!" "%YELLOW%"
    )
) else (
    for /f "delims=" %%m in ('call :select_model') do set "MODEL=%%m"
    call :echo_color "[!] Auto-selected model: !MODEL!" "%GREEN%"
)

:: Clean up temp files
if exist system_info_temp.json del system_info_temp.json
if exist system_info.json del system_info.json

echo.
call :echo_color "[-] Stopping any running services..." "%YELLOW%"
taskkill /f /im ollama.exe 2>nul
taskkill /f /im python.exe 2>nul
taskkill /f /im python3.exe 2>nul
taskkill /f /im server.py 2>nul


:: Kill port 8080
call :echo_color "[-] Killing any process on port %PORT%..." "%YELLOW%"
for /f "tokens=5" %%p in ('netstat -aon ^| findstr ":%PORT%" ^| findstr "LISTENING"') do (
    taskkill /f /pid %%p 2>nul
)
timeout /t 4 /nobreak >nul


:: Start Ollama
call :echo_color "[-] Starting Ollama AI server..." "%YELLOW%"
start /b "" ollama serve
timeout /t 6 /nobreak >nul


:: Verify Ollama is running
curl -s http://localhost:11434/api/tags >nul
if %errorlevel% equ 0 (
    call :echo_color "[✓] Ollama is running" "%GREEN%"
) else (
    call :echo_color "[✗] Ollama failed to start!" "%RED%"
    call :echo_color "Try running manually: ollama serve" "%YELLOW%"
    exit /b 1
)

:: Check if model exists and download if it doesn't
call :echo_color "[!] Checking model: !MODEL!" "%YELLOW%"
ollama list | findstr "!MODEL!" >nul
if %errorlevel% equ 0 (
    call :echo_color "[✓] Model is available" "%GREEN%"
) else (
    call :echo_color "[!] Downloading model (may take a while)..." "%YELLOW%"
    ollama pull !MODEL!
    if %errorlevel% neq 0 (
        call :echo_color "[!] Model download failed. Trying smaller model..." "%YELLOW%"
        for %%f in ("codellama:7b" "qwen2.5:7b" "tinyllama:1.1b") do (
            call :echo_color "[!] Trying: %%f" "%YELLOW%"
            ollama pull %%f
            if %errorlevel% equ 0 (
                set "MODEL=%%~f"
                call :echo_color "[✓] Using fallback model: !MODEL!" "%GREEN%"
                goto :model_selected
            )
        )
    )
    :model_selected
)


:: Start web server
echo.
call :echo_color "[!] Starting web interface on port %PORT%..." "%YELLOW%"

if not exist "server.py" (
    call :echo_color "[✗] ERROR: server.py not found!" "%RED%"
    call :echo_color "  Please create server.py with the code provided" "%RED%"
    exit /b 1
)

findstr "def do_POST" server.py >nul
if %errorlevel% equ 0 (
    call :echo_color "[✓] Using custom server.py with API proxy support" "%GREEN%"
    start /b "" python server.py
    timeout /t 3 /nobreak >nul
    
    curl -s http://localhost:%PORT% >nul
    if %errorlevel% equ 0 (
        echo.
        call :echo_color "[✓] Web server is running" "%GREEN%"
    ) else (
        call :echo_color "[!] Web server might have issues" "%YELLOW%"
        echo.
    )
) else (
    call :echo_color "[✗] ERROR: server.py missing POST method!" "%RED%"
    call :echo_color "  Make sure server.py has 'def do_POST' method" "%RED%"
    exit /b 1
)


:: Show info
call :echo_color "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓" "%GREEN%"
call :echo_color "┃       LOCAL AI CHAT SERVER         ┃" "%GREEN%"
call :echo_color "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛" "%GREEN%"
echo.
call :echo_color "|-- [-] AI Engine (Ollama)" "%BLUE%"
echo ^|   URL:    http://localhost:11434
echo ^|   Model:  !MODEL!
echo ^|   Status: Running
echo ^|
call :echo_color "|-- [-] Web Interface" "%BLUE%"
echo ^|   This computer:  http://localhost:%PORT%
echo ^|   Local network:  http://%COMPUTERNAME%.local:%PORT%
echo ^|   API Proxy:      ✓ Enabled (cross-device works)
echo ^|
call :echo_color "|-- [-] Quick Start" "%BLUE%"
echo ^|   1) Open browser to: http://localhost:%PORT%
echo ^|   2) Type your first prompt
echo ^|   3) Press Enter
echo ^|
call :echo_color "|-- [-] To Stop" "%YELLOW%"
echo ^|_  Close this window or press Ctrl+C
echo.
call :echo_color "[!] Services are running. Press Ctrl+C or close window to stop." "%YELLOW%"
echo.
pause >nul


call :echo_color "[!] Stopping services..." "%YELLOW%"
taskkill /f /im ollama.exe 2>nul
taskkill /f /im python.exe 2>nul
timeout /t 2 /nobreak >nul
call :echo_color "[✓] All services stopped" "%GREEN%"
exit /b 0

