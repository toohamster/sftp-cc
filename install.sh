#!/bin/bash
# install.sh — 将 sftp-cc-toomaster skill 安装到目标项目
# Usage: bash install.sh [TARGET_PROJECT_PATH]

set -euo pipefail

# 颜色输出
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

# 安装源目录（本仓库）
SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"

# 目标项目路径（参数或当前目录）
TARGET="${1:-.}"
TARGET="$(cd "$TARGET" && pwd)"

SKILL_DIR="$TARGET/.claude/skills/sftp-cc-toomaster"
SFTP_CC_DIR="$TARGET/.claude/sftp-cc"

echo -e "${BOLD}========================================${NC}"
echo -e "${BOLD}  sftp-cc-toomaster 安装程序${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
info "源目录:   $SOURCE_DIR"
info "目标项目: $TARGET"
echo ""

# 检查源文件
if [ ! -f "$SOURCE_DIR/skill.md" ]; then
    error "找不到 skill.md，请在 sftp-cc-toomaster 仓库根目录运行此脚本"
    exit 1
fi

if [ ! -d "$SOURCE_DIR/scripts" ]; then
    error "找不到 scripts/ 目录"
    exit 1
fi

# ====== 1. 创建目录 ======
step "创建目录结构..."
mkdir -p "$SKILL_DIR/scripts"
mkdir -p "$SFTP_CC_DIR"
info "  $SKILL_DIR/"
info "  $SFTP_CC_DIR/"

# ====== 2. 复制 skill.md ======
step "安装 skill.md..."
cp "$SOURCE_DIR/skill.md" "$SKILL_DIR/skill.md"
info "  -> $SKILL_DIR/skill.md"

# ====== 3. 复制脚本 ======
step "安装脚本..."
cp "$SOURCE_DIR/scripts/"*.sh "$SKILL_DIR/scripts/"
chmod +x "$SKILL_DIR/scripts/"*.sh
for f in "$SKILL_DIR/scripts/"*.sh; do
    info "  -> $f"
done

# ====== 4. 复制配置模板 ======
step "安装配置..."
if [ -f "$SFTP_CC_DIR/sftp-config.json" ]; then
    warn "sftp-config.json 已存在，跳过覆盖"
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
    info "  -> $SFTP_CC_DIR/sftp-config.json"
fi

# ====== 5. 更新 .gitignore ======
step "检查 .gitignore..."
GITIGNORE="$TARGET/.gitignore"
ENTRIES_TO_ADD=()

# 需要忽略的条目
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
        info "  添加到 .gitignore: $entry"
    done
else
    info "  .gitignore 已包含必要条目"
fi

# ====== 完成 ======
echo ""
echo -e "${BOLD}========================================${NC}"
echo -e "${GREEN}${BOLD}  安装完成！${NC}"
echo -e "${BOLD}========================================${NC}"
echo ""
echo "安装的文件:"
echo "  $SKILL_DIR/skill.md"
echo "  $SKILL_DIR/scripts/sftp-init.sh"
echo "  $SKILL_DIR/scripts/sftp-keybind.sh"
echo "  $SKILL_DIR/scripts/sftp-push.sh"
echo "  $SFTP_CC_DIR/sftp-config.json"
echo ""
echo -e "${YELLOW}下一步:${NC}"
echo "  1. 编辑 $SFTP_CC_DIR/sftp-config.json 填写服务器信息"
echo "  2. 将 SSH 私钥文件放入 $SFTP_CC_DIR/"
echo "  3. 在 Claude Code 中说: \"把代码同步到服务器\""
echo ""
echo -e "${CYAN}快速配置:${NC}"
echo "  bash $SKILL_DIR/scripts/sftp-init.sh \\"
echo "    --host your-server.com \\"
echo "    --username deploy \\"
echo "    --remote-path /var/www/html"
