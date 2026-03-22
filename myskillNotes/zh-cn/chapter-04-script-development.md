# 第 4 章：脚本开发实战

> "Shell 脚本是 Unix 世界的胶水语言。" — 经典编程格言

本章你将学到：
- 生产级 Shell 脚本的完整结构
- 纯 Shell JSON 解析的实现原理
- 完善的错误处理模式
- 临时文件管理和清理
- 项目根目录定位技巧
- 实战：sftp-keybind.sh 逐行解析
- 调试技巧和最佳实践

---

## 4.1 脚本结构模板

### 4.1.1 标准脚本结构

一个生产级的 Shell 脚本应该包含以下部分：

```bash
#!/bin/bash
# ============================================================================
# 脚本头注释
# ============================================================================
# 脚本名称：sftp-push.sh
# 功能说明：SFTP 上传脚本，支持增量上传和全量上传
# 作者：your-name
# 版本：2.0.0
# 创建日期：2024-01-01
# 最后更新：2024-01-15
#
# Usage:
#   ./sftp-push.sh [OPTIONS] [FILES...]
#
# Options:
#   -f, --full      全量上传所有文件
#   -n, --dry-run   预览模式，不实际上传
#   -v, --verbose   详细输出模式
#   -h, --help      显示帮助信息
#
# Examples:
#   ./sftp-push.sh                    # 增量上传
#   ./sftp-push.sh --full             # 全量上传
#   ./sftp-push.sh -n                 # 预览模式
#   ./sftp-push.sh file1.php file2    # 上传指定文件
# ============================================================================

# ============================================================================
# 严格模式设置
# ============================================================================
set -euo pipefail

# ============================================================================
# 全局变量定义
# ============================================================================
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly VERSION="2.0.0"

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'  # No Color

# ============================================================================
# 日志函数
# ============================================================================
info()  { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$SCRIPT_NAME]${NC} $*" >&2; }
error() { echo -e "${RED}[$SCRIPT_NAME]${NC} $*" >&2; }
step()  { echo -e "${CYAN}[$SCRIPT_NAME]${NC} $*"; }

# ============================================================================
# 工具函数
# ============================================================================
# 显示帮助信息
show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] [FILES...]

SFTP 上传脚本 - 将本地文件上传到远程服务器

Options:
  -f, --full        全量上传所有文件
  -n, --dry-run     预览模式（显示操作但不执行）
  -v, --verbose     详细输出模式
  -d, --dir DIR     上传指定目录
  -h, --help        显示此帮助信息

Examples:
  $SCRIPT_NAME                      # 增量上传
  $SCRIPT_NAME --full               # 全量上传
  $SCRIPT_NAME -n                   # 预览模式
  $SCRIPT_NAME file1.php file2      # 上传指定文件
  $SCRIPT_NAME -d src/controllers/  # 上传指定目录

Version: $VERSION
EOF
}

# ============================================================================
# 核心函数
# ============================================================================

# 函数 1: 初始化配置
init_config() {
    local config_file="$1"
    # ... 实现
    :
}

# 函数 2: 验证配置
validate_config() {
    # ... 实现
    :
}

# 函数 3: 执行上传
upload_files() {
    # ... 实现
    :
}

# ============================================================================
# 参数解析
# ============================================================================
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--full)
                FULL_MODE=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                error "未知选项：$1"
                show_help
                exit 1
                ;;
            *)
                FILES+=("$1")
                shift
                ;;
        esac
    done
}

# ============================================================================
# 主函数
# ============================================================================
main() {
    # 1. 解析命令行参数
    parse_args "$@"

    # 2. 初始化配置
    info "正在初始化..."
    init_config "$CONFIG_FILE"

    # 3. 验证配置
    if ! validate_config "$CONFIG_FILE"; then
        error "配置验证失败"
        exit 1
    fi

    # 4. 执行上传
    step "开始上传文件..."
    upload_files

    # 5. 完成
    info "上传完成！"
}

# ============================================================================
# 脚本入口
# ============================================================================
main "$@"
```

### 4.1.2 各部分详解

#### 脚本头注释

```bash
#!/bin/bash
# ============================================================================
# 脚本头注释
# ============================================================================
```

**要点**：
- `#!/bin/bash` 必须是第一行（shebang）
- 使用分隔线让结构清晰
- 包含所有必要信息（功能、作者、用法、示例）

