@echo off
rem 1) Installe Git, VS Code, Android Studio, Flutter (fenetre Administrateur)
cd /d "%~dp0"
powershell -NoProfile -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%~dp0setup_windows.ps1'"
