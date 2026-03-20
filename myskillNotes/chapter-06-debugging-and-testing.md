# 第 6 章：调试与测试

## 6.1 Shell 脚本调试基础

### set 命令选项
```bash
#!/bin/bash
set -euo pipefail  # 推荐的生产环境设置

# 调试时使用
set -x  # 打印执行的每一行
set -v  # 打印读取的每一行
set -xv # 同时启用两者
```

| 选项 | 说明 |
|------|------|
| `-e` | 命令失败时立即退出 |
| `-u` | 使用未定义变量时报错 |
| `-o pipefail` | 管道中任一命令失败则整体失败 |
| `-x` | 打印每条执行命令（调试用） |
| `-v` | 打印每行输入（调试用） |

### 使用场景
```bash
# 开发阶段：详细调试
#!/bin/bash
set -xv

# 生产阶段：严格错误处理
#!/bin/bash
set -euo pipefail

# 临时调试：在脚本中间插入
set -x
# 需要调试的代码段
set +x
```

---

## 6.2 日志级别设计

### 四级日志系统
```bash
# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志函数
info()  { echo -e "${GREEN}[prefix]${NC} $*"; }
warn()  { echo -e "${YELLOW}[prefix]${NC} $*" >&2; }
error() { echo -e "${RED}[prefix]${NC} $*" >&2; }
step()  { echo -e "${CYAN}[prefix]${NC} $*"; }
```

### 输出目标
- `info`：正常输出到 stdout
- `warn`：警告输出到 stderr
- `error`：错误输出到 stderr
- `step`：重要步骤，高亮显示

### 使用示例
```bash
info "配置文件已创建：$CONFIG_FILE"
warn "配置文件已存在：$CONFIG_FILE"
error "配置文件不存在：$CONFIG_FILE"
step "开始初始化配置..."
```

---

## 6.3 _verbose_ 模式实现

### 添加详细输出开关
```bash
# 解析命令行参数
VERBOSE=false
if [[ "${1:-}" == "-v" ]] || [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

# 定义 debug 函数
debug() {
    $VERBOSE && echo -e "[DEBUG] $*" >&2
}

# 使用示例
debug "配置文件路径：$CONFIG_FILE"
debug "排除列表：${EXCLUDES[*]}"
```

### 在 sftp-push.sh 中的应用
```bash
# 解析参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose) VERBOSE=true; shift ;;
        # ...
    esac
done

# 详细输出
$VERBOSE && info "  + $rel_path"

# 或者使用 debug 函数
debug "正在处理文件：$rel_path"
```

---

## 6.4 临时文件管理

### mktemp 创建临时文件
```bash
# 创建临时文件
tmp_file=$(mktemp)
changed_list=$(mktemp)
batch_file=$(mktemp)

# 使用临时文件
grep "pattern" input.txt > "$tmp_file"
process_file "$tmp_file"
```

### trap 清理临时文件
```bash
# 定义清理函数
cleanup() {
    rm -f "$tmp_file" "$changed_list" "$batch_file"
}

# 注册退出时清理
trap cleanup EXIT

# 或者内联清理
rm -f "$tmp_file"
```

### 最佳实践
```bash
# 1. 使用后立即删除
process_file "$tmp_file"
rm -f "$tmp_file"

# 2. 使用 trap 确保清理
tmp_files=()
cleanup() {
    for f in "${tmp_files[@]}"; do
        rm -f "$f"
    done
}
trap cleanup EXIT

# 创建临时文件时记录
tmp1=$(mktemp); tmp_files+=("$tmp1")
tmp2=$(mktemp); tmp_files+=("$tmp2")
```

---

## 6.5 错误处理模式

### 参数验证
```bash
# 检查必填参数
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

### 命令存在检查
```bash
if ! command -v sftp &>/dev/null; then
    error "未找到 sftp 命令，请先安装"
    exit 1
fi

if ! command -v git &>/dev/null; then
    error "未找到 git 命令"
    exit 1
fi
```

### 文件存在检查
```bash
# 配置文件
if [ ! -f "$CONFIG_FILE" ]; then
    error "配置文件不存在：$CONFIG_FILE"
    error "请先运行 sftp-init.sh 初始化配置"
    exit 1
fi

# 私钥文件
if [ ! -f "$PRIVATE_KEY" ]; then
    error "私钥文件不存在：$PRIVATE_KEY"
    exit 1
fi

# 目录存在检查
if [ ! -d "$LOCAL_PATH" ]; then
    error "目录不存在：$LOCAL_PATH"
    exit 1
fi
```

### 命令执行结果检查
```bash
# 检查命令执行是否成功
if ! sftp "$SFTP_TARGET" < "$batch_file"; then
    error "SFTP 上传失败"
    exit 1
fi

# 捕获退出码
sftp "$SFTP_TARGET" < "$batch_file"
rc=$?
if [ $rc -ne 0 ]; then
    error "SFTP 上传失败 (退出码：$rc)"
    exit $rc
