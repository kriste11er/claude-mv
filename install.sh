#!/usr/bin/env bash
#
# claude-mv installer
#
# Downloads the latest claude-mv from GitHub, places it at ~/.local/bin/claude-mv,
# makes it executable, and reports whether ~/.local/bin is in your PATH.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/kriste11er/claude-mv/main/install.sh | bash
#
# Or, to inspect first (recommended):
#   curl -fsSL -o install.sh https://raw.githubusercontent.com/kriste11er/claude-mv/main/install.sh
#   less install.sh
#   bash install.sh

set -euo pipefail

# Configuration — update REPO when you publish
REPO="${CLAUDE_MV_REPO:-kriste11er/claude-mv}"
BRANCH="${CLAUDE_MV_BRANCH:-main}"
INSTALL_DIR="${CLAUDE_MV_INSTALL_DIR:-$HOME/.local/bin}"
SCRIPT_NAME="claude-mv"
SCRIPT_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${SCRIPT_NAME}"

# Color output (only if stdout is a terminal)
if [ -t 1 ]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    BLUE=$'\033[0;34m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
else
    RED="" GREEN="" YELLOW="" BLUE="" BOLD="" RESET=""
fi

info()  { echo "${BLUE}==>${RESET} $*"; }
ok()    { echo "${GREEN}✓${RESET} $*"; }
warn()  { echo "${YELLOW}!${RESET} $*"; }
fail()  { echo "${RED}✗${RESET} $*" >&2; exit 1; }

# Check dependencies
command -v curl >/dev/null 2>&1 || fail "curl is required but not installed"
command -v bash >/dev/null 2>&1 || fail "bash is required but not installed"

# Create install dir if needed
if [ ! -d "$INSTALL_DIR" ]; then
    info "Creating $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
fi

DEST="$INSTALL_DIR/$SCRIPT_NAME"

# Warn if a file already exists at the destination
if [ -e "$DEST" ]; then
    warn "$DEST already exists — backing up to ${DEST}.bak"
    mv "$DEST" "${DEST}.bak"
fi

# Download
info "Downloading $SCRIPT_NAME from $SCRIPT_URL"
if ! curl -fsSL -o "$DEST" "$SCRIPT_URL"; then
    fail "Download failed — check the URL and your network connection"
fi

# Make executable
chmod +x "$DEST"
ok "Installed: $DEST"

# Verify the script runs
if "$DEST" --help >/dev/null 2>&1; then
    ok "Script runs successfully"
else
    fail "Script downloaded but failed to run — file may be corrupt"
fi

# Check PATH
echo ""
if echo "$PATH" | tr ':' '\n' | grep -qFx "$INSTALL_DIR"; then
    ok "$INSTALL_DIR is in your PATH"
    echo ""
    echo "${BOLD}You can now run:${RESET} ${GREEN}claude-mv --help${RESET}"
else
    warn "$INSTALL_DIR is NOT in your PATH"
    echo ""
    echo "Add this line to your shell config (~/.bashrc, ~/.zshrc, or ~/.bash_profile):"
    echo ""
    echo "  ${BOLD}export PATH=\"$INSTALL_DIR:\$PATH\"${RESET}"
    echo ""
    echo "Then either restart your shell or run:"
    echo ""
    echo "  ${BOLD}source ~/.bashrc${RESET}   # or ~/.zshrc, ~/.bash_profile"
    echo ""
    echo "Or run claude-mv directly with the full path:"
    echo ""
    echo "  ${BOLD}$DEST --help${RESET}"
fi
echo ""
ok "Done. See https://github.com/${REPO} for usage."