#### 严格模式设置

```bash
set -euo pipefail
```

**各选项含义**：

| 选项 | 含义 | 作用 |
|------|------|------|
| `-e` | errexit | 命令失败时立即退出 |
| `-u` | nounset | 使用未定义变量时报错 |
| `-o pipefail` | - | 管道中任一命令失败则整体失败 |

**示例对比**：

```bash
# 不使用 set -e
false
echo "这行会执行"  # 会执行

# 使用 set -e
set -e
false
echo "这行不会执行"  # 不会执行，脚本已退出

# pipefail 示例
# 不使用 pipefail
echo "test" | false | cat
echo $?  # 输出 0（cat 成功）

# 使用 pipefail
set -o pipefail
echo "test" | false | cat
echo $?  # 输出 1（false 失败）
```

#### 全局变量定义

```bash
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly VERSION="2.0.0"
```

**最佳实践**：
- 使用 `readonly` 声明常量
- 全局变量使用大写命名
- 局部变量使用小写命名

#### 日志函数

```bash
info()  { echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*"; }
warn()  { echo -e "${YELLOW}[$SCRIPT_NAME]${NC} $*" >&2; }
error() { echo -e "${RED}[$SCRIPT_NAME]${NC} $*" >&2; }
```

**设计要点**：
- `info` 输出到 stdout
- `warn` 和 `error` 输出到 stderr（`>&2`）
- 使用颜色区分日志级别
- 包含脚本名前缀便于识别

---

## 4.2 纯 Shell JSON 解析

### 4.2.1 为什么不用 jq

#### jq 的问题

```bash
# jq 需要安装
which jq
# /usr/local/bin/jq  (可能有，可能没有)

# 在没有 jq 的系统上
which jq
# (无输出)

# 尝试安装
apt-get install jq  # 需要 root 权限
# 或
brew install jq     # 需要 Homebrew
```

#### 零依赖原则

```
原则：脚本不应依赖用户可能需要额外安装的命令

✅ 内部命令（可用）
- bash 内置：echo, read, test, [[ ]], (( ))
- POSIX 标准：grep, sed, awk, cut, sort, uniq

❌ 外部依赖（避免）
- jq（JSON 处理）
- python3（除非明确需要）
- node（除非明确需要）
```

### 4.2.2 JSON 解析函数详解

#### 读取字符串值

```bash
json_get() {
    local file="$1"      # JSON 文件路径
    local key="$2"       # 要读取的键
    local default="${3:-}"  # 默认值

    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')

    if [ -z "$val" ] || [ "$val" = "null" ]; then
        echo "$default"
    else
        echo "$val"
    fi
}
```

**工作原理**：

```
假设 JSON 文件内容：
{
  "host": "example.com",
  "port": 22,
  "username": "deploy"
}

执行 json_get "config.json" "host":

1. grep "\"host\"" config.json
   结果：  "host": "example.com",

2. head -1
   结果：  "host": "example.com",

3. sed 's/.*: *"\([^"]*\)".*/\1/'
   解析过程：
   - .*:     匹配 "host":
   - *"      匹配空格和引号
   - \([^"]*\) 捕获 example.com
   - ".*    匹配后面的引号和逗号

   结果：example.com
```

**使用示例**：

```bash
CONFIG_FILE="sftp-config.json"

# 读取 host，无默认值
HOST=$(json_get "$CONFIG_FILE" "host")
echo "$HOST"  # 输出：example.com

# 读取 private_key，带默认值
PRIVATE_KEY=$(json_get "$CONFIG_FILE" "private_key" "")
echo "$PRIVATE_KEY"  # 如果为空则输出空字符串
```

#### 读取数字值

```bash
json_get_num() {
    local file="$1"
    local key="$2"
    local default="${3:-0}"

    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *\([0-9][0-9]*\).*/\1/')

    if [ -z "$val" ] || ! [[ "$val" =~ ^[0-9]+$ ]]; then
        echo "$default"
    else
        echo "$val"
    fi
}
```

**与字符串解析的区别**：

```bash
# JSON: "port": 22
# 字符串正则："\([^"]*\)"  → 匹配引号内的内容
# 数字正则：\([0-9][0-9]*\) → 匹配数字

# 数字没有引号包裹
grep '"port"' config.json
# 结果："port": 22

# sed 提取数字
sed 's/.*: *\([0-9][0-9]*\).*/\1/'
# 结果：22
```