fi
```

---

## 6.6 测试方法

### 单元测试思路
```bash
# 测试 JSON 解析函数
test_json_get() {
    local test_file=$(mktemp)
    echo '{"host": "example.com", "port": 22}' > "$test_file"

    local result
    result=$(json_get "$test_file" "host")
    [ "$result" = "example.com" ] || {
        echo "FAIL: json_get host"
        return 1
    }

    rm -f "$test_file"
    echo "PASS: json_get"
}

# 运行测试
test_json_get
```

### 集成测试
```bash
# 测试完整流程
test_full_workflow() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"

    # 1. 初始化配置
    bash scripts/sftp-init.sh \
        --host test.example.com \
        --port 22 \
        --username testuser \
        --remote-path /tmp/test

    # 检查配置文件是否创建
    [ -f ".claude/sftp-cc/sftp-config.json" ] || {
        echo "FAIL: config file not created"
        return 1
    }

    # 2. 测试私钥绑定（需要放置私钥）
    # ...

    # 清理
    rm -rf "$test_dir"
    echo "PASS: full workflow"
}
```

### Dry-run 模式
```bash
# 预览模式：显示操作但不执行
DRY_RUN=false
if [[ "${1:-}" == "-n" ]] || [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# 使用示例
if $DRY_RUN; then
    info "[预览模式] 将上传 $count 个文件"
    cat "$batch_file"
    return 0
fi

# 实际执行
sftp "$SFTP_TARGET" < "$batch_file"
```

---

## 6.7 调试实战案例

### 案例 1：JSON 解析失败
**问题**：`json_get` 返回空值

**调试步骤**：
```bash
# 1. 检查文件内容
cat "$CONFIG_FILE"

# 2. 检查 grep 结果
grep '"host"' "$CONFIG_FILE"

# 3. 检查 sed 处理
grep '"host"' "$CONFIG_FILE" | sed 's/.*: *"\([^"]*\)".*/\1/'

# 4. 添加调试输出
json_get() {
    local file="$1" key="$2" default="${3:-}"
    debug "json_get: file=$file key=$key"
    local val
    val=$(grep "\"$key\"" "$file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    debug "json_get result: $val"
    # ...
}
```

### 案例 2：SFTP 连接失败
**问题**：SFTP 上传时连接被拒绝

**调试步骤**：
```bash
# 1. 检查连接参数
debug "SFTP 目标：$SFTP_TARGET"
debug "SFTP 选项：$SFTP_OPTS"

# 2. 手动测试连接
sftp -v -P 22 user@host

# 3. 检查私钥权限
ls -la "$PRIVATE_KEY"
stat -c "%a" "$PRIVATE_KEY"

# 4. 在脚本中添加详细输出
set -x
sftp $SFTP_OPTS -b "$batch_file" "$SFTP_TARGET"
set +x
```

### 案例 3：增量检测异常
**问题**：始终检测不到文件变更

**调试步骤**：
```bash
# 1. 检查 .last-push 文件
cat .claude/sftp-cc/.last-push

# 2. 检查 git 状态
git status
git diff --name-only HEAD

# 3. 在 collect_changed_files 中添加调试
collect_changed_files() {
    debug "=== 开始收集变更文件 ==="
    debug "LAST_PUSH_FILE: $LAST_PUSH_FILE"
    debug "last_hash: $last_hash"

    # 输出各类变更
    debug "已提交变更:"
    git diff --name-only "$last_hash" HEAD >&2

    debug "暂存区变更:"
    git diff --cached --name-only >&2

    # ...
}
```

---

## 6.8 验证工具

### Plugin 验证
```bash
# 验证 Plugin 结构
claude plugin validate .

# 查看 Plugin 信息
claude plugin info .
```

### 手动安装测试
```bash
# 测试安装到临时目录
bash install.sh /tmp/test-project

# 检查目录结构
tree /tmp/test-project/.claude/

# 清理测试环境
rm -rf /tmp/test-project
```

### 脚本语法检查
```bash
# 使用 shellcheck 检查语法
shellcheck scripts/*.sh

# 使用 bash -n 检查语法（不执行）
bash -n scripts/sftp-push.sh

# 检查脚本可执行性
file scripts/*.sh
head -1 scripts/*.sh  # 检查 shebang
```

---

## 6.9 常见问题排查表

| 问题 | 可能原因 | 排查方法 |
|------|----------|----------|
| Skill 不触发 | 触发词未定义 | 检查 SKILL.md 触发词列表 |
| 变量未解析 | ${CLAUDE_PLUGIN_ROOT} 为空 | 确认在 Claude 上下文中执行 |
| JSON 解析失败 | 格式不匹配 | `cat` 查看实际内容 |
| SFTP 连接失败 | 权限/网络问题 | `sftp -v` 详细调试 |
| 私钥权限错误 | 非 600 权限 | `ls -la` 检查 |
| 增量检测失效 | .last-push 损坏 | 删除后重新全量上传 |

---

## 本章小结

- 使用 `set -euo pipefail` 严格错误处理
- 四级日志系统：info/warn/error/step
- verbose 模式提供详细输出
- 临时文件使用 `mktemp` + `trap` 管理
- Dry-run 模式预览操作
- 完善的错误检查和参数验证
- 使用 `shellcheck` 等工具检查语法

## 下一章

第 7 章将介绍发布与分发流程。
