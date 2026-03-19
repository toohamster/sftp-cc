#!/bin/bash
# sftp-keybind.sh — Auto-bind private key + fix permissions
# Scan .claude/sftp-cc/ for private key files, auto-bind to sftp-config.json and fix permissions
# Zero external dependencies, pure shell

set -euo pipefail

# Locate project root directory
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SFTP_CC_DIR="$PROJECT_ROOT/.claude/sftp-cc"
CONFIG_FILE="$SFTP_CC_DIR/sftp-config.json"

# Initialize language from config
source "$(cd "$(dirname "$0")" && pwd)/i18n.sh"
init_lang "$CONFIG_FILE"

# Private key file patterns
KEY_PATTERNS=("id_rsa" "id_ed25519" "id_ecdsa" "id_dsa" "*.pem" "*.key")

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[keybind]${NC} $*"; }
warn()  { echo -e "${YELLOW}[keybind]${NC} $*"; }
error() { echo -e "${RED}[keybind]${NC} $*" >&2; }

# Pure shell JSON tools
json_get() {
    local file="$1" key="$2" default="${3:-}"
    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "$default"
    else
        echo "$val"
    fi
}

json_set() {
    local file="$1" key="$2" value="$3"
    local tmp
    tmp=$(mktemp)
    sed "s|\"$key\": *\"[^\"]*\"|\"$key\": \"$value\"|" "$file" > "$tmp"
    mv "$tmp" "$file"
}

# Check config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    error "$(printf "$MSG_CONFIG_MISSING" "$CONFIG_FILE")"
    error "$MSG_RUN_INIT_FIRST"
    exit 1
fi

# Read current private key path
CURRENT_KEY=$(json_get "$CONFIG_FILE" "private_key")

# If already configured and file exists, just fix permissions
if [ -n "$CURRENT_KEY" ] && [ -f "$CURRENT_KEY" ]; then
    PERMS=$(stat -f "%Lp" "$CURRENT_KEY" 2>/dev/null || stat -c "%a" "$CURRENT_KEY" 2>/dev/null)
    if [ "$PERMS" != "600" ]; then
        chmod 600 "$CURRENT_KEY"
        info "$(printf "$MSG_KEY_PERMISSIONS_FIXED" "$CURRENT_KEY")"
    else
        info "$(printf "$MSG_KEYBIND_COMPLETE" "$CURRENT_KEY")"
    fi
    exit 0
fi

# Scan for private key files
FOUND_KEY=""
for pattern in "${KEY_PATTERNS[@]}"; do
    while IFS= read -r -d '' keyfile; do
        # Skip .pub public key files
        [[ "$keyfile" == *.pub ]] && continue
        # Skip config files and example files
        [[ "$(basename "$keyfile")" == "sftp-config"* ]] && continue
        [[ "$(basename "$keyfile")" == *"example"* ]] && continue

        FOUND_KEY="$keyfile"
        break
    done < <(find "$SFTP_CC_DIR" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
    [ -n "$FOUND_KEY" ] && break
done

if [ -z "$FOUND_KEY" ]; then
    warn "$(printf "$MSG_NO_KEY_FOUND" "$SFTP_CC_DIR")"
    warn "$(printf "$MSG_SUPPORTED_KEYS" "${KEY_PATTERNS[*]}")"
    warn "$(printf "$MSG_PLACE_KEY_IN_DIR" "$SFTP_CC_DIR/")"
    exit 1
fi

# Fix permissions
chmod 600 "$FOUND_KEY"
info "$(printf "$MSG_KEY_PERMISSIONS_FIXED" "$FOUND_KEY")"

# Write to config
json_set "$CONFIG_FILE" "private_key" "$FOUND_KEY"

info "$(printf "$MSG_KEY_BOUND" "$FOUND_KEY")"
info "$(printf "$MSG_CONFIG_UPDATED" "$CONFIG_FILE")"
