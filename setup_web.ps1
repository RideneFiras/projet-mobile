# ==============================================================
#  VERSION WEB (Chrome) : tester l'application sans emulateur.
#  Ajoute le dossier web/ et les fichiers SQLite pour le navigateur.
# ==============================================================
Set-Location $PSScriptRoot
New-Item -ItemType Directory -Force -Path "$PSScriptRoot\logs" | Out-Null
Start-Transcript -Path "$PSScriptRoot\logs\web.log" -Force | Out-Null
$env:Path = [Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
            [Environment]::GetEnvironmentVariable("Path","User")
if (Test-Path "C:\src\flutter\bin") { $env:Path = "C:\src\flutter\bin;" + $env:Path }

Write-Host "==> Ajout de la plateforme web" -ForegroundColor Cyan
if (-not (Test-Path "web\index.html")) {
    flutter create --platforms=web --project-name projet_mobile . 2>&1 | Out-Host
    Write-Host "CREATE_EXIT=$LASTEXITCODE"
}
if (Test-Path "test\widget_test.dart") { Remove-Item "test\widget_test.dart" }

Write-Host "==> flutter pub get" -ForegroundColor Cyan
flutter pub get 2>&1 | Out-Host
Write-Host "PUBGET_EXIT=$LASTEXITCODE"

Write-Host "==> Fichiers SQLite web (sqlite3.wasm, sqflite_sw.js)" -ForegroundColor Cyan
# Android Studio doit etre FERME (sinon fichier verrouille dans .dart_tool)
for ($i = 1; $i -le 3; $i++) {
    dart run sqflite_common_ffi_web:setup 2>&1 | Out-Host
    if ($LASTEXITCODE -eq 0) { break }
    Write-Host "Nouvel essai dans 5 s..." -ForegroundColor Yellow
    Start-Sleep -Seconds 5
}
Write-Host "SETUP_EXIT=$LASTEXITCODE"

Write-Host "==> flutter analyze" -ForegroundColor Cyan
flutter analyze 2>&1 | Out-Host
Write-Host "ANALYZE_EXIT=$LASTEXITCODE"

Write-Host "==> flutter test" -ForegroundColor Cyan
flutter test 2>&1 | Out-Host
Write-Host "TEST_EXIT=$LASTEXITCODE"

Get-ChildItem web | Format-Table Name, Length | Out-Host
Write-Host "FIN_WEB"
Stop-Transcript | Out-Null
Read-Host "Appuyez sur Entree pour fermer"
