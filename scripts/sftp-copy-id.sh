#!/bin/bash
# sftp-copy-id.sh — 部署公钥到服务器
# 将本地公钥添加到远程服务器的 ~/.ssh/authorized_keys
# 支持密码交互式登录

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
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[copy-id]${NC} $*"
}
warn()  { echo -e "${YELLOW}[copy-id]${NC} $*"
}
error() { echo -e "${RED}[copy-id]${NC} $*" >&2
}
step()  { echo -e "${CYAN}[copy-id]${NC} $*"
}

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

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    error "配置文件不存在：$CONFIG_FILE"
    error "请先运行 sftp-init.sh 初始化配置"
    exit 1
fi

# 读取配置
HOST=$(json_get "$CONFIG_FILE" "host")
USERNAME=$(json_get "$CONFIG_FILE" "username")
PRIVATE_KEY=$(json_get "$CONFIG_FILE" "private_key")

# 验证必要配置
MISSING=()
[ -z "$HOST" ]     && MISSING+=("host")
[ -z "$USERNAME" ] && MISSING+=("username")

if [ ${#MISSING[@]} -gt 0 ]; then
    error "配置不完整，缺少：${MISSING[*]}"
    error "请编辑 $CONFIG_FILE 补充配置"
    exit 1
fi

# 确定公钥路径
PUB_KEY=""

# 1. 优先使用项目私钥对应的公钥
if [ -n "$PRIVATE_KEY" ] && [ -f "${PRIVATE_KEY}.pub" ]; then
    PUB_KEY="${PRIVATE_KEY}.pub"
    info "使用项目私钥对应的公钥：$PUB_KEY"
# 2. 尝试系统默认公钥
elif [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
    PUB_KEY="$HOME/.ssh/id_ed25519.pub"
    info "使用系统默认公钥 (id_ed25519.pub)：$PUB_KEY"
elif [ -f "$HOME/.ssh/id_rsa.pub" ]; then
    PUB_KEY="$HOME/.ssh/id_rsa.pub"
    info "使用系统默认公钥 (id_rsa.pub)：$PUB_KEY"
else
    error "未找到公钥文件"
    error "请生成密钥对：ssh-keygen -t ed25519"
    exit 1
fi

# 检查 ssh-copy-id 命令
if ! command -v ssh-copy-id &>/dev/null; then
    error "需要 ssh-copy-id 命令（OpenSSH 自带）"
    exit 1
fi

step "部署公钥到 $USERNAME@$HOST"
info "公钥文件：$PUB_KEY"
warn "根据提示输入服务器密码（密码不会显示）"
echo ""

# 执行 ssh-copy-id（它会自动提示密码）
ssh-copy-id -i "$PUB_KEY" "$USERNAME@$HOST"

info "完成！公钥已部署到服务器"
info ""
info "下一步："
info "  1. 如果私钥还未放入 .claude/sftp-cc/，请复制进去"
info "  2. 运行：bash ${SCRIPT_DIR}/sftp-keybind.sh 绑定私钥"
info "  3. 运行：bash ${SCRIPT_DIR}/sftp-push.sh 上传文件"
info ""
info "或者对 Claude 说：'绑定私钥' 和 '把代码同步到服务器'"
