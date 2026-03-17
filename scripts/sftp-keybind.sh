#!/bin/bash
# sftp-keybind.sh — 私钥自动绑定 + 权限修正
# 扫描 .claude/sftp-cc/ 下的私钥文件，自动绑定到 sftp-config.json 并修正权限
# 零外部依赖，纯 shell 实现

set -euo pipefail

# 定位项目根目录
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SFTP_CC_DIR="$PROJECT_ROOT/.claude/sftp-cc"
CONFIG_FILE="$SFTP_CC_DIR/sftp-config.json"

# 私钥文件匹配模式
KEY_PATTERNS=("id_rsa" "id_ed25519" "id_ecdsa" "id_dsa" "*.pem" "*.key")

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[keybind]${NC} $*"; }
warn()  { echo -e "${YELLOW}[keybind]${NC} $*"; }
error() { echo -e "${RED}[keybind]${NC} $*" >&2; }

# ====== 纯 shell JSON 工具函数 ======
# 读取 JSON 字符串值（适用于简单扁平 JSON）
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

# 设置 JSON 字符串值（通过临时文件，兼容 macOS/Linux）
json_set() {
    local file="$1" key="$2" value="$3"
    local tmp
    tmp=$(mktemp)
    sed "s|\"$key\": *\"[^\"]*\"|\"$key\": \"$value\"|" "$file" > "$tmp"
    mv "$tmp" "$file"
}

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    error "配置文件不存在: $CONFIG_FILE"
    error "请先运行 sftp-init.sh 初始化配置"
    exit 1
fi

# 读取当前配置的私钥路径
CURRENT_KEY=$(json_get "$CONFIG_FILE" "private_key")

# 如果已配置且文件存在，仅修正权限
if [ -n "$CURRENT_KEY" ] && [ -f "$CURRENT_KEY" ]; then
    PERMS=$(stat -f "%Lp" "$CURRENT_KEY" 2>/dev/null || stat -c "%a" "$CURRENT_KEY" 2>/dev/null)
    if [ "$PERMS" != "600" ]; then
        chmod 600 "$CURRENT_KEY"
        info "已修正私钥权限: $CURRENT_KEY (${PERMS} -> 600)"
    else
        info "私钥已绑定且权限正确: $CURRENT_KEY"
    fi
    exit 0
fi

# 扫描私钥文件
FOUND_KEY=""
for pattern in "${KEY_PATTERNS[@]}"; do
    while IFS= read -r -d '' keyfile; do
        # 跳过 .pub 公钥文件
        [[ "$keyfile" == *.pub ]] && continue
        # 跳过配置文件和 example 文件
        [[ "$(basename "$keyfile")" == "sftp-config"* ]] && continue
        [[ "$(basename "$keyfile")" == *"example"* ]] && continue

        FOUND_KEY="$keyfile"
        break
    done < <(find "$SFTP_CC_DIR" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
    [ -n "$FOUND_KEY" ] && break
done

if [ -z "$FOUND_KEY" ]; then
    warn "未在 $SFTP_CC_DIR 下找到私钥文件"
    warn "支持的文件: ${KEY_PATTERNS[*]}"
    warn "请将私钥文件放入 $SFTP_CC_DIR/ 目录"
    exit 1
fi

# 修正权限
chmod 600 "$FOUND_KEY"
info "已修正私钥权限: $FOUND_KEY -> 600"

# 写入配置
json_set "$CONFIG_FILE" "private_key" "$FOUND_KEY"

info "已自动绑定私钥: $FOUND_KEY"
info "配置已更新: $CONFIG_FILE"
