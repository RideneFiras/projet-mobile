@echo off
title Tests - Travel Platform
cd /d "%~dp0"

rem Chemin de Flutter : utilise le chemin complet s'il existe, sinon le PATH.
set "FLUTTER=C:\src\flutter\bin\flutter.bat"
if exist "%FLUTTER%" (set "FL=%FLUTTER%") else (set "FL=flutter")

if not exist logs mkdir logs
set "LOG=logs\transport.log"

echo ==== Verification Travel Platform ==== > "%LOG%"
echo Date : %DATE% %TIME% >> "%LOG%"
echo Flutter utilise : %FL% >> "%LOG%"
echo.
echo Flutter utilise : %FL%
echo.

echo [1/3] flutter pub get
call "%FL%" pub get >> "%LOG%" 2>&1
set "CODE_DEPS=%ERRORLEVEL%"

echo [2/3] flutter analyze
call "%FL%" analyze >> "%LOG%" 2>&1
set "CODE_ANALYSE=%ERRORLEVEL%"

echo [3/3] flutter test
call "%FL%" test >> "%LOG%" 2>&1
set "CODE_TESTS=%ERRORLEVEL%"

echo ==== FIN ==== >> "%LOG%"
echo Dependances : code %CODE_DEPS% >> "%LOG%"
echo Analyse     : code %CODE_ANALYSE% >> "%LOG%"
echo Tests       : code %CODE_TESTS% >> "%LOG%"

echo.
echo Dependances : code %CODE_DEPS%
echo Analyse     : code %CODE_ANALYSE%
echo Tests       : code %CODE_TESTS%
echo.
echo Journal complet : %CD%\%LOG%
echo Envoyez ce fichier (logs\transport.log) si un code est different de 0.
echo.
pause
