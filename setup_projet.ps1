# ==============================================================
#  ETAPE 2 - Preparer le projet (a lancer dans le dossier du projet)
#     Set-ExecutionPolicy -Scope Process Bypass -Force
#     .\setup_projet.ps1
#  Sans danger a relancer : ne touche pas au code dans lib/.
# ==============================================================
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\logs" | Out-Null
Start-Transcript -Path "$PSScriptRoot\logs\projet.log" -Force | Out-Null

# PATH a jour meme si la fenetre a ete ouverte avant l'installation
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [Environment]::GetEnvironmentVariable("Path","User")
if (Test-Path "C:\src\flutter\bin") { $env:Path = "C:\src\flutter\bin;" + $env:Path }

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter introuvable. Lancez d'abord setup_windows.ps1 puis rouvrez PowerShell." -ForegroundColor Red
    exit 1
}

# 0. Accepter les licences Android SDK (equivalent de repondre "y" a tout)
Write-Host "==> Licences Android" -ForegroundColor Cyan
("y`n" * 20) | flutter doctor --android-licenses
Write-Host "LICENSES_EXIT=$LASTEXITCODE"

# 1. Generer les dossiers android/ et ios/ s'ils n'existent pas
if (-not (Test-Path "android")) {
    Write-Host "==> Generation des dossiers Android / iOS" -ForegroundColor Cyan
    flutter create . --org tn.esprit --project-name projet_mobile --platforms=android,ios
    # flutter create ajoute un test d'exemple qui ne correspond pas a notre app
    if (Test-Path "test\widget_test.dart") { Remove-Item "test\widget_test.dart" }
}

# 2. Autoriser Internet + HTTP local (API sur http://10.0.2.2)
$manifest = "android\app\src\main\AndroidManifest.xml"
$xml = Get-Content $manifest -Raw
if ($xml -notmatch "android.permission.INTERNET") {
    $xml = $xml -replace '(<manifest[^>]*>)', "`$1`n    <uses-permission android:name=`"android.permission.INTERNET`"/>"
}
if ($xml -notmatch "usesCleartextTraffic") {
    $xml = $xml -replace '<application', '<application android:usesCleartextTraffic="true"'
}
[IO.File]::WriteAllText((Resolve-Path $manifest), $xml, (New-Object System.Text.UTF8Encoding $false))
Write-Host "    OK : AndroidManifest (INTERNET + HTTP)" -ForegroundColor Green

# 3. Dependances
Write-Host "==> flutter pub get" -ForegroundColor Cyan
flutter pub get

# 4. Verifications
Write-Host "==> flutter analyze" -ForegroundColor Cyan
flutter analyze
Write-Host "ANALYZE_EXIT=$LASTEXITCODE"
Write-Host "==> flutter test" -ForegroundColor Cyan
flutter test
Write-Host "TEST_EXIT=$LASTEXITCODE"
Write-Host "==> flutter doctor" -ForegroundColor Cyan
flutter doctor -v

Write-Host @"

Projet pret ! Demarrez un emulateur puis :
   flutter run
(ou F5 dans VS Code / bouton Run dans Android Studio)
"@ -ForegroundColor Yellow

Write-Host "FIN_PROJET"
Stop-Transcript | Out-Null
Read-Host "Appuyez sur Entree pour fermer"
