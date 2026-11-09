@echo off
rem 3) Version web : tester dans Chrome sans emulateur
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_web.ps1"
