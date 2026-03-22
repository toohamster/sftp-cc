# 第 8 章：进阶与最佳实践

> "优秀的程序员写出的代码人类能读懂，而机器也能执行。" — Martin Fowler

本章你将学到：
- 性能优化技巧（减少子进程、批量处理）
- 安全最佳实践（命令注入、路径安全）
- 代码组织规范（函数命名、变量作用域）
- 错误处理进阶（trap、超时处理）
- 可维护性提升（注释规范、配置分离）
- 用户反馈处理流程
- 完整的故障排查清单
- 扩展开发方向
- 学习资源推荐
- 本书总结和实战项目

---

## 8.1 性能优化

### 8.1.1 减少子进程调用

在 Shell 中，每次调用外部命令都会创建子进程，这是性能开销的主要来源。

#### 问题示例

```bash
#!/bin/bash
# 低效的代码

files=("file1.txt" "file2.txt" "file3.txt")

for file in "${files[@]}"; do
    # 每次循环都调用 grep（创建子进程）
    result=$(grep "pattern" "$file")

    # 每次循环都调用 wc（创建子进程）
    count=$(wc -l < "$file")

    # 每次循环都调用 basename（创建子进程）
    name=$(basename "$file")
done
```

#### 优化方案

```bash
#!/bin/bash
# 高效的代码

files=("file1.txt" "file2.txt" "file3.txt")

# 批量处理：一次调用处理所有文件
grep "pattern" "${files[@]}" > /tmp/results.txt

# 使用内置命令代替外部命令
count=0
for file in "${files[@]}"; do
    while IFS= read -r line; do
        ((count++))
    done < "$file"
done

# 使用参数扩展代替 basename
for file in "${files[@]}"; do
    name="${file##*/}"  # Bash 内置，无需子进程
    echo "处理：$name"
done
```

#### 性能对比

```bash
# 测试：处理 100 个文件

# 方法 1：每次调用子进程
time for i in {1..100}; do
    grep "pattern" "file$i.txt" > /dev/null
done
# 结果：约 2.5 秒

# 方法 2：批量处理
time grep "pattern" file{1..100}.txt > /dev/null
# 结果：约 0.1 秒

# 性能提升：25 倍
```

### 8.1.2 避免不必要的命令

#### 冗余检查示例

```bash
# ❌ 低效：多次系统调用
if [ -f "$file" ]; then
    if [ -r "$file" ]; then
        if [ -s "$file" ]; then
            cat "$file"
        fi
    fi
fi

# ✅ 高效：合并条件
if [ -f "$file" ] && [ -r "$file" ] && [ -s "$file" ]; then
    cat "$file"
fi

# ✅ 更高效：使用 test 组合
if [ -f "$file" ] && [ -r "$file" ] && [ -s "$file" ]; then
    cat "$file"
fi
```

#### 路径解析优化

```bash
# ❌ 低效：调用外部命令
dir=$(dirname "$path")
base=$(basename "$path")

# ✅ 高效：使用参数扩展
dir="${path%/*}"    # 删除最后一个/之后的内容
base="${path##*/}"  # 删除最后一个/之前的内容

# 边界情况处理
if [ "$dir" = "$path" ]; then
    dir="."
fi
if [ "$base" = "$path" ]; then
    dir="."
fi
```

### 8.1.3 使用数组而非字符串拼接

#### 危险模式

```bash
# ❌ 危险：使用 eval
args=""
for f in "${files[@]}"; do
    args="$args \"$f\""  # 字符串拼接
done
eval "command $args"  # eval 有安全风险

# 问题：如果文件名包含特殊字符
files=("file with spaces.txt" "file'quote.txt")
# eval 会错误解析
```

#### 安全模式

```bash
# ✅ 安全：使用数组
args=()
for f in "${files[@]}"; do
    args+=("$f")  # 数组追加
done
command "${args[@]}"  # 安全展开

# 数组自动处理空格和特殊字符
```

### 8.1.4 循环优化

#### 使用 mapfile 代替 while read

