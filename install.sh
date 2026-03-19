#!/bin/bash
# install.sh — Install sftp-cc-toomaster skill to target project
# Usage: bash install.sh [TARGET_PROJECT_PATH] [OPTIONS]
#
# Options:
#   --language LANG    Set language (en|zh|ja), default: en
#   --help, -h         Show this help

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

info()  { echo -e "${GREEN}[install]${NC} $*"; }
warn()  { echo -e "${YELLOW}[install]${NC} $*"; }
error() { echo -e "${RED}[install]${NC} $*" >&2; }
step()  { echo -e "${CYAN}[install]${NC} $*"; }

# Source directory (this repository)
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

# Default language
LANGUAGE="en"

# Parse arguments
TARGET=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --language)
            LANGUAGE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: bash install.sh [TARGET_PROJECT_PATH] [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --language LANG    Set language (en|zh|ja), default: en"
            echo "  --help, -h         Show this help"
            exit 0
            ;;
        -*)
            error "Unknown option: $1"
            exit 1
            ;;
        *)
            if [ -z "$TARGET" ]; then
                TARGET="$1"
            fi
            shift
            ;;
    esac
done

# Target project path (argument or current directory)
TARGET="${TARGET:-.}"
TARGET="$(cd "$TARGET" && pwd)"

SKILL_DIR="$TARGET/.claude/skills/sftp-cc-toomaster"
SFTP_CC_DIR="$TARGET/.claude/sftp-cc"

