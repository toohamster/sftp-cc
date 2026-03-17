#!/bin/bash
# sftp-init.sh — 初始化 SFTP 配置
# 创建 .claude/sftp-cc/ 目录并生成 sftp-config.json
# 零外部依赖，纯 shell 实现

set -euo pipefail

# 定位项目根目录
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SFTP_CC_DIR="$PROJECT_ROOT/.claude/sftp-cc"
CONFIG_FILE="$SFTP_CC_DIR/sftp-config.json"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[init]${NC} $*"; }
warn()  { echo -e "${YELLOW}[init]${NC} $*"; }
error() { echo -e "${RED}[init]${NC} $*" >&2; }

# ====== 纯 shell JSON 工具函数 ======
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

json_set_num() {
    local file="$1" key="$2" value="$3"
    local tmp
    tmp=$(mktemp)
    sed "s|\"$key\": *[0-9][0-9]*|\"$key\": $value|" "$file" > "$tmp"
    mv "$tmp" "$file"
}

# 解析参数
HOST=""
PORT="22"
USERNAME=""
REMOTE_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --host)      HOST="$2";        shift 2 ;;
        --port)      PORT="$2";        shift 2 ;;
        --username)  USERNAME="$2";    shift 2 ;;
        --remote-path) REMOTE_PATH="$2"; shift 2 ;;
        --help|-h)
            echo "Usage: sftp-init.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --host HOST           SFTP 服务器地址"
            echo "  --port PORT           SFTP 端口 (默认 22)"
            echo "  --username USER       登录用户名"
            echo "  --remote-path PATH    远程目标路径"
            echo "  -h, --help            显示帮助"
            exit 0
            ;;
        *) error "未知参数: $1"; exit 1 ;;
    esac
done

# 创建目录
mkdir -p "$SFTP_CC_DIR"
info "已创建配置目录: $SFTP_CC_DIR"

# 创建配置文件
if [ -f "$CONFIG_FILE" ]; then
    warn "配置文件已存在: $CONFIG_FILE"
else
    # 尝试从模板复制
    TEMPLATE=""
    POSSIBLE_TEMPLATES=(
        "$SCRIPT_DIR/../templates/sftp-config.example.json"
        "$PROJECT_ROOT/.claude/skills/sftp-cc-toomaster/templates/sftp-config.example.json"
    )
    for t in "${POSSIBLE_TEMPLATES[@]}"; do
        if [ -f "$t" ]; then
            TEMPLATE="$t"
            break
        fi
    done

    if [ -n "$TEMPLATE" ]; then
        cp "$TEMPLATE" "$CONFIG_FILE"
    else
        # 内联创建默认配置
        cat > "$CONFIG_FILE" <<'JSONEOF'
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
    info "已创建配置文件: $CONFIG_FILE"
fi

# 填入用户提供的参数
[ -n "$HOST" ]        && json_set "$CONFIG_FILE" "host" "$HOST"
[ -n "$USERNAME" ]    && json_set "$CONFIG_FILE" "username" "$USERNAME"
[ -n "$REMOTE_PATH" ] && json_set "$CONFIG_FILE" "remote_path" "$REMOTE_PATH"
[ "$PORT" != "22" ]   && json_set_num "$CONFIG_FILE" "port" "$PORT"

if [ -n "$HOST" ] || [ -n "$USERNAME" ] || [ -n "$REMOTE_PATH" ]; then
    info "已更新配置字段"
fi

# 自动绑定私钥
KEYBIND_SCRIPT="$SCRIPT_DIR/sftp-keybind.sh"
if [ -f "$KEYBIND_SCRIPT" ]; then
    bash "$KEYBIND_SCRIPT" || true
fi

# 检查配置完整性
MISSING_FIELDS=()
[ -z "$(json_get "$CONFIG_FILE" "host")" ]        && MISSING_FIELDS+=("host")
[ -z "$(json_get "$CONFIG_FILE" "username")" ]     && MISSING_FIELDS+=("username")
[ -z "$(json_get "$CONFIG_FILE" "remote_path")" ]  && MISSING_FIELDS+=("remote_path")

if [ ${#MISSING_FIELDS[@]} -gt 0 ]; then
    warn "以下字段尚未配置: ${MISSING_FIELDS[*]}"
    warn "请编辑 $CONFIG_FILE 补充配置"
fi

info "初始化完成！"
echo ""
echo "下一步："
echo "  1. 编辑 $CONFIG_FILE 填写服务器信息"
echo "  2. 将私钥文件放入 $SFTP_CC_DIR/"
echo "  3. 告诉 Claude: \"把代码上传到服务器\""