```bash
# ❌ 低效：while read 逐行处理
files=()
while IFS= read -r file; do
    files+=("$file")
done < <(find . -name "*.txt")

# ✅ 高效：mapfile 批量读取
mapfile -t files < <(find . -name "*.txt")

# Bash 4.0+ 支持
```

#### 使用 glob 代替 find（简单场景）

```bash
# ❌ 低效：简单场景用 find
files=$(find . -maxdepth 1 -name "*.txt")

# ✅ 高效：使用 glob
files=( *.txt )

# 检查是否有匹配
if [ ${#files[@]} -eq 0 ] || [ "${files[0]}" = "*.txt" ]; then
    echo "没有找到文件"
fi
```

---

## 8.2 安全最佳实践

### 8.2.1 避免命令注入

#### 危险模式

```bash
#!/bin/bash
# ❌ 危险：直接使用用户输入

# 场景 1：eval
user_input="$1"
eval "echo $user_input"  # 危险！
# 输入：$(rm -rf /)  → 执行恶意命令

# 场景 2：反引号
user_file="$1"
content=`cat $user_file`  # 危险！

# 场景 3：$()
user_cmd="$1"
result=$($user_cmd)  # 危险！
```

#### 安全模式

```bash
#!/bin/bash
# ✅ 安全：正确处理用户输入

# 方法 1：使用变量，不使用 eval
user_input="$1"
echo "$user_input"  # 安全输出

# 方法 2：验证输入
user_file="$1"
# 只允许字母数字和点
if [[ ! "$user_file" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "无效的文件名"
    exit 1
fi
cat "$user_file"

# 方法 3：使用白名单
allowed_commands=("ls" "cat" "grep")
user_cmd="$1"
if [[ ! " ${allowed_commands[@]} " =~ " $user_cmd " ]]; then
    echo "不允许的命令"
    exit 1
fi
```

### 8.2.2 安全处理文件路径

#### 路径遍历攻击防护

```bash
#!/bin/bash
# 安全的路径处理

validate_path() {
    local path="$1"
    local base_dir="$2"

    # 1. 解析绝对路径
    local real_path
    real_path=$(realpath -m "$path" 2>/dev/null || echo "$path")

    # 2. 解析基准目录
    local real_base
    real_base=$(realpath -m "$base_dir" 2>/dev/null || echo "$base_dir")

    # 3. 检查是否在基准目录内
    if [[ "$real_path" != "$real_base"* ]]; then
        echo "错误：路径超出允许范围"
        return 1
    fi

    # 4. 检查是否包含 ..
    if [[ "$path" == *".."* ]]; then
        echo "警告：路径包含 .."
    fi

    return 0
}

# 使用示例
PROJECT_ROOT="/var/www/project"
user_path="$1"

if ! validate_path "$user_path" "$PROJECT_ROOT"; then
    exit 1
fi
```

#### 符号链接攻击防护

```bash
#!/bin/bash
# 防止符号链接攻击

safe_read() {
    local file="$1"

    # 检查是否是符号链接
    if [ -L "$file" ]; then
        echo "警告：文件是符号链接"
        # 可以选择拒绝
        return 1
    fi

    # 检查实际文件
    if [ ! -f "$file" ]; then
        echo "错误：文件不存在"
        return 1
    fi

    cat "$file"
}
```

### 8.2.3 敏感信息保护

#### 不在日志中暴露敏感信息

```bash
#!/bin/bash
# ❌ 危险：日志中暴露密码
log_debug "连接参数：host=$HOST, user=$USER, pass=$PASSWORD"

# ✅ 安全：脱敏处理
log_debug "连接参数：host=$HOST, user=$USER, pass=****"
```

#### 安全的密码输入

```bash
#!/bin/bash
# 安全的密码输入

read_password() {
    local prompt="${1:-Password:}"
    local password

    # 禁用回显
    read -sp "$prompt " password
    echo  # 换行

    # 返回密码（通过全局变量）
    PASSWORD="$password"
}

# 使用
read_password "输入服务器密码："
# 密码不会显示在终端
```

#### 安全的临时文件