**使用示例**：

```bash
PORT=$(json_get_num "$CONFIG_FILE" "port" "22")
echo "$PORT"  # 输出：22

# 如果 port 不存在，使用默认值
TIMEOUT=$(json_get_num "$CONFIG_FILE" "timeout" "30")
echo "$TIMEOUT"  # 输出：30
```

#### 读取数组

```bash
json_get_array() {
    local file="$1"
    local key="$2"

    # 提取数组部分
    sed -n '/"'"$key"'"/,/\]/p' "$file" | \
    # 过滤包含引号的行
    grep '"' | \
    # 排除 key 行
    grep -v "\"$key\"" | \
    # 提取字符串值
    sed 's/.*"\([^"]*\)".*/\1/'
}
```

**工作原理**：

```
假设 JSON 数组：
"excludes": [
  ".git",
  ".claude",
  "node_modules"
]

1. sed -n '/"excludes"/,/\]/p'
   结果:
   "excludes": [
     ".git",
     ".claude",
     "node_modules"
   ]

2. grep '"'
   结果（过滤掉不含引号的行）:
     ".git",
     ".claude",
     "node_modules"

3. grep -v "\"excludes\""
   结果（排除 key 行）:
     ".git",
     ".claude",
     "node_modules"

4. sed 's/.*"\([^"]*\)".*/\1/'
   结果:
   .git
   .claude
   node_modules
```

**使用示例**：

```bash
# 读取数组到 Bash 数组
EXCLUDES=()
while IFS= read -r line; do
    [ -n "$line" ] && EXCLUDES+=("$line")
done < <(json_get_array "$CONFIG_FILE" "excludes")

# 测试
for ex in "${EXCLUDES[@]}"; do
    echo "排除：$ex"
done
```

### 4.2.3 写入 JSON

#### 修改字符串值

```bash
json_set() {
    local file="$1"
    local key="$2"
    local value="$3"

    local tmp
    tmp=$(mktemp)

    # 使用 sed 替换
    sed "s|\"$key\": *\"[^\"]*\"|\"$key\": \"$value\"|" "$file" > "$tmp"
    mv "$tmp" "$file"
}
```

**工作原理**：

```
原内容:
"private_key": ""

执行 json_set "config.json" "private_key" "/path/to/key"

sed 替换:
s|"private_key": *"[^"]*"|"private_key": "/path/to/key"|

结果:
"private_key": "/path/to/key"
```

**使用示例**：

```bash
# 更新私钥路径
json_set "$CONFIG_FILE" "private_key" "$FOUND_KEY"

# 更新 host
json_set "$CONFIG_FILE" "host" "new-server.example.com"
```

#### 修改数字值

```bash
json_set_num() {
    local file="$1"
    local key="$2"
    local value="$3"

    local tmp
    tmp=$(mktemp)

    sed "s|\"$key\": *[0-9][0-9]*|\"$key\": $value|" "$file" > "$tmp"
    mv "$tmp" "$file"
}
```

### 4.2.4 限制和注意事项

#### 不支持复杂 JSON

```bash
# ❌ 嵌套 JSON 无法处理
{
  "server": {
    "host": "example.com"  # json_get 无法访问嵌套键
  }
}

# ✅ 扁平 JSON 可以处理
{
  "server_host": "example.com"  # 可以
}
```

#### 转义字符问题

```bash
# ❌ 值中包含引号会出错
"description": "He said \"hello\""

# ✅ 解决方案：避免在配置值中使用特殊字符
```

#### 性能考虑

```bash
# 对于大文件，每次 grep 会扫描整个文件
# 解决方案：将常用值缓存到变量

# 低效
for i in {1..10}; do
    val=$(json_get "$file" "key")
done

# 高效
val=$(json_get "$file" "key")
for i in {1..10}; do
    echo "$val"
done
```

---

## 4.3 错误处理

### 4.3.1 参数验证

#### 多字段验证

```bash
validate_config() {
    local config_file="$1"
    local missing=()

    # 检查每个必填字段
    [ -z "$(json_get "$config_file" "host")" ]        && missing+=("host")
    [ -z "$(json_get "$config_file" "username")" ]    && missing+=("username")
    [ -z "$(json_get "$config_file" "remote_path")" ] && missing+=("remote_path")

    # 如果有缺失字段
    if [ ${#missing[@]} -gt 0 ]; then
        error "配置不完整，缺少字段：${missing[*]}"
        error "请编辑配置文件：$config_file"
        return 1
    fi

    return 0
}
```

