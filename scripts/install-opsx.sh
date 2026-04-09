#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# gentle-ai OPSX — Install Script
# Compiles the OPSX fork and syncs it, creating the full config from scratch.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/JuanCruzRobledo/Gentle-Ai-Stack-SDD-OPSX/main/scripts/install-opsx.sh | bash
#
# Requires: Go 1.24+, git
# ============================================================================

GITHUB_OWNER="JuanCruzRobledo"
GITHUB_REPO="Gentle-Ai-Stack-SDD-OPSX"
BINARY_NAME="gentle-ai"

# ============================================================================
# Color support
# ============================================================================

setup_colors() {
    if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
        RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
        BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'
        DIM='\033[2m'; NC='\033[0m'
    else
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
    fi
}

info()    { echo -e "${BLUE}[info]${NC}    $*"; }
success() { echo -e "${GREEN}[ok]${NC}      $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}    $*"; }
fatal()   { echo -e "${RED}[error]${NC}   $*" >&2; exit 1; }
step()    { echo -e "\n${CYAN}${BOLD}==>${NC} ${BOLD}$*${NC}"; }

print_banner() {
    echo ""
    echo -e "${CYAN}${BOLD}"
    echo "   ____            _   _              _    ___ "
    echo "  / ___| ___ _ __ | |_| | ___        / \  |_ _|"
    echo " | |  _ / _ \ '_ \| __| |/ _ \_____ / _ \  | | "
    echo " | |_| |  __/ | | | |_| |  __/_____/ ___ \ | | "
    echo "  \____|\___|_| |_|\__|_|\___|    /_/   \_\___|"
    echo -e "${NC}"
    echo -e "  ${DIM}OPSX Edition — Fluid workflow powered by OpenSpec CLI${NC}"
    echo ""
}

# ============================================================================
# Prerequisites
# ============================================================================

