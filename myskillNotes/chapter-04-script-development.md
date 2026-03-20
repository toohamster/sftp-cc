# 第 4 章：脚本开发实战

## 4.1 脚本结构模板

### 标准结构
```bash
#!/bin/bash
# 脚本名称：功能说明
# Usage: 使用说明

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# 日志函数
info()  { echo -e "${GREEN}[script]${NC} $*"; }
warn()  { echo -e "${YELLOW}[script]${NC} $*"; }
error() { echo -e "${RED}[script]${NC} $*" >&2; }

# 主逻辑
main() {
    info "Starting..."
    # ...
}

main "$@"
```

---

## 4.2 纯 Shell JSON 解析

### 为什么不用 jq
- 外部依赖，需要安装
- 不是所有系统都有
- Shell 可以搞定简单 JSON

### JSON 解析函数
```bash
# 读取字符串值
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

# 读取数字值
json_get_num() {
    local file="$1" key="$2" default="${3:-0}"
    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    echo "${val:-$default}"
}

# 读取数组
json_get_array() {
    local file="$1" key="$2"
    sed -n '/"'"$key"'"/,/\]/p' "$file" | grep '"' | grep -v "\"$key\"" | sed 's/.*"\([^"]*\)".*/\1/'
}
```

### 使用示例
```bash
CONFIG_FILE=".claude/sftp-cc/sftp-config.json"

HOST=$(json_get "$CONFIG_FILE" "host")
PORT=$(json_get_num "$CONFIG_FILE" "port" "22")
USERNAME=$(json_get "$CONFIG_FILE" "username")

# 读取数组
while IFS= read -r line; do
    [ -n "$line" ] && EXCLUDES+=("$line")
done < <(json_get_array "$CONFIG_FILE" "excludes")
```

---

## 4.3 错误处理

### 参数验证
```bash
MISSING=()
[ -z "$HOST" ]        && MISSING+=("host")
[ -z "$USERNAME" ]    && MISSING+=("username")
[ -z "$REMOTE_PATH" ] && MISSING+=("remote_path")

if [ ${#MISSING[@]} -gt 0 ]; then
    error "配置不完整，缺少字段：${MISSING[*]}"
    error "请编辑配置文件：$CONFIG_FILE"
    exit 1
fi
```

### 命令执行检查
```bash
if ! command -v sftp &>/dev/null; then
    error "未找到 sftp 命令，请先安装"
    exit 1
fi
```

### 文件存在检查
```bash
if [ ! -f "$CONFIG_FILE" ]; then
    error "配置文件不存在：$CONFIG_FILE"
    error "请先运行 sftp-init.sh 初始化配置"
    exit 1
fi

if [ ! -f "$PRIVATE_KEY" ]; then
    error "私钥文件不存在：$PRIVATE_KEY"
    exit 1
fi
```

---

## 4.4 实战：sftp-keybind.sh