**输出示例**：

```
[push] 配置不完整，缺少字段：host username
[push] 请编辑配置文件：.claude/sftp-cc/sftp-config.json
```

#### 值范围验证

```bash
validate_port() {
    local port="$1"

    # 检查是否为数字
    if ! [[ "$port" =~ ^[0-9]+$ ]]; then
        error "端口必须是数字：$port"
        return 1
    fi

    # 检查范围
    if [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        error "端口必须在 1-65535 之间：$port"
        return 1
    fi

    return 0
}

# 使用
if ! validate_port "$PORT"; then
    exit 1
fi
```

#### 路径格式验证

```bash
validate_path() {
    local path="$1"
    local name="$2"

    # 空路径检查
    if [ -z "$path" ]; then
        error "$name 不能为空"
        return 1
    fi

    # 绝对路径建议
    if [[ "$path" != /* ]]; then
        warn "$name 建议使用绝对路径：$path"
    fi

    return 0
}
```

### 4.3.2 命令存在检查

```bash
check_dependencies() {
    local deps=("sftp" "git" "grep" "sed")
    local missing=()

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "缺少必需的命令：${missing[*]}"
        error "请安装缺失的命令后重试"
        return 1
    fi

    return 0
}

# 在脚本开头调用
if ! check_dependencies; then
    exit 1
fi
```

**输出示例**：

```
[push] 缺少必需的命令：sftp
[push] 请安装缺失的命令后重试
```

### 4.3.3 文件存在检查

#### 单个文件检查

```bash
if [ ! -f "$CONFIG_FILE" ]; then
    error "配置文件不存在：$CONFIG_FILE"
    error "请先运行 sftp-init.sh 初始化配置"
    exit 1
fi
```

#### 多个文件检查

```bash
check_required_files() {
    local files=("$@")
    local missing=()

    for f in "${files[@]}"; do
        if [ ! -f "$f" ]; then
            missing+=("$f")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "以下文件不存在:"
        for f in "${missing[@]}"; do
            error "  - $f"
        done
        return 1
    fi

    return 0
}

# 使用
if ! check_required_files "$CONFIG_FILE" "$PRIVATE_KEY"; then
    exit 1
fi
```

#### 目录检查

```bash
if [ ! -d "$LOCAL_PATH" ]; then
    error "源目录不存在：$LOCAL_PATH"
    exit 1
fi

# 如果目录不存在则创建
mkdir -p "$TARGET_DIR" || {
    error "无法创建目录：$TARGET_DIR"
    exit 1
}
```

### 4.3.4 权限检查

```bash
check_key_permissions() {
    local key_file="$1"

    if [ ! -f "$key_file" ]; then
        return 1
    fi

    local perms
    perms=$(stat -f "%Lp" "$key_file" 2>/dev/null || stat -c "%a" "$key_file" 2>/dev/null)

    if [ "$perms" != "600" ]; then
        error "私钥权限不安全：$perms (应该是 600)"
        error "运行以下命令修正："
        error "  chmod 600 $key_file"
        return 1
    fi

    return 0
}
```

### 4.3.5 错误恢复

```bash
# 尝试多种方法
copy_file_safe() {
    local src="$1"
    local dst="$2"

    # 方法 1: cp
    if cp "$src" "$dst" 2>/dev/null; then
        return 0
    fi

    # 方法 2: cat
    if cat "$src" > "$dst" 2>/dev/null; then
        return 0
    fi

    # 都失败了
    error "无法复制文件：$src -> $dst"
    return 1
}

# 使用
if ! copy_file_safe "$SRC" "$DST"; then
    error "复制失败，请手动处理"
    exit 1
fi
```

---

## 4.4 实战：sftp-keybind.sh 逐行解析

### 4.4.1 完整代码回顾

让我们逐行分析这个生产级脚本：

```bash
#!/bin/bash
# sftp-keybind.sh — 私钥自动绑定 + 权限修正
# 扫描 .claude/sftp-cc/ 下的私钥文件，自动绑定到配置文件并修正权限
set -euo pipefail

PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SFTP_CC_DIR="$PROJECT_ROOT/.claude/sftp-cc"
CONFIG_FILE="$SFTP_CC_DIR/sftp-config.json"

# ... (前面已讲解的部分省略)
```

