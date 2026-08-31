#!/usr/bin/env bash
#
# apply-afrezza-patches.sh
#
# Clones AndroidAPS, checks out the exact tested base commit, and applies the
# Afrezza patch with `git apply`.
#
# The patch is a plain `git diff` (not a format-patch), so it is applied with
# `git apply`, NOT `git am`. It was generated and verified against AndroidAPS dev
# at commit 283a184f60eb8b18dac42e228faebbe260c3aa22 and applies cleanly there
# with zero conflicts. Applying onto a newer dev requires `--3way` and manual
# conflict resolution - see README (NOT recommended for dosing-relevant files).
#
# Usage: ./apply-afrezza-patches.sh [target_dir]
#
set -euo pipefail

BASE_COMMIT="283a184f60eb8b18dac42e228faebbe260c3aa22"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${1:-$SCRIPT_DIR/../AndroidAPS-Afrezza}"
COMBINED_PATCH="$SCRIPT_DIR/patches/afrezza-combined.patch"

echo "============================================"
echo "  Afrezza AAPS Plugin - Patch Applicator"
echo "============================================"
echo

[ -f "$COMBINED_PATCH" ] || { echo "ERROR: patch not found at $COMBINED_PATCH"; exit 1; }
command -v git >/dev/null || { echo "ERROR: git is not installed."; exit 1; }

if [ -d "$TARGET_DIR/.git" ]; then
  echo "[1/4] Using existing repo: $TARGET_DIR"
  cd "$TARGET_DIR"
else
  echo "[1/4] Cloning AndroidAPS to $TARGET_DIR ..."
  git clone https://github.com/nightscout/AndroidAPS.git "$TARGET_DIR"
  cd "$TARGET_DIR"
fi

echo "[2/4] Checking out tested base commit $BASE_COMMIT ..."
git fetch origin
git checkout "$BASE_COMMIT"

BRANCH="feature/afrezza-inhaled-insulin"
echo "[3/4] Creating feature branch: $BRANCH"
git branch -D "$BRANCH" 2>/dev/null || true
git checkout -b "$BRANCH"

echo "[4/4] Applying Afrezza patch..."
if git apply --verbose "$COMBINED_PATCH"; then
  git add -A
  git commit -m "Add Afrezza inhaled insulin support" >/dev/null
  echo
  echo "============================================"
  echo "  SUCCESS - patch applied and committed."
  echo "============================================"
  echo "  Repository: $TARGET_DIR"
  echo "  Branch:     $BRANCH"
  echo "  Base:       $BASE_COMMIT"
  echo
  echo "  Next: open in Android Studio, then"
  echo "    ./gradlew assembleFullDebug"
  echo "    ./gradlew :wear:assembleFullDebug"
  echo
  echo "  READ THE README SAFETY NOTICE BEFORE USING THIS ON A PUMP."
  echo
else
  echo
  echo "ERROR: patch did not apply cleanly on $BASE_COMMIT."
  echo "This base is the tested one and should apply without conflicts."
  echo "If you changed the base commit, that is the likely cause."
  exit 1
fi