### 完整代码
```bash
#!/bin/bash
# sftp-keybind.sh — 私钥自动绑定 + 权限修正
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SFTP_CC_DIR="$PROJECT_ROOT/.claude/sftp-cc"
CONFIG_FILE="$SFTP_CC_DIR/sftp-config.json"

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[keybind]${NC} $*"; }
warn()  { echo -e "${YELLOW}[keybind]${NC} $*"; }
error() { echo -e "${RED}[keybind]${NC} $*" >&2; }

# JSON 解析
json_get() {
    local file="$1" key="$2" default="${3:-}"
    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    echo "${val:-$default}"
}

json_set() {
    local file="$1" key="$2" value="$3"
    local tmp
    tmp=$(mktemp)
    sed "s|\"$key\": *\"[^\"]*\"|\"$key\": \"$value\"|" "$file" > "$tmp"
    mv "$tmp" "$file"
}

# 检查配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    error "配置文件不存在：$CONFIG_FILE"
    exit 1
fi

# 读取现有 private_key
CURRENT_KEY=$(json_get "$CONFIG_FILE" "private_key")

# 如果已配置且文件存在，只修正权限
if [ -n "$CURRENT_KEY" ] && [ -f "$CURRENT_KEY" ]; then
    PERMS=$(stat -f "%Lp" "$CURRENT_KEY" 2>/dev/null || stat -c "%a" "$CURRENT_KEY" 2>/dev/null)
    if [ "$PERMS" != "600" ]; then
        chmod 600 "$CURRENT_KEY"
        info "已修正私钥权限：$CURRENT_KEY -> 600"
    else
        info "私钥已绑定且权限正确：$CURRENT_KEY"
    fi
    exit 0
fi

# 扫描私钥文件
KEY_PATTERNS=("id_rsa" "id_ed25519" "id_ecdsa" "id_dsa" "*.pem" "*.key")
FOUND_KEY=""

for pattern in "${KEY_PATTERNS[@]}"; do
    while IFS= read -r -d '' keyfile; do
        [[ "$keyfile" == *.pub ]] && continue
        [[ "$(basename "$keyfile")" == "sftp-config"* ]] && continue
        [[ "$(basename "$keyfile")" == *"example"* ]] && continue
        FOUND_KEY="$keyfile"
        break
    done < <(find "$SFTP_CC_DIR" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
    [ -n "$FOUND_KEY" ] && break
done

if [ -z "$FOUND_KEY" ]; then
    warn "未在 $SFTP_CC_DIR 下找到私钥文件"
    warn "支持的文件：${KEY_PATTERNS[*]}"
    warn "请将私钥文件放入 $SFTP_CC_DIR/"
    exit 1
fi

# 修正权限并写入配置
chmod 600 "$FOUND_KEY"
info "已修正私钥权限：$FOUND_KEY -> 600"

json_set "$CONFIG_FILE" "private_key" "$FOUND_KEY"
info "已绑定私钥：$FOUND_KEY"
info "配置已更新：$CONFIG_FILE"
```

### 执行流程
1. 定位 `.claude/sftp-cc/` 目录
2. 检查 `sftp-config.json` 是否存在
3. 如果已配置私钥 → 只修正权限
4. 否则扫描目录查找私钥
5. 找到私钥 → 修正权限 → 写入配置

---

## 4.5 实战：sftp-push.sh（节选）

### 增量检测逻辑
```bash
collect_changed_files() {
    local last_hash_file=".claude/sftp-cc/.last-push"

    # 首次上传，全量
    if [ ! -f "$last_hash_file" ]; then
        return 0
    fi

    local last_hash
    last_hash=$(head -1 "$last_hash_file")

    local changed_list deleted_list
    changed_list=$(mktemp)
    deleted_list=$(mktemp)

    # 已提交的变更
    if [ -n "$last_hash" ]; then
        git -C "$PROJECT_ROOT" diff --name-only --diff-filter=ACMR "$last_hash" HEAD \
            >> "$changed_list" 2>/dev/null || true
    fi

    # 暂存区变更
    git -C "$PROJECT_ROOT" diff --cached --name-only --diff-filter=ACMR \
        >> "$changed_list" 2>/dev/null || true

    # 工作区修改
    git -C "$PROJECT_ROOT" diff --name-only --diff-filter=ACMR \
        >> "$changed_list" 2>/dev/null || true

    # 未跟踪文件
    git -C "$PROJECT_ROOT" ls-files --others --exclude-standard \
        >> "$changed_list" 2>/dev/null || true

    # 去重
    sort -u "$changed_list" -o "$changed_list"

    cat "$changed_list"
    rm -f "$changed_list" "$deleted_list"
}
```

---

## 4.6 定位项目根目录

### 使用 git
```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

### 为什么这样做
- 支持在子目录执行脚本
- 兼容非 git 项目（回退到 pwd）
- 统一路径基准

---

## 4.7 调试技巧

### 启用详细输出
```bash
set -x  # 打印执行的每一行
set -v  # 打印读取的每一行
```

### 临时文件清理
```bash
# 使用 mktemp 创建临时文件
tmp_file=$(mktemp)

# 使用 trap 确保退出时清理
trap 'rm -f "$tmp_file"' EXIT

# 使用后立即删除
process_file "$tmp_file"
rm -f "$tmp_file"
```

### 日志级别
```bash
VERBOSE=false
if [[ "${1:-}" == "-v" ]] || [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

debug() {
    $VERBOSE && echo -e "[DEBUG] $*" >&2
}
```

---

## 本章小结

- 掌握纯 Shell JSON 解析
- 完善的错误处理
- 使用 git 定位项目根目录
- 临时文件及时清理

## 下一章

第 5 章将介绍多语言支持（i18n）的实现。