### 4.4.2 关键代码解析

#### 1. 项目根目录定位

```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
```

**为什么这样做**：

```
场景 1：在项目根目录执行
$ cd /path/to/project
$ bash scripts/sftp-keybind.sh
→ git rev-parse --show-toplevel 输出 /path/to/project

场景 2：在子目录执行
$ cd /path/to/project/src/controllers
$ bash ../../scripts/sftp-keybind.sh
→ git rev-parse --show-toplevel 仍然输出 /path/to/project

场景 3：非 Git 项目
$ cd /path/to/not-a-git-project
$ bash scripts/sftp-keybind.sh
→ git rev-parse 失败（2>/dev/null 隐藏错误）
→ || pwd 回退到当前目录
```

#### 2. 私钥文件模式

```bash
KEY_PATTERNS=("id_rsa" "id_ed25519" "id_ecdsa" "id_dsa" "*.pem" "*.key")
```

**支持的私钥类型**：

| 模式 | 说明 |
|------|------|
| `id_rsa` | RSA 私钥（最常用） |
| `id_ed25519` | Ed25519 私钥（推荐） |
| `id_ecdsa` | ECDSA 私钥 |
| `id_dsa` | DSA 私钥（已废弃） |
| `*.pem` | PEM 格式私钥 |
| `*.key` | KEY 格式私钥 |

#### 3. 查找私钥文件

```bash
FOUND_KEY=""
for pattern in "${KEY_PATTERNS[@]}"; do
    while IFS= read -r -d '' keyfile; do
        # 跳过 .pub 公钥文件
        [[ "$keyfile" == *.pub ]] && continue
        # 跳过配置文件
        [[ "$(basename "$keyfile")" == "sftp-config"* ]] && continue
        # 跳过示例文件
        [[ "$(basename "$keyfile")" == *"example"* ]] && continue

        FOUND_KEY="$keyfile"
        break
    done < <(find "$SFTP_CC_DIR" -maxdepth 1 -name "$pattern" -print0 2>/dev/null)
    [ -n "$FOUND_KEY" ] && break
done
```

**代码解析**：

| 代码 | 作用 |
|------|------|
| `IFS= read -r -d ''` | 处理包含空格的文件名 |
| `-print0` | 用 null 分隔文件名（安全） |
| `[[ "$keyfile" == *.pub ]]` | 跳过公钥文件 |
| `2>/dev/null` | 隐藏 find 错误 |

#### 4. 权限检查和修正

```bash
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
```

**为什么权限重要**：

```
SSH 私钥权限必须是 600（只有所有者可读写）

如果权限太开放：
$ ls -la id_rsa
-rw-r--r--  1 user  staff  1823 Jan 1 12:00 id_rsa

SSH 会拒绝使用：
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@         WARNING: UNPROTECTED PRIVATE KEY FILE!          @
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
Permissions 0644 for 'id_rsa' are too open.
It is required that your private key files are NOT accessible by others.
```

### 4.4.3 执行流程图

```
┌─────────────────────────────────────────────────────────┐
│              sftp-keybind.sh 执行流程                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. 定位 .claude/sftp-cc/ 目录                          │
│     ↓                                                   │
│  2. 检查 sftp-config.json 是否存在                      │
│     ↓                                                   │
│  3. 读取 existing private_key 配置                      │
│     ↓                                                   │
│  ┌─→ 已配置且文件存在？                                │
│  │    ↓ 是                                              │
│  │    检查权限是否为 600                               │
│  │    ↓ 是 → 输出成功消息 → 退出                       │
│  │    ↓ 否 → chmod 600 → 输出成功消息 → 退出          │
│  │                                                     │
│  │    ↓ 否                                            │
│  4. 扫描目录查找私钥文件                                │
│     ↓                                                   │
│  5. 找到私钥？                                         │
│     ↓ 否 → 输出错误消息 → 退出                         │
│     ↓ 是                                              │
│  6. chmod 600 修正权限                                 │
│     ↓                                                   │
│  7. 写入 sftp-config.json                              │
│     ↓                                                   │
│  8. 输出成功消息                                       │
│     ↓                                                   │
│  9. 退出                                               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 4.5 临时文件管理

### 4.5.1 mktemp 创建临时文件

```bash
# 创建临时文件
tmp_file=$(mktemp)
changed_list=$(mktemp)
batch_file=$(mktemp)

