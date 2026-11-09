# ==============================================================
#  ETAPE 1 - Installation de l'environnement Flutter (Windows 10/11)
#  A lancer UNE SEULE FOIS par PC, dans PowerShell "Administrateur" :
#     Set-ExecutionPolicy -Scope Process Bypass -Force
#     .\setup_windows.ps1
# ==============================================================
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\logs" | Out-Null
Start-Transcript -Path "$PSScriptRoot\logs\install.log" -Force | Out-Null

function Info($m) { Write-Host "`n==> $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "    OK : $m" -ForegroundColor Green }

# --- 0. winget disponible ? ---
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "winget introuvable. Installez 'App Installer' depuis le Microsoft Store puis relancez." -ForegroundColor Red
    exit 1
}

# --- 1. Git, VS Code, Android Studio ---
$apps = @(
    @{ id = "Git.Git";                     nom = "Git" },
    @{ id = "Microsoft.VisualStudioCode";  nom = "Visual Studio Code" },
    @{ id = "Google.AndroidStudio";        nom = "Android Studio" }
)
foreach ($a in $apps) {
    Info "Installation de $($a.nom)"
    winget install --id $a.id -e --accept-source-agreements --accept-package-agreements --silent
    Ok $a.nom
}

# Rafraichir le PATH de la session (pour git)
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [Environment]::GetEnvironmentVariable("Path","User")

# --- 2. Flutter SDK (branche stable) dans C:\src\flutter ---
$flutterDir = "C:\src\flutter"
Info "Installation du SDK Flutter dans $flutterDir"
if (-not (Test-Path $flutterDir)) {
    New-Item -ItemType Directory -Force -Path "C:\src" | Out-Null
    git clone https://github.com/flutter/flutter.git -b stable $flutterDir
} else {
    Ok "Flutter deja present, mise a jour"
    git -C $flutterDir pull
}

# --- 3. Ajouter Flutter au PATH utilisateur ---
$userPath = [Environment]::GetEnvironmentVariable("Path","User")
if ($userPath -notlike "*$flutterDir\bin*") {
    [Environment]::SetEnvironmentVariable("Path", "$userPath;$flutterDir\bin", "User")
    Ok "Flutter ajoute au PATH"
}
$env:Path += ";$flutterDir\bin"

# --- 4. Premier lancement + extensions VS Code ---
Info "Premier lancement de Flutter (telechargement du Dart SDK, quelques minutes)"
flutter config --no-analytics | Out-Null
flutter precache --android

Info "Extensions VS Code Flutter + Dart"
$code = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
if (Test-Path $code) { & $code --install-extension Dart-Code.flutter --force }

# --- 5. Etapes manuelles restantes ---
Write-Host @"

==============================================================
 PRESQUE FINI ! Etapes manuelles (une seule fois) :

 1. Ouvrez Android Studio -> suivez l'assistant "Standard"
    (il installe Android SDK + un emulateur).
 2. Android Studio > More Actions > SDK Manager > onglet "SDK Tools"
    cochez "Android SDK Command-line Tools (latest)" -> Apply.
 3. Android Studio > Plugins > installez "Flutter" (installe aussi Dart).
 4. Android Studio > More Actions > Virtual Device Manager
    -> Create Device (ex: Pixel 7, API 34+).
 5. FERMEZ puis rouvrez PowerShell, puis tapez :
       flutter doctor --android-licenses   (repondez y a tout)
       flutter doctor
    Tout doit etre coche [v] pour Android.

 Ensuite : lancez setup_projet.ps1 dans le dossier du projet.
==============================================================
"@ -ForegroundColor Yellow

Write-Host "FIN_INSTALLATION"
Stop-Transcript | Out-Null
Read-Host "Appuyez sur Entree pour fermer"
