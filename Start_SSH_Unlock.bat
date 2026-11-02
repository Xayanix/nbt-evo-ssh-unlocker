@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if %errorlevel%==0 (
    py -3 nbt_ssh_unlock_gui.py
    if errorlevel 1 pause
    goto :eof
)
python nbt_ssh_unlock_gui.py
if errorlevel 1 pause
