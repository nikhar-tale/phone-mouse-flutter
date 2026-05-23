# build.ps1

# Ensure we exit on error
$ErrorActionPreference = "Stop"

# Navigate to script directory
Set-Location $PSScriptRoot

Write-Host "=== Building Phone Mouse Server Executable ===" -ForegroundColor Yellow

# Create venv if it does not exist
if (-not (Test-Path -Path "venv")) {
    Write-Host "1. Creating Python virtual environment..." -ForegroundColor Cyan
    python -m venv venv
} else {
    Write-Host "1. Python virtual environment already exists." -ForegroundColor Cyan
}

# Activate virtual environment
Write-Host "2. Activating virtual environment..." -ForegroundColor Cyan
# Set execution policy for process to allow running activation script if needed
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
. .\venv\Scripts\Activate.ps1

# Upgrade pip
Write-Host "3. Upgrading pip..." -ForegroundColor Cyan
python -m pip install --upgrade pip

# Install requirements
Write-Host "4. Installing dependencies from requirements.txt..." -ForegroundColor Cyan
pip install -r requirements.txt

# Install PyInstaller
Write-Host "5. Installing PyInstaller..." -ForegroundColor Cyan
pip install pyinstaller

# Build executable
Write-Host "6. Compiling server.py with PyInstaller..." -ForegroundColor Cyan
# Using --onefile to pack everything into a single executable.
# We keep the console enabled so uvicorn startup logs (host/port) and connection messages are visible.
pyinstaller --onefile --name="phone_mouse_server" server.py

Write-Host "=== Build Completed Successfully! ===" -ForegroundColor Green
Write-Host "Your standalone executable is located at: .\dist\phone_mouse_server.exe" -ForegroundColor Green
