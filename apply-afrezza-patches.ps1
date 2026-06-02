#
# apply-afrezza-patches.ps1
#
# Clones AAPS dev branch, applies the Afrezza patches, and prepares for building.
#
# Usage:
#   .\apply-afrezza-patches.ps1 [-TargetDir "C:\path\to\AndroidAPS-Afrezza"]
#

param(
    [string]$TargetDir = "$PSScriptRoot\..\AndroidAPS-Afrezza"
)

$ErrorActionPreference = "Stop"
$PatchesDir = Join-Path $PSScriptRoot "patches"
$CombinedPatch = Join-Path $PatchesDir "afrezza-combined.patch"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Afrezza AAPS Plugin - Patch Applicator" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check patches exist
if (-not (Test-Path $CombinedPatch)) {
    Write-Host "ERROR: Patch files not found in $PatchesDir" -ForegroundColor Red
    Write-Host "       Make sure you're running this from the repository root." -ForegroundColor Red
    exit 1
}

# Check git is installed
try {
    git --version | Out-Null
} catch {
    Write-Host "ERROR: git is not installed. Please install git first." -ForegroundColor Red
    exit 1
}

# Step 1: Clone AAPS
if (Test-Path (Join-Path $TargetDir ".git")) {
    Write-Host "[1/4] Target directory exists, using existing repo: $TargetDir" -ForegroundColor Yellow
    Set-Location $TargetDir
} else {
    Write-Host "[1/4] Cloning AAPS repository to $TargetDir ..." -ForegroundColor Green
    git clone https://github.com/nightscout/AndroidAPS.git $TargetDir
    Set-Location $TargetDir
}

# Step 2: Switch to dev branch
Write-Host "[2/4] Switching to dev branch..." -ForegroundColor Green
git checkout dev
git pull origin dev

# Step 3: Create feature branch
$BranchName = "feature/afrezza-inhaled-insulin"
$branchExists = git branch --list $BranchName
if ($branchExists) {
    Write-Host "       Branch $BranchName already exists. Switching to it." -ForegroundColor Yellow
    git checkout $BranchName
} else {
    Write-Host "[3/4] Creating feature branch: $BranchName" -ForegroundColor Green
    git checkout -b $BranchName
}

# Step 4: Apply patches
Write-Host "[4/4] Applying Afrezza patches..." -ForegroundColor Green
$patchContent = Get-Content $CombinedPatch -Raw
$patchContent | git am --3way

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  SUCCESS - All patches applied!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Repository: $TargetDir" -ForegroundColor White
    Write-Host "  Branch:     $BranchName" -ForegroundColor White
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor Cyan
    Write-Host "    1. Open in Android Studio" -ForegroundColor White
    Write-Host "    2. Run tests:  .\gradlew.bat :core:data:test --tests '*ICfgAfrezzaIobTest*'" -ForegroundColor White
    Write-Host "    3. Build APK:  .\gradlew.bat assembleFullDebug" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "WARNING: Some patches had conflicts." -ForegroundColor Yellow
    Write-Host "Resolve the conflicts in Android Studio or your editor, then run:" -ForegroundColor Yellow
    Write-Host "  cd $TargetDir" -ForegroundColor White
    Write-Host "  git add ." -ForegroundColor White
    Write-Host "  git am --continue" -ForegroundColor White
    Write-Host ""
}