```bash
#!/bin/bash
# 安全地创建临时文件

# ❌ 不安全：可预测的文件名
tmp="/tmp/my_script_$$"
echo "data" > "$tmp"  # 可能被 symlink 攻击

# ✅ 安全：使用 mktemp
tmp=$(mktemp) || exit 1
echo "data" > "$tmp"

# 设置安全权限
chmod 600 "$tmp"

# 使用后立即删除
rm -f "$tmp"
```

### 8.2.4 权限管理最佳实践

```bash
#!/bin/bash
# 权限管理

# 私钥文件：600（只有所有者可读写）
chmod 600 "$PRIVATE_KEY"

# 配置文件：644（所有者写，其他人读）
chmod 644 "$CONFIG_FILE"

# 包含敏感信息的配置：600
chmod 600 "$SENSITIVE_CONFIG"

# 脚本文件：755（所有者执行，其他人执行）
chmod 755 "$SCRIPT_FILE"

# 目录：755
chmod 755 "$SCRIPT_DIR"

# 验证权限
check_permissions() {
    local file="$1"
    local expected="$2"

    local actual
    actual=$(stat -c "%a" "$file" 2>/dev/null)

    if [ "$actual" != "$expected" ]; then
        echo "警告：$file 权限是 $actual，应该是 $expected"
        return 1
    fi
    return 0
}
```

---

## 8.3 代码组织

### 8.3.1 函数命名规范

#### 命名约定

```bash
# 动词 + 名词：描述函数行为
init_config()      # 初始化配置
load_messages()    # 加载消息
push_files()       # 推送文件
collect_changes()  # 收集变更

# 布尔函数：使用 is/has/check/validate 前缀
is_excluded()      # 是否被排除
has_permission()   # 是否有权限
check_config()     # 检查配置
validate_input()   # 验证输入

# 内部函数：使用下划线前缀
_helper_function() {
    # 仅供内部使用
}

# 导出函数：无特殊前缀
public_function() {
    # 可以被其他脚本调用
}
```

#### 函数文档

```bash
# ========================================
# 函数：json_get
# 功能：从 JSON 文件中读取字符串值
# 参数：
#   $1 - 文件路径
#   $2 - 键名
#   $3 - 默认值（可选）
# 返回：
#   stdout - 值
# 示例：
#   host=$(json_get "config.json" "host" "localhost")
# ========================================
json_get() {
    local file="$1"
    local key="$2"
    local default="${3:-}"

    # ... 实现 ...
}
```

### 8.3.2 变量作用域管理

#### 全局变量

```bash
#!/bin/bash

# 只读全局变量（常量）
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly VERSION="1.0.0"
readonly CONFIG_DIR="$HOME/.config/myapp"

# 可写全局变量（状态）
DEBUG_MODE=false
VERBOSE=false
CURRENT_STEP=0
```

#### 局部变量

```bash
process_file() {
    local file="$1"           # 参数
    local content             # 临时变量
    local line_count=0        # 带初始值
    local temp_file           # 临时文件

    # ... 实现 ...
}
```

#### 变量命名约定

| 类型 | 命名规范 | 示例 |
|------|----------|------|
| 全局常量 | 全大写下划线 | `MAX_RETRY`, `DEFAULT_PORT` |
| 全局变量 | 小写下划线 | `debug_mode`, `current_step` |
| 局部变量 | 小写下划线 | `file_path`, `line_count` |
| 函数参数 | 小写下划线 | `file`, `count`, `options` |

### 8.3.3 模块化设计

#### 函数库分离

```bash
# lib/utils.sh - 工具函数库
#!/bin/bash

lib_utils_log() {
    echo "[$(date +%H:%M:%S)] $*"
}

lib_utils_error() {
    echo "[ERROR] $*" >&2
}

# lib/json.sh - JSON 处理库
#!/bin/bash

lib_json_get() {
    local file="$1" key="$2"
    # ... 实现 ...
}

# main.sh - 主脚本
#!/bin/bash

source "$(dirname "$0")/lib/utils.sh"
source "$(dirname "$0")/lib/json.sh"

main() {
    lib_utils_log "启动..."
    # ...
}
```

