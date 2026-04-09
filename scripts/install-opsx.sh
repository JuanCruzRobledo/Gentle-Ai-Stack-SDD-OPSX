#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# gentle-ai OPSX — Install Script
# One command to install the OPSX-enhanced Gentle AI Stack.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/JuanCruzRobledo/Gentle-Ai-Stack-SDD-OPSX/main/scripts/install-opsx.sh | bash
#
# Requires: Go 1.24+, git, curl
# ============================================================================

GITHUB_OWNER="JuanCruzRobledo"
GITHUB_REPO="Gentle-Ai-Stack-SDD-OPSX"
BINARY_NAME="gentle-ai"

# ============================================================================
# Color support
# ============================================================================

setup_colors() {
    if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[1;33m'
        BLUE='\033[0;34m'
        CYAN='\033[0;36m'
        BOLD='\033[1m'
        DIM='\033[2m'
        NC='\033[0m'
    else
        RED='' GREEN='' YELLOW='' BLUE='' CYAN='' BOLD='' DIM='' NC=''
    fi
}

info()    { echo -e "${BLUE}[info]${NC}    $*"; }
success() { echo -e "${GREEN}[ok]${NC}      $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}    $*"; }
error()   { echo -e "${RED}[error]${NC}   $*" >&2; }
fatal()   { error "$@"; exit 1; }
step()    { echo -e "\n${CYAN}${BOLD}==>${NC} ${BOLD}$*${NC}"; }

# ============================================================================
# Banner
# ============================================================================

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

    if ! command -v git &>/dev/null; then
        missing+=("git")
    fi

    if ! command -v go &>/dev/null; then
        missing+=("go (https://go.dev/dl/)")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        fatal "Missing required tools: ${missing[*]}. Please install them and try again."
    fi

    # Check Go version >= 1.24
    local go_version
    go_version="$(go version | grep -oP 'go\K[0-9]+\.[0-9]+')"
    local go_major go_minor
    go_major="$(echo "$go_version" | cut -d. -f1)"
    go_minor="$(echo "$go_version" | cut -d. -f2)"

    if [ "$go_major" -lt 1 ] || { [ "$go_major" -eq 1 ] && [ "$go_minor" -lt 24 ]; }; then
        fatal "Go 1.24+ required, found go${go_version}. Update from https://go.dev/dl/"
    fi

    success "git and Go ${go_version} are available"
}

# ============================================================================
# Clean legacy config
# ============================================================================

clean_legacy() {
    step "Cleaning legacy SDD config (if present)"

    local cleaned=false

    # OpenCode
    if ls ~/.config/opencode/commands/sdd-*.md &>/dev/null 2>&1; then
        rm -f ~/.config/opencode/commands/sdd-*.md
        cleaned=true
    fi
    if [ -f ~/.config/opencode/opencode.json ]; then
        rm -f ~/.config/opencode/opencode.json
        cleaned=true
    fi

    # Claude Code
    if ls ~/.claude/commands/sdd-*.md &>/dev/null 2>&1; then
        rm -f ~/.claude/commands/sdd-*.md
        cleaned=true
    fi

    # Cursor
    if ls ~/.cursor/agents/sdd-*.md &>/dev/null 2>&1; then
        rm -f ~/.cursor/agents/sdd-*.md
        cleaned=true
    fi

    # Gemini
    if ls ~/.gemini/commands/sdd-*.md &>/dev/null 2>&1; then
        rm -f ~/.gemini/commands/sdd-*.md
        cleaned=true
    fi

    if [ "$cleaned" = true ]; then
        success "Legacy SDD config removed"
    else
        success "No legacy config found — clean install"
    fi
}

# ============================================================================
# Clone, build, install
# ============================================================================

install_from_source() {
    step "Cloning repository"

    local tmpdir
    tmpdir="$(mktemp -d)"
    trap '[ -n "${tmpdir:-}" ] && rm -rf "$tmpdir"' EXIT

    git clone --depth 1 "https://github.com/${GITHUB_OWNER}/${GITHUB_REPO}.git" "$tmpdir/repo"
    success "Repository cloned"

    step "Building ${BINARY_NAME}"

    cd "$tmpdir/repo"
    go build -o "${BINARY_NAME}" ./cmd/gentle-ai/
    success "Build complete"

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
        fatal "Cannot write to ${install_dir}. Run with sudo or install Go and use 'go build' manually."
    fi

    success "Installed ${BINARY_NAME} to ${install_dir}/${BINARY_NAME}"

    if [[ ":$PATH:" != *":${install_dir}:"* ]]; then
        warn "${install_dir} is not in your PATH"
        echo -e "  ${DIM}Add to your shell profile: export PATH=\"\$PATH:${install_dir}\"${NC}"
        export PATH="$PATH:${install_dir}"
    fi
}

# ============================================================================
# Run sync
# ============================================================================

run_sync() {
    step "Running ${BINARY_NAME} sync"

    if command -v "$BINARY_NAME" &>/dev/null; then
        "$BINARY_NAME" sync
        success "Sync complete — OPSX workflow is active"
    else
        warn "Binary not in PATH. Run '${BINARY_NAME} sync' manually after adding it."
    fi
}

# ============================================================================
# Verify
# ============================================================================

verify_installation() {
    step "Verifying installation"

    hash -r 2>/dev/null || true

    if command -v "$BINARY_NAME" &>/dev/null; then
        local version_output
        version_output="$("$BINARY_NAME" version 2>&1 || true)"
        success "${BINARY_NAME} is installed: ${version_output}"
    else
        warn "Could not verify installation. Restart your shell and run: ${BINARY_NAME} version"
    fi
}

# ============================================================================
# Next steps
# ============================================================================

print_next_steps() {
    echo ""
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo ""
    echo -e "${BOLD}Your agents are now configured with OPSX.${NC}"
    echo ""
    echo -e "${BOLD}OPSX Commands:${NC}"
    echo -e "  ${CYAN}/opsx:explore${NC}  — Think through ideas before committing"
    echo -e "  ${CYAN}/opsx:propose${NC}  — Create a change with all artifacts"
    echo -e "  ${CYAN}/opsx:apply${NC}    — Implement tasks from the change"
    echo -e "  ${CYAN}/opsx:archive${NC}  — Sync specs and close the change"
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
    clean_legacy
    install_from_source
    run_sync
    verify_installation
    print_next_steps
}

main "$@"
