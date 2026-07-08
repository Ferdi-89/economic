# Financier - Setup script
# Run this from PowerShell (right-click → "Run with PowerShell" or type each block manually)

Write-Host "=== 1. Install Flutter dependencies ===" -ForegroundColor Cyan
Set-Location "E:\Project's\Mobile\Economic\financier"
flutter pub get
if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: flutter pub get" -ForegroundColor Red; exit 1 }

Write-Host "=== 2. Generate Freezed/JSON code ===" -ForegroundColor Cyan
dart run build_runner build --delete-conflicting-outputs
if ($LASTEXITCODE -ne 0) { Write-Host "FAILED: build_runner" -ForegroundColor Red; exit 1 }

Write-Host "=== 3. Analyze ===" -ForegroundColor Cyan
flutter analyze
if ($LASTEXITCODE -ne 0) { Write-Host "WARN: flutter analyze has issues" -ForegroundColor Yellow }

Write-Host "=== 4. Git init & push to GitHub ===" -ForegroundColor Cyan
Set-Location "E:\Project's\Mobile"
git init
git remote remove origin 2>$null
git remote add origin https://github.com/Ferdi-89/economic.git
git add -A
git commit -m "Initial commit: Financier - Personal Finance Tracker"
git branch -M main
git push -u origin main

Write-Host "=== DONE ===" -ForegroundColor Green