### 8.3.4 完整脚本结构模板

```bash
#!/bin/bash
# ============================================================================
# 脚本：sftp-push.sh
# 功能：SFTP 上传脚本，支持增量上传
# 作者：your-name
# 版本：2.0.0
# ============================================================================

# 严格模式
set -euo pipefail

# ============================================================================
# 全局常量
# ============================================================================
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly VERSION="2.0.0"

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

# ============================================================================
# 全局变量
# ============================================================================
VERBOSE=false
DRY_RUN=false
FULL_MODE=false

# ============================================================================
# 工具函数
# ============================================================================
info() {
    echo -e "${GREEN}[$SCRIPT_NAME]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[$SCRIPT_NAME]${NC} $*" >&2
}

error() {
    echo -e "${RED}[$SCRIPT_NAME]${NC} $*" >&2
}

show_help() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS] [FILES...]

SFTP 上传脚本

Options:
  -f, --full        全量上传
  -n, --dry-run     预览模式
  -v, --verbose     详细输出
  -h, --help        显示帮助

Version: $VERSION
EOF
}

# ============================================================================
# 核心函数
# ============================================================================
init_config() {
    local config_file="$1"
    # 实现...
}

validate_config() {
    local config_file="$1"
    # 实现...
}

upload_files() {
    local files=("$@")
    # 实现...
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
# 清理函数
# ============================================================================
cleanup() {
    local exit_code=$?
    # 清理临时文件
    rm -f "$TEMP_FILE" 2>/dev/null || true
    exit $exit_code
}

# ============================================================================
# 主函数
# ============================================================================
main() {
    trap cleanup EXIT

    parse_args "$@"

    info "初始化配置..."
    init_config "$CONFIG_FILE"

    info "验证配置..."
    if ! validate_config "$CONFIG_FILE"; then
        exit 1
    fi

    info "开始上传..."
    upload_files "${FILES[@]}"

    info "上传完成！"
}

# ============================================================================
# 入口点
# ============================================================================
main "$@"
```

---

## 8.4 错误处理进阶

### 8.4.1 trap 错误捕获

```bash
#!/bin/bash
set -euo pipefail

# 错误处理函数
error_handler() {
    local exit_code=$?
    local line_no="${1:-unknown}"

    echo "" >&2
    echo "================================" >&2
    echo "错误!" >&2
    echo "================================" >&2
    echo "脚本：$SCRIPT_NAME" >&2
    echo "行号：$line_no" >&2
    echo "退出码：$exit_code" >&2
    echo "================================" >&2

    # 清理资源
    cleanup

    exit $exit_code
}

# 注册错误处理器
trap 'error_handler ${LINENO}' ERR

# 注册退出处理器
trap cleanup EXIT

# 注册中断处理器
trap 'echo "中断信号收到"; cleanup; exit 130' INT TERM
```

### 8.4.2 重试机制实现

```bash
#!/bin/bash

# 通用重试函数
retry() {
    local max_attempts="${1:-3}"
    local delay="${2:-5}"
    shift 2

    local attempt=1
    local result

    while [ $attempt -le $max_attempts ]; do
        log_debug "尝试 $attempt/$max_attempts: $*"

        if result=$("$@" 2>&1); then
            echo "$result"
            return 0
        fi

        local exit_code=$?
        log_warn "命令失败（尝试 $attempt/$max_attempts），$delay 秒后重试..."
        sleep "$delay"
        ((attempt++))
    done

    log_error "命令在 $max_attempts 次尝试后仍失败"
    return $exit_code
}

# 使用示例
if ! retry 3 5 sftp "$SFTP_OPTS" "$SFTP_TARGET" < "$batch_file"; then
    exit 1
fi
```

### 8.4.3 超时处理

