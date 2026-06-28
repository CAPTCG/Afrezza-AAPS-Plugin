#
# apply-afrezza-patches.ps1
#
# Clones AndroidAPS, checks out the exact tested base commit, and applies the
# Afrezza patch with `git apply`.
#
# The patch is a plain `git diff` (not a format-patch), so it is applied with
# `git apply`, NOT `git am`. It was generated and verified against AndroidAPS dev
# at commit 6afc35c058fe8ee915bb874da8027101ffcaa6c3, and applies cleanly there
# with zero conflicts. Applying onto a newer dev requires `--3way` and manual
# conflict resolution - see README (NOT recommended for dosing-relevant files).
#
# Usage:
#   .\apply-afrezza-patches.ps1 [-TargetDir "C:\path\to\AndroidAPS-Afrezza"]
#

param(
    [string]$TargetDir = "$PSScriptRoot\..\AndroidAPS-Afrezza"
)

$ErrorActionPreference = "Stop"
$BaseCommit    = "6afc35c058fe8ee915bb874da8027101ffcaa6c3"
$PatchesDir    = Join-Path $PSScriptRoot "patches"
$CombinedPatch = Join-Path $PatchesDir "afrezza-combined.patch"

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Afrezza AAPS Plugin - Patch Applicator" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Path $CombinedPatch)) {
    Write-Host "ERROR: Patch not found at $CombinedPatch" -ForegroundColor Red
    exit 1
}
try { git --version | Out-Null } catch {
    Write-Host "ERROR: git is not installed." -ForegroundColor Red; exit 1
}

# Step 1: Clone (or reuse) AAPS
if (Test-Path (Join-Path $TargetDir ".git")) {
    Write-Host "[1/4] Using existing repo: $TargetDir" -ForegroundColor Yellow
    Set-Location $TargetDir
} else {
    Write-Host "[1/4] Cloning AndroidAPS to $TargetDir ..." -ForegroundColor Green
    git clone https://github.com/nightscout/AndroidAPS.git $TargetDir
    Set-Location $TargetDir
}

# Step 2: Check out the EXACT base commit this patch was tested against.
Write-Host "[2/4] Checking out tested base commit $BaseCommit ..." -ForegroundColor Green
git fetch origin
git checkout $BaseCommit
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: could not checkout $BaseCommit. Is this the nightscout/AndroidAPS repo?" -ForegroundColor Red
    exit 1
}

# Step 3: Create a feature branch at that commit
$BranchName = "feature/afrezza-inhaled-insulin"
Write-Host "[3/4] Creating feature branch: $BranchName" -ForegroundColor Green
git branch -D $BranchName 2>$null
git checkout -b $BranchName

# Step 4: Apply the patch (plain git apply - clean on this base)
Write-Host "[4/4] Applying Afrezza patch..." -ForegroundColor Green
git apply --verbose $CombinedPatch
if ($LASTEXITCODE -eq 0) {
    git add -A
    git commit -m "Add Afrezza inhaled insulin support" | Out-Null
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  SUCCESS - patch applied and committed." -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Repository: $TargetDir"  -ForegroundColor White
    Write-Host "  Branch:     $BranchName" -ForegroundColor White
    Write-Host "  Base:       $BaseCommit" -ForegroundColor White
    Write-Host ""
    Write-Host "  Next steps:" -ForegroundColor Cyan
    Write-Host "    1. Open in Android Studio" -ForegroundColor White
    Write-Host "    2. Build APK:  .\gradlew.bat assembleFullDebug" -ForegroundColor White
    Write-Host "    3. Build Wear: .\gradlew.bat :wear:assembleFullDebug" -ForegroundColor White
    Write-Host ""
    Write-Host "  READ THE README SAFETY NOTICE BEFORE USING THIS ON A PUMP." -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "ERROR: patch did not apply cleanly on $BaseCommit." -ForegroundColor Red
    Write-Host "This base is the tested one and should apply without conflicts." -ForegroundColor Red
    Write-Host "If you changed the base commit, that is the likely cause." -ForegroundColor Red
    Write-Host ""
}
