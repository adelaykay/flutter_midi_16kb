#!/bin/bash

# Complete 16KB alignment verification script
# Tests both built libraries and final APK/AAB

set -e

COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_NC='\033[0m'

echo "========================================"
echo "16 KB Page Size Alignment Verification"
echo "========================================"
echo ""

# Function to check a single library
check_library() {
    local lib_path=$1
    local lib_name=$(basename "$lib_path")

    if [ ! -f "$lib_path" ]; then
        echo -e "${COLOR_YELLOW}⚠️  File not found: $lib_name${COLOR_NC}"
        return 1
    fi

    # Get alignment using readelf
    local alignment=$(readelf -l "$lib_path" 2>/dev/null | grep -A 1 "LOAD" | grep "Align" | head -1 | awk '{print $NF}')

    if [ -z "$alignment" ]; then
        echo -e "${COLOR_RED}✗ $lib_name: Could not read alignment${COLOR_NC}"
        return 1
    fi

    # Convert hex to decimal
    local align_dec=$((alignment))

    # 16 KB = 16384 bytes = 0x4000
    if [ $align_dec -ge 16384 ]; then
        echo -e "${COLOR_GREEN}✓ $lib_name: $alignment ($align_dec bytes) - PASS${COLOR_NC}"
        return 0
    else
        echo -e "${COLOR_RED}✗ $lib_name: $alignment ($align_dec bytes) - FAIL (needs >= 16384)${COLOR_NC}"
        return 1
    fi
}

# Test 1: Check built .so files in build directory
echo "Test 1: Checking built native libraries..."
echo "-------------------------------------------"

FOUND_LIBS=0
PASS_COUNT=0
FAIL_COUNT=0

# Check in common build locations
BUILD_DIRS=(
    "android/build/intermediates/cmake"
    "build/app/intermediates/cmake"
    "../example/build/app/intermediates/cmake"
)

for build_dir in "${BUILD_DIRS[@]}"; do
    if [ -d "$build_dir" ]; then
        echo "Searching in: $build_dir"
        while IFS= read -r -d '' lib; do
            FOUND_LIBS=1
            if check_library "$lib"; then
                ((PASS_COUNT++))
            else
                ((FAIL_COUNT++))
            fi
        done < <(find "$build_dir" -name "*.so" -print0 2>/dev/null)
    fi
done

if [ $FOUND_LIBS -eq 0 ]; then
    echo -e "${COLOR_YELLOW}No .so files found in build directories.${COLOR_NC}"
    echo "Build your app first with: flutter build apk"
    echo ""
fi

echo ""

# Test 2: Check libraries in APK
echo "Test 2: Checking libraries in APK..."
echo "-------------------------------------------"

# Find APK files
APK_PATHS=(
    "build/app/outputs/flutter-apk/app-release.apk"
    "build/app/outputs/flutter-apk/app-debug.apk"
    "../example/build/app/outputs/flutter-apk/app-release.apk"
    "../example/build/app/outputs/flutter-apk/app-debug.apk"
)

APK_FOUND=0

for apk_path in "${APK_PATHS[@]}"; do
    if [ -f "$apk_path" ]; then
        APK_FOUND=1
        echo "Found APK: $apk_path"
        echo ""

        # Create temp directory
        TEMP_DIR=$(mktemp -d)

        # Extract APK
        unzip -q "$apk_path" -d "$TEMP_DIR" 2>/dev/null || {
            echo -e "${COLOR_RED}Failed to extract APK${COLOR_NC}"
            rm -rf "$TEMP_DIR"
            continue
        }

        # Check all .so files in APK
        echo "Checking native libraries in APK:"
        while IFS= read -r -d '' lib; do
            check_library "$lib"
            if [ $? -eq 0 ]; then
                ((PASS_COUNT++))
            else
                ((FAIL_COUNT++))
            fi
        done < <(find "$TEMP_DIR" -name "*.so" -print0 2>/dev/null)

        # Cleanup
        rm -rf "$TEMP_DIR"
        echo ""
        break
    fi
done

if [ $APK_FOUND -eq 0 ]; then
    echo -e "${COLOR_YELLOW}No APK found. Build with: flutter build apk${COLOR_NC}"
    echo ""
fi

# Test 3: Check AAB (Android App Bundle)
echo "Test 3: Checking libraries in AAB..."
echo "-------------------------------------------"

AAB_PATHS=(
    "build/app/outputs/bundle/release/app-release.aab"
    "../example/build/app/outputs/bundle/release/app-release.aab"
)

AAB_FOUND=0

for aab_path in "${AAB_PATHS[@]}"; do
    if [ -f "$aab_path" ]; then
        AAB_FOUND=1
        echo "Found AAB: $aab_path"
        echo ""

        # Create temp directory
        TEMP_DIR=$(mktemp -d)

        # Extract AAB (it's a ZIP file)
        unzip -q "$aab_path" -d "$TEMP_DIR" 2>/dev/null || {
            echo -e "${COLOR_RED}Failed to extract AAB${COLOR_NC}"
            rm -rf "$TEMP_DIR"
            continue
        }

        # Check all .so files in AAB
        echo "Checking native libraries in AAB:"
        while IFS= read -r -d '' lib; do
            check_library "$lib"
            if [ $? -eq 0 ]; then
                ((PASS_COUNT++))
            else
                ((FAIL_COUNT++))
            fi
        done < <(find "$TEMP_DIR" -name "*.so" -print0 2>/dev/null)

        # Cleanup
        rm -rf "$TEMP_DIR"
        echo ""
        break
    fi
done

if [ $AAB_FOUND -eq 0 ]; then
    echo -e "${COLOR_YELLOW}No AAB found. Build with: flutter build appbundle${COLOR_NC}"
    echo ""
fi

# Summary
echo "========================================"
echo "Summary"
echo "========================================"
echo -e "Total checks: $((PASS_COUNT + FAIL_COUNT))"
echo -e "${COLOR_GREEN}Passed: $PASS_COUNT${COLOR_NC}"
echo -e "${COLOR_RED}Failed: $FAIL_COUNT${COLOR_NC}"
echo ""

if [ $FAIL_COUNT -eq 0 ] && [ $PASS_COUNT -gt 0 ]; then
    echo -e "${COLOR_GREEN}✓ All libraries are 16 KB aligned!${COLOR_NC}"
    echo "Your app is ready for Google Play Store."
    echo ""
    exit 0
else
    if [ $PASS_COUNT -eq 0 ]; then
        echo -e "${COLOR_YELLOW}⚠️  No libraries were checked.${COLOR_NC}"
        echo ""
        echo "Next steps:"
        echo "1. Build your app: flutter build apk"
        echo "2. Run this script again"
    else
        echo -e "${COLOR_RED}✗ Some libraries are NOT 16 KB aligned!${COLOR_NC}"
        echo ""
        echo "This will cause issues on Android 15+ devices."
        echo "Check your CMakeLists.txt for the alignment flags."
    fi
    echo ""
    exit 1
fi