```bash
#!/bin/bash

# 带超时的命令执行
run_with_timeout() {
    local timeout_secs="$1"
    shift

    local pid
    local result

    # 后台执行命令
    "$@" &
    pid=$!

    # 计时等待
    local elapsed=0
    while kill -0 "$pid" 2>/dev/null; do
        if [ $elapsed -ge $timeout_secs ]; then
            kill -9 "$pid" 2>/dev/null
            wait "$pid" 2>/dev/null
            log_error "命令超时（${timeout_secs}s）"
            return 124  # timeout 退出码
        fi
        sleep 1
        ((elapsed++))
    done

    # 等待完成
    wait "$pid"
    result=$?

    return $result
}

# 使用示例
if ! run_with_timeout 30 sftp "$SFTP_TARGET" < "$batch_file"; then
    exit 1
fi
```

---

## 8.5 可维护性提升

### 8.5.1 注释规范

#### 文件头注释

```bash
#!/bin/bash
# ============================================================================
# 脚本：sftp-push.sh
# 功能：SFTP 文件上传脚本，支持增量上传和全量上传
# 作者：张三 <zhangsan@example.com>
# 版本：2.0.0
# 创建日期：2024-01-01
# 最后更新：2024-01-15
#
# 依赖：
#   - bash 4.0+
#   - sftp (OpenSSH)
#   - git
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
```

#### 代码块注释

```bash
# ========================================
# 步骤 1: 加载配置
# ========================================
# 从 sftp-config.json 读取连接参数
# 如果文件不存在，提示用户运行初始化
if [ ! -f "$CONFIG_FILE" ]; then
    error "配置文件不存在"
    exit 1
fi

# ========================================
# 步骤 2: 验证配置
# ========================================
# 检查必填字段：host, username, remote_path
validate_config "$CONFIG_FILE" || exit 1

# ========================================
# 步骤 3: 建立连接
# ========================================
# 使用私钥（如果有）建立 SFTP 连接
# 连接超时设置为 30 秒
```

### 8.5.2 配置与代码分离

```bash
#!/bin/bash

# ============================================================================
# 默认配置（硬编码的合理默认值）
# ============================================================================
readonly DEFAULT_PORT=22
readonly DEFAULT_TIMEOUT=30
readonly DEFAULT_LANGUAGE="en"
readonly DEFAULT_EXCLUDES=(".git" ".claude" "node_modules" ".env")

# ============================================================================
# 用户配置（从配置文件加载）
# ============================================================================
load_user_config() {
    local config_file="$1"

    # 从配置加载，回退到默认值
    HOST=$(json_get "$config_file" "host" "")
    PORT=$(json_get_num "$config_file" "port" "$DEFAULT_PORT")
    USERNAME=$(json_get "$config_file" "username" "")
    REMOTE_PATH=$(json_get "$config_file" "remote_path" "")
    LANGUAGE=$(json_get "$config_file" "language" "$DEFAULT_LANGUAGE")

    # 加载排除列表
    EXCLUDES=("${DEFAULT_EXCLUDES[@]}")
    while IFS= read -r line; do
        [ -n "$line" ] && EXCLUDES+=("$line")
    done < <(json_get_array "$config_file" "excludes")
}
```

### 8.5.3 版本兼容性检查

```bash
#!/bin/bash

check_bash_version() {
    local required_major=4
    local current_major=${BASH_VERSION%%.*}

    if [ "$current_major" -lt "$required_major" ]; then
        echo "错误：需要 Bash $required_major.0 或更高版本" >&2
        echo "当前版本：$BASH_VERSION" >&2
        exit 1
    fi
}

check_dependencies() {
    local deps=("git" "sftp" "grep" "sed" "find")
    local missing=()

    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "错误：缺少以下命令：${missing[*]}" >&2
        echo "请安装缺失的命令后重试" >&2
        exit 1
    fi
}

# 在脚本开头调用
check_bash_version
check_dependencies
```

---

## 8.6 用户反馈处理

### 8.6.1 反馈收集渠道

```
反馈来源
├── GitHub Issues
│   ├── Bug 报告
│   └── 功能请求
│
├── 文档评论
│   ├── README.md Issues
│   └── 讨论区
│
├── 使用统计（可选）
│   ├── 日活用户
│   └── 常用功能
│
└── 直接联系
    ├── 邮件
    └── 社交媒体
```

