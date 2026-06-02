#!/bin/bash
#
# apply-afrezza-patches.sh
#
# Clones AAPS dev branch, applies the Afrezza patches, and prepares for building.
#
# Usage:
#   ./apply-afrezza-patches.sh [target_directory]
#
# Example:
#   ./apply-afrezza-patches.sh ~/AndroidAPS-Afrezza
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/patches"
TARGET_DIR="${1:-$SCRIPT_DIR/../AndroidAPS-Afrezza}"

echo "============================================"
echo "  Afrezza AAPS Plugin — Patch Applicator"
echo "============================================"
echo ""

# Check patches exist
if [ ! -f "$PATCHES_DIR/afrezza-combined.patch" ]; then
    echo "ERROR: Patch files not found in $PATCHES_DIR"
    echo "       Make sure you're running this from the repository root."
    exit 1
fi

# Check git is installed
if ! command -v git &> /dev/null; then
    echo "ERROR: git is not installed. Please install git first."
    exit 1
fi

# Step 1: Clone AAPS
if [ -d "$TARGET_DIR/.git" ]; then
    echo "[1/4] Target directory exists, using existing repo: $TARGET_DIR"
    cd "$TARGET_DIR"
else
    echo "[1/4] Cloning AAPS repository to $TARGET_DIR ..."
    git clone https://github.com/nightscout/AndroidAPS.git "$TARGET_DIR"
    cd "$TARGET_DIR"
fi

# Step 2: Switch to dev branch
echo "[2/4] Switching to dev branch..."
git checkout dev
git pull origin dev

# Step 3: Create feature branch
BRANCH_NAME="feature/afrezza-inhaled-insulin"
if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
    echo "       Branch $BRANCH_NAME already exists. Switching to it."
    git checkout "$BRANCH_NAME"
else
    echo "[3/4] Creating feature branch: $BRANCH_NAME"
    git checkout -b "$BRANCH_NAME"
fi

# Step 4: Apply patches
echo "[4/4] Applying Afrezza patches..."
if git am --3way < "$PATCHES_DIR/afrezza-combined.patch"; then
    echo ""
    echo "============================================"
    echo "  SUCCESS — All patches applied!"
    echo "============================================"
    echo ""
    echo "  Repository: $TARGET_DIR"
    echo "  Branch:     $BRANCH_NAME"
    echo ""
    echo "  Next steps:"
    echo "    1. Open in Android Studio"
    echo "    2. Run tests:  ./gradlew :core:data:test --tests '*ICfgAfrezzaIobTest*'"
    echo "    3. Build APK:  ./gradlew assembleFullDebug"
    echo "    4. Build Wear: ./gradlew :wear:assembleFullDebug"
    echo ""
else
    echo ""
    echo "WARNING: Some patches had conflicts."
    echo "Resolve the conflicts, then run:"
    echo "  cd $TARGET_DIR"
    echo "  git add ."
    echo "  git am --continue"
    echo ""
fi
