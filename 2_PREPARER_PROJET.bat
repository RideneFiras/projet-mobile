@echo off
rem 2) Prepare le projet : android/, pub get, analyse, tests, flutter doctor
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_projet.ps1"