# 使用临时文件
echo "content" > "$tmp_file"
process_file "$tmp_file"

# 使用后立即删除
rm -f "$tmp_file"
```

### 4.5.2 trap 确保清理

```bash
# 定义清理函数
cleanup() {
    rm -f "$tmp_file" "$changed_list" "$batch_file"
}

# 注册退出时清理
trap cleanup EXIT

# 注册错误时清理
trap cleanup ERR

# 现在即使脚本异常退出，临时文件也会被清理
```

### 4.5.3 完整示例

```bash
#!/bin/bash
set -euo pipefail

# 临时文件列表
TEMP_FILES=()

# 清理函数
cleanup() {
    for f in "${TEMP_FILES[@]}"; do
        rm -f "$f"
    done
}

# 注册清理
trap cleanup EXIT

# 创建临时文件的辅助函数
make_temp() {
    local tmp
    tmp=$(mktemp)
    TEMP_FILES+=("$tmp")
    echo "$tmp"
}

# 使用
changed_list=$(make_temp)
deleted_list=$(make_temp)

# ... 使用临时文件 ...

# 不需要手动删除，退出时自动清理
```

---

## 4.6 调试技巧

### 4.6.1 set 命令选项

```bash
# 开发阶段：详细调试
set -xv

# 生产阶段：严格错误处理
set -euo pipefail

# 组合使用
set -euo pipefail -x  # 严格模式 + 调试输出
```

### 4.6.2 条件调试输出

```bash
# 解析 verbose 参数
VERBOSE=false
if [[ "${1:-}" == "-v" ]] || [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

# debug 函数
debug() {
    $VERBOSE && echo -e "[DEBUG] $*" >&2
}

# 使用
debug "配置路径：$CONFIG_FILE"
debug "排除列表：${EXCLUDES[*]}"
```

### 4.6.3 性能分析

```bash
# 测量执行时间
start_time=$(date +%s.%N)

# ... 执行的代码 ...

end_time=$(date +%s.%N)
elapsed=$(echo "$end_time - $start_time" | bc)
echo "执行时间：${elapsed}s"
```

---

## 4.7 本章总结

### 核心知识点回顾

| 概念 | 关键点 |
|------|--------|
| 脚本结构 | 注释头、严格模式、全局变量、函数、main 入口 |
| JSON 解析 | grep + sed 实现零依赖解析 |
| 错误处理 | 参数验证、命令检查、文件检查、权限检查 |
| 临时文件 | mktemp + trap 确保清理 |
| 调试技巧 | set -x、条件输出、时间测量 |

### 脚本检查清单

- [ ] 脚本头注释完整
- [ ] set -euo pipefail 已设置
- [ ] 日志函数定义完整
- [ ] 参数验证完善
- [ ] 错误消息清晰有帮助
- [ ] 临时文件正确清理
- [ ] 调试输出可控

---

## 4.8 练习与实践

### 基础练习

**练习 4-1**：完善 json_get
- 添加对 null 值的处理
- 添加对布尔值的处理

**练习 4-2**：添加日志级别
- 实现 DEBUG、INFO、WARN、ERROR 四级日志
- 通过环境变量控制输出级别

### 进阶练习

**练习 4-3**：创建工具库
- 将 json_get、json_set 等函数提取到 utils.sh
- 在其他脚本中 source 使用

### 实践项目

编写一个配置管理脚本：
- 读取配置文件
- 验证所有必填字段
- 支持交互式修改配置
- 保存修改后的配置

---

## 下一章预告

第 5 章将介绍**多语言支持 (i18n)**：
- 三语言方案设计（英文、中文、日文）
- 变量式多语言实现（$MSG_XXX 方案）
- i18n.sh 工具库实现
- 语言配置读取和切换

---

## 关于本书

**第一版（数字版）, 2026 年 3 月**

**作者**：[toohamster](https://github.com/toohamster)
**授权**：电子版 MIT License，纸质版/商业版 © All Rights Reserved
**源码**：[github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

详细说明请参阅 [LICENSE](../../LICENSE) 和 [关于作者](../authors.md)

---