# Language-specific installer header
if [ "$LANGUAGE" = "zh" ]; then
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}  sftp-cc-toomaster 安装程序${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""
    info "源目录：  $SOURCE_DIR"
    info "目标项目：$TARGET"
elif [ "$LANGUAGE" = "ja" ]; then
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}  sftp-cc-toomaster インストーラー${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""
    info "ソース：  $SOURCE_DIR"
    info "ターゲット：$TARGET"
else
    echo -e "${BOLD}========================================${NC}"
    echo -e "${BOLD}  sftp-cc-toomaster Installer${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo ""
    info "Source:   $SOURCE_DIR"
    info "Target:   $TARGET"
fi
echo ""

# Check source files
if [ ! -f "$SOURCE_DIR/skill.md" ]; then
    error "skill.md not found, please run this script from sftp-cc-toomaster repository root"
    exit 1
fi

if [ ! -d "$SOURCE_DIR/scripts" ]; then
    error "scripts/ directory not found"
    exit 1
fi

# ====== 1. Create directories ======
step "Creating directory structure..."
mkdir -p "$SKILL_DIR/scripts"
mkdir -p "$SFTP_CC_DIR"
info "  $SKILL_DIR/"
info "  $SFTP_CC_DIR/"

# ====== 2. Copy skill.md ======
step "Installing skill.md..."
cp "$SOURCE_DIR/skill.md" "$SKILL_DIR/skill.md"
info "  -> $SKILL_DIR/skill.md"

# ====== 3. Copy scripts ======
step "Installing scripts..."
cp "$SOURCE_DIR/scripts/"*.sh "$SKILL_DIR/scripts/"
chmod +x "$SKILL_DIR/scripts/"*.sh
for f in "$SKILL_DIR/scripts/"*.sh; do
    info "  -> $f"
done

# ====== 4. Copy config template ======
step "Installing configuration..."
if [ -f "$SFTP_CC_DIR/sftp-config.json" ]; then
    warn "sftp-config.json already exists, skipping overwrite"
else
    if [ -f "$SOURCE_DIR/templates/sftp-config.example.json" ]; then
        cp "$SOURCE_DIR/templates/sftp-config.example.json" "$SFTP_CC_DIR/sftp-config.json"
    else
        cat > "$SFTP_CC_DIR/sftp-config.json" <<'JSONEOF'
{
  "host": "",
  "port": 22,
  "username": "",
  "remote_path": "",
  "local_path": ".",
  "private_key": "",
  "language": "en",
  "excludes": [
    ".git",
    ".claude",
    "node_modules",
    ".env",
    ".DS_Store"
  ]
}
JSONEOF
    fi

    # Set language in config
    json_set() {
        local file="$1" key="$2" value="$3"
        local tmp
        tmp=$(mktemp)
        sed "s|\"$key\": *\"[^\"]*\"|\"$key\": \"$value\"|" "$file" > "$tmp"
        mv "$tmp" "$file"
    }

    json_set "$SFTP_CC_DIR/sftp-config.json" "language" "$LANGUAGE"
    info "  -> $SFTP_CC_DIR/sftp-config.json (language: $LANGUAGE)"
fi

# ====== 5. Update .gitignore ======
step "Checking .gitignore..."
GITIGNORE="$TARGET/.gitignore"
ENTRIES_TO_ADD=()

# Entries to ignore
IGNORE_ENTRIES=(
    ".claude/sftp-cc/"
)

if [ -f "$GITIGNORE" ]; then
    for entry in "${IGNORE_ENTRIES[@]}"; do
        if ! grep -qF "$entry" "$GITIGNORE"; then
            ENTRIES_TO_ADD+=("$entry")
        fi
    done
else
    ENTRIES_TO_ADD=("${IGNORE_ENTRIES[@]}")
fi

if [ ${#ENTRIES_TO_ADD[@]} -gt 0 ]; then
    echo "" >> "$GITIGNORE"
    echo "# sftp-cc-toomaster (SFTP config & keys)" >> "$GITIGNORE"
    for entry in "${ENTRIES_TO_ADD[@]}"; do
        echo "$entry" >> "$GITIGNORE"
        info "  Added to .gitignore: $entry"
    done
else
    info "  .gitignore already contains required entries"
fi

# ====== Complete ======
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${GREEN}${BOLD}  Installation complete!${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo "Installed files:"
echo "  $SKILL_DIR/skill.md"
echo "  $SKILL_DIR/scripts/sftp-init.sh"
echo "  $SKILL_DIR/scripts/sftp-keybind.sh"
echo "  $SKILL_DIR/scripts/sftp-copy-id.sh"
echo "  $SKILL_DIR/scripts/sftp-push.sh"
echo "  $SFTP_CC_DIR/sftp-config.json"
echo ""

# Language-specific next steps
if [ "$LANGUAGE" = "zh" ]; then
    echo -e "${YELLOW}下一步:${NC}"
    echo "  1. 编辑 $SFTP_CC_DIR/sftp-config.json 填写服务器信息"
    echo "  2. 运行：bash $SKILL_DIR/scripts/sftp-copy-id.sh 部署公钥到服务器"
    echo "  3. 将 SSH 私钥文件放入 $SFTP_CC_DIR/"
    echo "  4. 在 Claude Code 中说：\"把代码同步到服务器\""
    echo ""
    echo -e "${CYAN}快速配置:${NC}"
    echo "  bash $SKILL_DIR/scripts/sftp-init.sh \\"
    echo "    --host your-server.com \\"
    echo "    --username deploy \\"
    echo "    --remote-path /var/www/html"
elif [ "$LANGUAGE" = "ja" ]; then
    echo -e "${YELLOW}次のステップ:${NC}"
    echo "  1. $SFTP_CC_DIR/sftp-config.json を編集してサーバー情報を入力"
    echo "  2. 実行：bash $SKILL_DIR/scripts/sftp-copy-id.sh 公開鍵をサーバーにデプロイ"
    echo "  3. SSH 秘密鍵ファイルを $SFTP_CC_DIR/ に配置"
    echo "  4. Claude Code に伝える：\"sync code to server\""
    echo ""
    echo -e "${CYAN}クイック設定:${NC}"
    echo "  bash $SKILL_DIR/scripts/sftp-init.sh \\"
    echo "    --host your-server.com \\"
    echo "    --username deploy \\"
    echo "    --remote-path /var/www/html"
else
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Edit $SFTP_CC_DIR/sftp-config.json to fill in server information"
    echo "  2. Run: bash $SKILL_DIR/scripts/sftp-copy-id.sh to deploy public key to server"
    echo "  3. Place SSH private key file in $SFTP_CC_DIR/"
    echo "  4. Tell Claude Code: \"sync code to server\""
    echo ""
    echo -e "${CYAN}Quick configuration:${NC}"
    echo "  bash $SKILL_DIR/scripts/sftp-init.sh \\"
    echo "    --host your-server.com \\"
    echo "    --username deploy \\"
    echo "    --remote-path /var/www/html"
fi
