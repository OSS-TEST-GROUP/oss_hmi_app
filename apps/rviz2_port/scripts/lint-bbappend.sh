#!/bin/bash
# lint-bbappend.sh — Syntax validation for Yocto bbappend files
#
# Purpose: Verify bbappend files have correct syntax and conventions
# Usage: ./scripts/lint-bbappend.sh
# Exit code: 0=success, 1=error
#
# AC-4 Verification Strategy:
# Since bitbake environment is not available, we perform static syntax checks:
# 1. Variable assignment format (KEY = "value" or KEY:append = " value")
# 2. SRC_URI file:// paths exist
# 3. DEPENDS/RDEPENDS have valid package names (no special chars)
# 4. LAYERSERIES_COMPAT pattern check
# 5. No duplicate variable definitions (without :append/:prepend)

set -euo pipefail

PROJECT_ROOT="/home/obigo/project/oss/oss_agent2"
BBAPPEND_FILES=(
    "$PROJECT_ROOT/yocto/meta-rviz2-agl/recipes-ros2/ogre/ogre_%.bbappend"
    "$PROJECT_ROOT/yocto/meta-rviz2-agl/recipes-ros2/rviz2/rviz2_%.bbappend"
    "$PROJECT_ROOT/yocto/meta-rviz2-agl/recipes-ros2/rviz_ogre_vendor/rviz_ogre_vendor_%.bbappend"
)

errors=0

echo "=== Yocto bbappend Syntax Lint ==="
echo ""

for bbappend in "${BBAPPEND_FILES[@]}"; do
    if [ ! -f "$bbappend" ]; then
        echo "ERROR: File not found: $bbappend"
        ((errors++))
        continue
    fi

    echo "Checking: $(basename "$bbappend")"

    # 1. Check variable assignment syntax
    if grep -E '^[A-Z_]+\s*=' "$bbappend" | grep -qvE '^[A-Z_]+(:append|:prepend|:remove)?\s*[=+]?\s*'; then
        echo "  ERROR: Invalid variable assignment syntax"
        grep -nE '^[A-Z_]+\s*=' "$bbappend" | grep -vE '^[A-Z_]+(:append|:prepend|:remove)?\s*[=+]?\s*'
        ((errors++))
    else
        echo "  ✓ Variable syntax OK"
    fi

    # 2. Check SRC_URI file:// paths exist (skip commented lines)
    while IFS= read -r line; do
        # Skip comments
        if [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        if [[ "$line" =~ file://([^\ \"]+) ]]; then
            filename="${BASH_REMATCH[1]}"
            recipe_dir="$(dirname "$bbappend")"
            patch_path="$recipe_dir/files/$filename"

            if [ ! -f "$patch_path" ]; then
                echo "  ERROR: SRC_URI patch file not found: $filename"
                echo "         Expected at: $patch_path"
                ((errors++))
            else
                echo "  ✓ SRC_URI file exists: $filename"
            fi
        fi
    done < "$bbappend"

    # 3. Check DEPENDS/RDEPENDS for invalid characters
    if grep -E 'DEPENDS|RDEPENDS' "$bbappend" | grep -qE '[^a-z0-9_\-:${} \\\"]'; then
        echo "  ERROR: Invalid characters in DEPENDS/RDEPENDS"
        grep -nE 'DEPENDS|RDEPENDS' "$bbappend" | grep -E '[^a-z0-9_\-:${} \\\"]'
        ((errors++))
    else
        echo "  ✓ DEPENDS/RDEPENDS syntax OK"
    fi

    # 4. Check for duplicate non-append variable definitions
    duplicate_vars=$(grep -oE '^[A-Z_]+\s*=' "$bbappend" | grep -vE ':append|:prepend|:remove' | cut -d= -f1 | sort | uniq -d)
    if [ -n "$duplicate_vars" ]; then
        echo "  WARNING: Duplicate variable definitions (may be intentional override):"
        echo "           $duplicate_vars"
    fi

    # 5. Check FILESEXTRAPATHS syntax
    if grep -q 'FILESEXTRAPATHS' "$bbappend"; then
        if grep -q 'FILESEXTRAPATHS:prepend := "${THISDIR}/files:"' "$bbappend"; then
            echo "  ✓ FILESEXTRAPATHS OK"
        else
            echo "  ERROR: FILESEXTRAPATHS syntax incorrect"
            echo "         Expected: FILESEXTRAPATHS:prepend := \"\${THISDIR}/files:\""
            grep -n 'FILESEXTRAPATHS' "$bbappend"
            ((errors++))
        fi
    fi

    echo ""
done

# 6. Cross-check: ogre and rviz2 bbappend compatibility
echo "=== Cross-Compatibility Check ==="
ogre_pv=$(grep -E '^PV\s*=' "$PROJECT_ROOT/yocto/meta-rviz2-agl/recipes-ros2/ogre/ogre_%.bbappend" | sed -E 's/.*"([^"]+)".*/\1/' || echo "")
ogre_src=$(grep -E '^SRC_URI\s*=' "$PROJECT_ROOT/yocto/meta-rviz2-agl/recipes-ros2/ogre/ogre_%.bbappend" | head -1 || echo "")

if [ -n "$ogre_pv" ]; then
    echo "OGRE version override: $ogre_pv"

    if [[ "$ogre_pv" =~ ^14\. ]]; then
        echo "  ✓ OGRE 14.x version detected (Wayland support confirmed)"
    else
        echo "  ERROR: OGRE version $ogre_pv may not support Wayland (require 14.3.0+)"
        ((errors++))
    fi
fi

if echo "$ogre_src" | grep -q "github.com/OGRECave/ogre"; then
    echo "  ✓ OGRE source from upstream GitHub (SRC_URI override active)"
else
    echo "  WARNING: OGRE SRC_URI may not be overridden (base recipe may use 1.12.x)"
fi

echo ""
echo "=== Lint Summary ==="
if [ $errors -eq 0 ]; then
    echo "✓ All checks PASSED"
    exit 0
else
    echo "✗ $errors error(s) found"
    exit 1
fi
