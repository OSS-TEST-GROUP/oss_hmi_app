#!/usr/bin/env bash
# R010 T2: Yocto Layer Fetching Script (Host Execution)
#
# Purpose: Clone AGL/Yocto layers to host directory for Docker COPY/mount
# Strategy: Host git clone + Docker COPY (fast, reproducible)
# Risk R5 Mitigation: Pin to specific commit hash for reproducibility
#
# Usage:
#   bash scripts/yocto-fetch-layers.sh [--dry-run]
#
# Output: yocto/sources/ populated with layers
# Note: This session does DRY RUN only - full clone deferred to session 2

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SOURCES_DIR="${PROJECT_ROOT}/yocto/sources"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# ===================================================================
# Layer Configuration (URLs, Branches, Commit Hashes)
# ===================================================================
# Risk R5 Mitigation: Pin to known-good commits for reproducibility
# Update these hashes after testing new layer versions

declare -A LAYERS=(
    # Core Yocto layer (Scarthgap)
    ["poky"]="https://git.yoctoproject.org/poky|scarthgap|HEAD"

    # OpenEmbedded layers (Scarthgap)
    ["meta-openembedded"]="https://git.openembedded.org/meta-openembedded|scarthgap|HEAD"

    # AGL core layers (Trout 20.0.3 ~ scarthgap compatible)
    ["meta-agl"]="https://gerrit.automotivelinux.org/gerrit/AGL/meta-agl|trout|HEAD"

    # Flutter layer (if needed for AGL integration tests)
    ["meta-flutter"]="https://github.com/meta-flutter/meta-flutter|main|HEAD"

    # Qt5 layer (Scarthgap - required for qtwayland)
    ["meta-qt5"]="https://github.com/meta-qt5/meta-qt5|scarthgap|HEAD"

    # ROS2 layers (Humble + Scarthgap best-effort)
    ["meta-ros"]="https://github.com/ros/meta-ros|scarthgap|HEAD"
)

# ===================================================================
# Functions
# ===================================================================

log() {
    echo "[$(date +%H:%M:%S)] $*" >&2
}

clone_layer() {
    local name=$1
    local url=$2
    local branch=$3
    local commit=$4
    local dest="${SOURCES_DIR}/${name}"

    if [[ -d "${dest}/.git" ]]; then
        log "SKIP: ${name} already exists at ${dest}"
        return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log "DRY-RUN: Would clone ${name} (${url} branch=${branch})"
        return 0
    fi

    log "Cloning ${name} (branch=${branch}) to ${dest} ..."
    git clone --branch "${branch}" --depth=1 "${url}" "${dest}"

    if [[ "${commit}" != "HEAD" ]]; then
        log "  Checking out commit ${commit} ..."
        git -C "${dest}" fetch --depth=1 origin "${commit}"
        git -C "${dest}" checkout "${commit}"
    fi

    log "  ✓ ${name} cloned successfully"
}

# ===================================================================
# Main
# ===================================================================

log "R010 T2: Yocto Layer Fetch (${DRY_RUN:+DRY-RUN})"
log "Target: ${SOURCES_DIR}"

# Create sources directory
mkdir -p "${SOURCES_DIR}"

# Dry-run validation only in this session
if [[ "${DRY_RUN}" == "true" ]]; then
    log "=== DRY-RUN Mode: Validating layer configuration ==="
    for layer_name in "${!LAYERS[@]}"; do
        IFS='|' read -r url branch commit <<< "${LAYERS[${layer_name}]}"
        log "  - ${layer_name}: ${url} (${branch}@${commit})"
    done
    log ""
    log "Configuration valid. Run without --dry-run in session 2 to clone."
    exit 0
fi

# Actual cloning (deferred to session 2)
log "=== Cloning Layers ==="
for layer_name in "${!LAYERS[@]}"; do
    IFS='|' read -r url branch commit <<< "${LAYERS[${layer_name}]}"
    clone_layer "${layer_name}" "${url}" "${branch}" "${commit}"
done

# Special handling: meta-ros has subdirectories
if [[ -d "${SOURCES_DIR}/meta-ros" ]]; then
    log "✓ meta-ros cloned (contains meta-ros2, meta-ros2-humble subdirectories)"
fi

# Verify meta-rviz2-agl (should already exist in repo)
if [[ ! -d "${PROJECT_ROOT}/yocto/meta-rviz2-agl/conf/layer.conf" ]]; then
    log "ERROR: meta-rviz2-agl not found in yocto/meta-rviz2-agl/"
    exit 1
fi

log ""
log "=== Layer Fetch Complete ==="
log "Next steps (session 2):"
log "  1. Review yocto/sources/ directory"
log "  2. Customize build/conf/local.conf and bblayers.conf"
log "  3. Run bitbake rviz2 (4-8 hours estimated)"

# Disk usage estimate
if command -v du &>/dev/null; then
    du_result=$(du -sh "${SOURCES_DIR}" 2>/dev/null || echo "N/A")
    log "Current sources/ disk usage: ${du_result}"
fi