### 8.6.2 反馈分类和处理流程

#### Bug 报告处理

```
1. 接收 Bug 报告
   ↓
2. 复现问题
   ├── 能复现 → 进入修复流程
   └── 不能复现 → 请求更多信息
   ↓
3. 确定严重性
   ├── 严重（崩溃、数据丢失）→ 立即修复，发布 Patch
   ├── 一般（功能异常）→ 计划修复
   └── 轻微（UI 问题）→ 排期修复
   ↓
4. 修复和测试
   ↓
5. 发布 Patch 版本
   ↓
6. 通知报告者
```

#### 功能请求处理

```
1. 接收功能请求
   ↓
2. 评估需求
   ├── 用户覆盖面
   ├── 实现复杂度
   └── 是否符合项目定位
   ↓
3. 决策
   ├── 接受 → 加入 Roadmap
   ├── 拒绝 → 解释原因
   └── 搁置 → 等待更多反馈
   ↓
4. 实现（接受时）
   ↓
5. 发布 Minor 版本
```

### 8.6.3 版本发布节奏

| 版本类型 | 触发条件 | 发布频率 | 示例 |
|----------|----------|----------|------|
| Patch | Bug 修复 | 随时 | v2.1.0 → v2.1.1 |
| Minor | 新功能 | 每 2-4 周 | v2.1.0 → v2.2.0 |
| Major | 破坏性变更 | 每 3-6 个月 | v2.0.0 → v3.0.0 |

---

## 8.7 完整故障排查清单

### 8.7.1 Skill 相关问题

#### Skill 不触发

```
问题：在 Claude 中说出触发词，但 Skill 没有响应

排查步骤：
□ 1. 检查 Plugin 是否已安装
   命令：/plugin list
   预期：看到 sftp-cc 在列表中

□ 2. 检查触发词是否正确
   参考：SKILL.md 中的触发词列表
   注意：触发词需要完全匹配或语义相似

□ 3. 重新加载 Plugin
   命令：/plugin marketplace remove sftp-cc
         /plugin marketplace add https://github.com/toohamster/sftp-cc

□ 4. 检查 marketplace.json
   命令：cat .claude-plugin/marketplace.json
   检查：name, description, skills 字段是否存在

□ 5. 查看 Claude Code 日志
   命令：检查是否有错误信息
```

#### 变量未解析

```
问题：${CLAUDE_PLUGIN_ROOT} 显示为空

排查步骤：
□ 1. 确认在 Claude Code 上下文中使用
   说明：该变量只在 Skill 执行时注入

□ 2. 检查 SKILL.md 中的脚本路径
   正确：bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
   错误：bash ./scripts/sftp-push.sh

□ 3. 直接 Shell 测试时使用绝对路径
   命令：bash ~/.claude/plugins/marketplaces/sftp-cc/scripts/sftp-push.sh
```

### 8.7.2 脚本执行问题

#### JSON 解析失败

```
问题：json_get 返回空值或错误

排查步骤：
□ 1. 检查配置文件内容
   命令：cat .claude/sftp-cc/sftp-config.json

□ 2. 检查 JSON 格式
   命令：jq '.' .claude/sftp-cc/sftp-config.json

□ 3. 检查 BOM 头
   命令：file .claude/sftp-cc/sftp-config.json
   预期：不包含 "with BOM"

□ 4. 手动测试 grep/sed
   命令：grep '"host"' config.json | sed 's/.*: *"\([^"]*\)".*/\1/'

□ 5. 添加调试输出
   在 json_get 函数中添加：echo "[DEBUG] file=$file key=$key" >&2
```

#### SFTP 连接失败