check_prerequisites() {
    step "Checking prerequisites"

    local missing=()
    if ! command -v git &>/dev/null; then missing+=("git"); fi
    if ! command -v go &>/dev/null; then missing+=("go (https://go.dev/dl/)"); fi

    if [ ${#missing[@]} -gt 0 ]; then
        fatal "Missing required tools: ${missing[*]}"
    fi

    local go_version
    go_version="$(go version | grep -oP 'go\K[0-9]+\.[0-9]+')"
    local go_major go_minor
    go_major="$(echo "$go_version" | cut -d. -f1)"
    go_minor="$(echo "$go_version" | cut -d. -f2)"

    if [ "$go_major" -lt 1 ] || { [ "$go_major" -eq 1 ] && [ "$go_minor" -lt 24 ]; }; then
        fatal "Go 1.24+ required, found go${go_version}. Update from https://go.dev/dl/"
    fi

    success "git and Go ${go_version} available"
}

# ============================================================================
# Clone, build, install
# ============================================================================

install_from_source() {
    step "Cloning OPSX fork"

    local tmpdir
    tmpdir="$(mktemp -d)"
    trap '[ -n "${tmpdir:-}" ] && rm -rf "$tmpdir"' EXIT

    git clone --depth 1 "https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}.git" "$tmpdir/repo" 2>&1 | tail -1
    success "Cloned"

    step "Building ${BINARY_NAME}"

    cd "$tmpdir/repo"
    go build -o "${BINARY_NAME}" ./cmd/gentle-ai/
    success "Built"

    step "Installing binary"

    local install_dir
    if [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
        install_dir="/usr/local/bin"
    else
        install_dir="${HOME}/.local/bin"
        mkdir -p "$install_dir"
    fi

    if cp "${BINARY_NAME}" "${install_dir}/${BINARY_NAME}" 2>/dev/null; then
        chmod +x "${install_dir}/${BINARY_NAME}"
    elif command -v sudo &>/dev/null; then
        warn "Permission denied. Trying with sudo..."
        sudo cp "${BINARY_NAME}" "${install_dir}/${BINARY_NAME}"
        sudo chmod +x "${install_dir}/${BINARY_NAME}"
    else
        fatal "Cannot write to ${install_dir}."
    fi

    success "Installed to ${install_dir}/${BINARY_NAME}"

    if [[ ":$PATH:" != *":${install_dir}:"* ]]; then
        warn "${install_dir} is not in your PATH"
        echo -e "  ${DIM}export PATH=\"\$PATH:${install_dir}\"${NC}"
        export PATH="$PATH:${install_dir}"
    fi
}

# ============================================================================
# Clean previous config (so sync creates fresh OPSX)
# ============================================================================

clean_previous_config() {
    step "Cleaning previous config (so sync creates fresh OPSX)"

    local cleaned=false

    # OpenCode: remove opencode.json entirely (sync recreates it with OPSX)
    if [ -f "$HOME_DIR/.config/opencode/opencode.json" ]; then
        rm -f "$HOME_DIR/.config/opencode/opencode.json"
        cleaned=true
    fi

    # OpenCode: remove old sdd-* commands
    if ls "$HOME_DIR/.config/opencode/commands/sdd-"*.md &>/dev/null 2>&1; then
        rm -f "$HOME_DIR/.config/opencode/commands/sdd-"*.md
        cleaned=true
    fi

    # Claude Code: remove sdd-orchestrator section so sync injects fresh
    local claude_md="$HOME_DIR/.claude/CLAUDE.md"
    if [ -f "$claude_md" ] && grep -q "<!-- gentle-ai:sdd-orchestrator -->" "$claude_md"; then
        local tmpfile
        tmpfile="$(mktemp)"
        awk '
        /<!-- gentle-ai:sdd-orchestrator -->/ { skip=1; next }
        /<!-- \/gentle-ai:sdd-orchestrator -->/ { skip=0; next }
        skip==0 { print }
        ' "$claude_md" > "$tmpfile"
        cp "$tmpfile" "$claude_md"
        rm -f "$tmpfile"
        cleaned=true
    fi

    # Cursor: remove old sdd-* agent files
    if ls "$HOME_DIR/.cursor/agents/sdd-"*.md &>/dev/null 2>&1; then
        rm -f "$HOME_DIR/.cursor/agents/sdd-"*.md
        cleaned=true
    fi

    if [ "$cleaned" = true ]; then
        success "Previous config cleaned"
    else
        success "No previous config found — clean install"
    fi
}

# ============================================================================
# Sync (with self-update DISABLED)
# ============================================================================

run_sync() {
    step "Running ${BINARY_NAME} sync (self-update disabled)"

    # CRITICAL: Disable self-update so our OPSX binary doesn't get replaced
    # by the official release from Gentleman-Programming/gentle-ai
    export GENTLE_AI_NO_SELF_UPDATE=1

    if command -v "$BINARY_NAME" &>/dev/null; then
        "$BINARY_NAME" sync
        success "Sync complete — OPSX config created"
    else
        warn "Binary not in PATH. Run: GENTLE_AI_NO_SELF_UPDATE=1 ${BINARY_NAME} sync"
    fi
}

# ============================================================================
# Summary
# ============================================================================

print_summary() {
    echo ""
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo ""
    echo -e "${BOLD}Your agents are configured with OPSX.${NC}"
    echo ""
    echo -e "${BOLD}OPSX Commands:${NC}"
    echo -e "  ${CYAN}/opsx:explore${NC}  — Think through ideas before committing"
    echo -e "  ${CYAN}/opsx:propose${NC}  — Create a change with all artifacts"
    echo -e "  ${CYAN}/opsx:apply${NC}    — Implement tasks from the change"
    echo -e "  ${CYAN}/opsx:archive${NC}  — Sync specs and close the change"
    echo ""
    echo -e "${YELLOW}${BOLD}IMPORTANT:${NC} If you run 'gentle-ai sync' in the future, always use:"
    echo -e "  ${DIM}GENTLE_AI_NO_SELF_UPDATE=1 gentle-ai sync${NC}"
    echo -e "  ${DIM}Otherwise the official binary will overwrite OPSX.${NC}"
    echo ""
    echo -e "${DIM}Docs: https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}${NC}"
    echo ""
}

# ============================================================================
# Main
# ============================================================================

main() {
    setup_colors
    print_banner
    check_prerequisites
    install_from_source
    clean_previous_config
    run_sync
    print_summary
}

main "$@"
