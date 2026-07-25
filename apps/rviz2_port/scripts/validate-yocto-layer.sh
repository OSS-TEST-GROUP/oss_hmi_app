#!/bin/bash
# validate-yocto-layer.sh — Comprehensive meta-rviz2-agl layer validation
#
# Purpose: Validate Yocto layer structure and bbappend files
# Usage: ./scripts/validate-yocto-layer.sh
# Exit code: 0=success, 1=error

set -euo pipefail

PROJECT_ROOT="/home/obigo/project/oss/oss_agent2"
LAYER_DIR="$PROJECT_ROOT/yocto/meta-rviz2-agl"

errors=0
warnings=0

echo "=== meta-rviz2-agl Layer Validation ==="
echo ""

# 1. Check layer.conf exists
if [ ! -f "$LAYER_DIR/conf/layer.conf" ]; then
    echo "ERROR: layer.conf not found at $LAYER_DIR/conf/layer.conf"
    ((errors++))
else
    echo "✓ layer.conf exists"

    # Check LAYERDEPENDS
    if grep -q "LAYERDEPENDS.*meta-ros2-humble" "$LAYER_DIR/conf/layer.conf"; then
        echo "  ✓ LAYERDEPENDS includes meta-ros2-humble"
    else
        echo "  ERROR: LAYERDEPENDS does not include meta-ros2-humble"
        ((errors++))
    fi
fi

# 2. Check recipe directories
echo ""
echo "=== Recipe Directory Structure ==="
required_dirs=(
    "$LAYER_DIR/recipes-ros2/ogre"
    "$LAYER_DIR/recipes-ros2/rviz2"
    "$LAYER_DIR/recipes-ros2/rviz2/files"
)

for dir in "${required_dirs[@]}"; do
    if [ -d "$dir" ]; then
        echo "✓ Directory exists: $(basename "$dir")"
    else
        echo "ERROR: Directory missing: $dir"
        ((errors++))
    fi
done

# 3. Run bbappend lint
echo ""
echo "=== Running bbappend lint ==="
if ./scripts/lint-bbappend.sh; then
    echo "✓ bbappend lint PASSED"
else
    echo "ERROR: bbappend lint FAILED"
    ((errors++))
fi

# 4. Validate patch file format
echo ""
echo "=== Patch File Validation ==="
patch_file="$LAYER_DIR/recipes-ros2/rviz2/files/0001-wayland-xcb-fallback-guard.patch"

if [ -f "$patch_file" ]; then
    echo "✓ Patch file exists: $(basename "$patch_file")"

    # Check git format-patch headers
    if grep -q "^From [0-9a-f]\{40\}" "$patch_file"; then
        echo "  ✓ Valid git format-patch header"
    else
        echo "  WARNING: Missing git format-patch commit hash header"
        ((warnings++))
    fi

    if grep -q "^Subject:" "$patch_file"; then
        echo "  ✓ Subject header present"
    else
        echo "  ERROR: Missing Subject header"
        ((errors++))
    fi

    # Check applicability
    pushd "$PROJECT_ROOT/hmi/rviz_agl" >/dev/null
    if git apply --check "$patch_file" 2>/dev/null; then
        echo "  ✓ Patch applies cleanly to hmi/rviz_agl"
    else
        echo "  ERROR: Patch does NOT apply to hmi/rviz_agl"
        ((errors++))
    fi
    popd >/dev/null
else
    echo "ERROR: Patch file not found: $patch_file"
    ((errors++))
fi

# 5. External repo non-modification check
echo ""
echo "=== External Repo Policy Check ==="
if [ -d "$PROJECT_ROOT/hmi/rviz_agl/.git" ]; then
    cd "$PROJECT_ROOT/hmi/rviz_agl"
    # Check only for modified/staged files (exclude untracked)
    if git diff --quiet && git diff --cached --quiet; then
        echo "✓ External repo hmi/rviz_agl is clean (no modifications)"
    else
        echo "ERROR: External repo hmi/rviz_agl has modified files:"
        git status --short | grep -v "^??"
        ((errors++))
    fi
    cd "$PROJECT_ROOT"
else
    echo "WARNING: hmi/rviz_agl is not a git repository"
    ((warnings++))
fi

# 6. Cross-layer integration check
echo ""
echo "=== Cross-Layer Integration ==="

# Check OGRE version compatibility with RViz2
ogre_version=$(grep -E '^PV\s*=' "$LAYER_DIR/recipes-ros2/ogre/ogre_%.bbappend" | sed -E 's/.*"([^"]+)".*/\1/')
echo "OGRE version: $ogre_version"

if [[ "$ogre_version" =~ ^14\.[3-9] ]] || [[ "$ogre_version" =~ ^14\.[0-9]{2} ]]; then
    echo "  ✓ OGRE version >= 14.3.0 (Wayland support confirmed)"
else
    echo "  ERROR: OGRE version $ogre_version < 14.3.0 (Wayland support unavailable)"
    ((errors++))
fi

# Check RViz2 bbappend references OGRE dependency
if grep -q "qtwayland" "$LAYER_DIR/recipes-ros2/rviz2/rviz2_%.bbappend"; then
    echo "  ✓ RViz2 bbappend includes qtwayland dependency"
else
    echo "  ERROR: RViz2 bbappend missing qtwayland dependency"
    ((errors++))
fi

# Summary
echo ""
echo "=== Validation Summary ==="
echo "Errors:   $errors"
echo "Warnings: $warnings"

if [ $errors -eq 0 ]; then
    echo ""
    echo "✓ Layer validation PASSED"
    if [ $warnings -gt 0 ]; then
        echo "  (with $warnings warnings)"
    fi
    exit 0
else
    echo ""
    echo "✗ Layer validation FAILED with $errors error(s)"
    exit 1
fi