```
问题：SFTP 上传失败，错误码非 0

排查步骤：
□ 1. 检查网络连接
   命令：ping -c 3 $HOST

□ 2. 检查 SSH 端口
   命令：nc -zv $HOST $PORT

□ 3. 验证服务器信息
   命令：检查 sftp-config.json 中的 host, port, username

□ 4. 检查私钥权限
   命令：ls -la $PRIVATE_KEY
   预期：权限为 600

□ 5. 手动测试 SFTP
   命令：sftp -v -P $PORT -i $PRIVATE_KEY $USERNAME@$HOST

□ 6. 检查 SSH 公钥是否部署
   命令：ssh $USERNAME@$HOST "cat ~/.ssh/authorized_keys"
```

### 8.7.3 增量检测问题

#### 检测不到变更

```
问题：修改了文件但脚本说"没有变更"

排查步骤：
□ 1. 检查 .last-push 文件
   命令：cat .claude/sftp-cc/.last-push

□ 2. 检查 git 状态
   命令：git status
         git diff --name-only HEAD

□ 3. 验证 last_hash 是否有效
   命令：git cat-file -t $(head -1 .last-push)
   预期：输出 commit

□ 4. 检查文件是否在排除列表中
   命令：检查 config 中的 excludes

□ 5. 强制全量上传
   命令：rm .claude/sftp-cc/.last-push
         bash scripts/sftp-push.sh --full
```

---

## 8.8 扩展开发方向

### 8.8.1 功能扩展建议

#### 短期（1-2 个月）

| 功能 | 难度 | 价值 | 说明 |
|------|------|------|------|
| 断点续传 | ⭐⭐⭐ | ⭐⭐⭐ | 大文件上传中断后可继续 |
| 上传队列 | ⭐⭐ | ⭐⭐ | 支持多个上传任务排队 |
| 差异预览 | ⭐⭐ | ⭐⭐⭐ | 上传前显示文件差异 |
| 配置文件验证 | ⭐ | ⭐⭐⭐ | 启动时验证配置完整性 |

#### 中期（3-6 个月）

| 功能 | 难度 | 价值 | 说明 |
|------|------|------|------|
| 多服务器支持 | ⭐⭐⭐⭐ | ⭐⭐⭐ | 同时部署到多个环境 |
| 下载功能 | ⭐⭐⭐ | ⭐⭐ | 从服务器拉取文件 |
| 文件监听 | ⭐⭐⭐⭐ | ⭐⭐ | 自动检测并上传变更 |
| 回滚支持 | ⭐⭐⭐⭐ | ⭐⭐⭐ | 记录历史版本 |

#### 长期（6 个月+）

| 功能 | 难度 | 价值 | 说明 |
|------|------|------|------|
| 并行上传 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | 同时上传多个文件 |
| 增量压缩 | ⭐⭐⭐⭐⭐ | ⭐⭐ | 减少传输数据量 |
| Web 界面 | ⭐⭐⭐⭐⭐ | ⭐ | 图形化管理界面 |

### 8.8.2 集成扩展

```
集成方向
├── CI/CD
│   ├── GitHub Actions
│   ├── GitLab CI
│   └── Jenkins
│
├── 通知系统
│   ├── Slack Webhook
│   ├── 钉钉机器人
│   └── 企业微信
│
├── 监控系统
│   ├── Prometheus
│   └── Grafana
│
└── 云平台
    ├── AWS S3
    ├── 阿里云 OSS
    └── 腾讯云 COS
```

---

## 8.9 学习资源

### 8.9.1 Shell 编程

#### 入门

- 《Bash 初学者指南》- 中文版
- 《Learning the bash Shell》- O'Reilly

#### 进阶

- 《Advanced Bash-Scripting Guide》- 免费在线书籍
- 《Bash Cookbook》- O'Reilly

#### 参考

- [GNU Bash 官方文档](https://www.gnu.org/software/bash/manual/)
- [ShellCheck 规则说明](https://github.com/koalaman/shellcheck/wiki/Checks)

### 8.9.2 Claude Code 开发

- [Claude Code 官方文档](https://docs.anthropic.com/claude-code/)
- [Plugin Marketplace](https://claude.ai/marketplace)
- [sftp-cc 示例项目](https://github.com/toohamster/sftp-cc)

### 8.9.3 相关工具

| 工具 | 用途 | 安装 |
|------|------|------|
| shellcheck | Shell 静态分析 | `brew install shellcheck` |
| shfmt | Shell 代码格式化 | `go install mvdan.cc/sh/v3/cmd/shfmt` |
| jq | JSON 处理 | `brew install jq` |
| git | 版本控制 | `brew install git` |

---

## 8.10 本书总结

### 8.10.1 核心知识点回顾

| 章节 | 核心内容 | 关键技能 |
|------|----------|----------|
| 第 1 章 | Plugin 架构 | 理解 SKILL.md、marketplace.json |
| 第 2 章 | 项目规划 | 需求分析、功能设计 |
| 第 3 章 | Skill 编写 | 触发词设计、YAML Frontmatter |
| 第 4 章 | 脚本开发 | JSON 解析、错误处理 |
| 第 5 章 | 多语言支持 | i18n 方案、消息管理 |
| 第 6 章 | 调试测试 | set 选项、单元测试 |
| 第 7 章 | 发布分发 | SemVer、GitHub API |
| 第 8 章 | 最佳实践 | 性能优化、安全规范 |

### 8.10.2 实战检查清单

在发布你的 Skill 之前，确认：

**代码质量**
- [ ] 通过 shellcheck 检查
- [ ] 使用 set -euo pipefail
- [ ] 完整的错误处理
- [ ] 临时文件正确清理

**文档完整**
- [ ] README.md（英文）
- [ ] README_CN.md（中文）
- [ ] CHANGELOG.md
- [ ] LICENSE

**测试覆盖**
- [ ] 单元测试通过
- [ ] 集成测试通过
- [ ] 多语言测试通过

**发布准备**
- [ ] marketplace.json 验证通过
- [ ] 版本号正确
- [ ] GitHub Release 已创建

### 8.10.3 下一步行动

1. **选择一个想法**
   - 你想解决什么问题？
   - 现有方案有什么不足？

2. **设计 Skill**
   - 触发词是什么？
   - 需要什么脚本？
   - 配置文件格式？

3. **实现 MVP**
   - 最小可用功能
   - 快速迭代

4. **发布到 Marketplace**
   - 创建 GitHub 仓库
   - 发布第一个版本
   - 收集用户反馈

5. **持续改进**
   - 修复 Bug
   - 添加新功能
   - 优化性能

---

## 8.11 实战项目

### 项目 8-1：创建你的第一个 Skill

**要求**：
1. 解决一个实际问题
2. 包含完整的 SKILL.md
3. 至少 2 个脚本
4. 支持中英文触发词

**示例想法**：
- 数据库备份工具
- 代码格式化助手
- 项目初始化模板
- API 测试工具

### 项目 8-2：添加多语言支持

**要求**：
1. 创建 i18n.sh
2. 支持至少 3 种语言
3. 所有用户可见消息都已翻译

### 项目 8-3：发布到 Marketplace

**要求**：
1. 创建 GitHub 仓库
2. 编写完整的 README
3. 创建第一个 Release
4. 提交到 Plugin Marketplace

---

## 结语

恭喜你完成了本书的学习！

通过开发 sftp-cc 这个完整的 Claude Code Skill，你已经掌握了：
- Plugin 架构和开发流程
- Shell 脚本开发技巧
- 多语言支持实现
- 调试和测试方法
- 发布和分发流程

现在，开始创建你自己的 Skill 吧！

**最好的学习方式就是动手实践。**

期待在 Plugin Marketplace 看到你的作品！

---

## 关于本书

**第一版（数字版）, 2026 年 3 月**

**作者**：[toohamster](https://github.com/toohamster)

![Author Photo](https://avatars.githubusercontent.com/u/16458414?s=100&u=7fd7d3827bd4824339e1ee5bf098fb78725728ec&v=4)

**授权**：电子版 MIT License，纸质版/商业版 © All Rights Reserved
**源码**：[github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

详细说明请参阅 [LICENSE](../../LICENSE) 和 [关于作者](../authors.md)

---

*全书完*

---
