# 第 8 章：进阶与最佳实践

## 8.1 性能优化

### 减少子进程调用
```bash
# 不推荐：每次调用都创建子进程
for file in "${files[@]}"; do
    result=$(grep "pattern" "$file")
    count=$(wc -l < "$file")
done

# 推荐：批量处理
grep "pattern" "${files[@]}" | wc -l
```

### 避免不必要的命令
```bash
# 不推荐：冗余检查
if [ -f "$file" ]; then
    if [ -r "$file" ]; then
        if [ -s "$file" ]; then
            cat "$file"
        fi
    fi
fi

# 推荐：合并检查
if [ -r "$file" ] && [ -s "$file" ]; then
    cat "$file"
fi
```

### 使用数组而非字符串拼接
```bash
# 不推荐：字符串拼接
args=""
for f in "${files[@]}"; do
    args="$args \"$f\""
done
eval "command $args"  # 危险！

# 推荐：使用数组
args=()
for f in "${files[@]}"; do
    args+=("$f")
done
command "${args[@]}"  # 安全
```

---

## 8.2 安全最佳实践

### 避免命令注入
```bash
# 危险：直接拼接用户输入
user_input="$1"
eval "echo $user_input"  # 危险！

# 安全：使用变量
user_input="$1"
echo "$user_input"
```

### 安全处理文件路径
```bash
# 危险：未引用变量
cat $file  # 如果 $file 包含空格会出错

# 安全：始终引用
cat "$file"

# 更安全：验证路径
if [[ "$file" == /* ]]; then
    # 绝对路径，可能在敏感目录
    if [[ "$file" != /tmp/* ]] && [[ "$file" != "$PROJECT_ROOT"/* ]]; then
        error "不允许访问该路径"
        exit 1
    fi
fi
```

### 权限管理
```bash
# 私钥权限必须为 600
chmod 600 "$PRIVATE_KEY"

# 配置文件权限建议为 644
chmod 644 "$CONFIG_FILE"

# 脚本权限建议为 755
chmod 755 "$SCRIPT_FILE"
```

---

## 8.3 代码组织

### 函数命名规范
```bash
# 动词 + 名词：描述函数行为
init_lang()      # 初始化语言
load_messages()  # 加载消息
push_files()     # 推送文件
collect_changed_files()  # 收集变更文件

# 布尔函数：使用 is/has/check 前缀
is_excluded()    # 是否被排除
has_permission() # 是否有权限
check_config()   # 检查配置
```

### 变量作用域
```bash
# 局部变量：使用 local
process_file() {
    local file="$1"
    local content
    content=$(cat "$file")
    # ...
}

# 全局变量：全大写
readonly SCRIPT_NAME="sftp-push"
readonly VERSION="1.0.0"

# 配置变量：小写
host=""
port=22
username=""
```

### 脚本结构模板
```bash
#!/bin/bash
# 脚本名称：功能说明
# Usage: 使用说明

set -euo pipefail

# ============================================================================
# 全局变量
# ============================================================================
readonly VERSION="1.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ============================================================================
# 工具函数
# ============================================================================
info()  { echo -e "${GREEN}[prefix]${NC} $*"; }
warn()  { echo -e "${YELLOW}[prefix]${NC} $*" >&2; }
error() { echo -e "${RED}[prefix]${NC} $*" >&2; }

# ============================================================================
# 核心函数
# ============================================================================
json_get() { ... }
process_file() { ... }
main_logic() { ... }

# ============================================================================
# 参数解析
# ============================================================================
parse_args() { ... }

# ============================================================================
# 入口点
# ============================================================================
main() {
    parse_args "$@"
    # ...
}

main "$@"
```

---

## 8.4 错误处理进阶

### 使用 trap 捕获错误
```bash
# 错误处理函数
error_handler() {
    local line_no=$1
    error "脚本执行错误，行号：$line_no"
    error "退出码：$?"
    # 清理资源
    rm -f "$tmp_file"
}

# 注册错误处理器
trap 'error_handler ${LINENO}' ERR

# 注册退出处理器
trap 'cleanup' EXIT
```

### 优雅的错误恢复
```bash
# 尝试多种方法
copy_file() {
    local src="$1" dst="$2"

    # 尝试 cp
    if cp "$src" "$dst" 2>/dev/null; then
        return 0
    fi

    # 回退到 cat
    if cat "$src" > "$dst" 2>/dev/null; then
        return 0
    fi

    error "无法复制文件：$src -> $dst"
    return 1
}
```

### 超时处理
```bash
# 设置命令超时
timeout_command() {
    local timeout="$1"
    shift

    if command -v timeout &>/dev/null; then
        timeout "$timeout" "$@"
    else
        # 没有 timeout 命令时使用后台执行
        "$@" &
        local pid=$!
        sleep "$timeout"
        if kill -0 "$pid" 2>/dev/null; then
            kill -9 "$pid"
            return 124  # timeout 退出码
        fi
        wait "$pid"
    fi
}

# 使用示例
if ! timeout_command 30 sftp "$SFTP_TARGET" < "$batch_file"; then
    error "SFTP 操作超时（30 秒）"
    exit 1
fi
```

---

## 8.5 可维护性提升

### 注释规范
```bash
# ========================================
# SFTP 连接配置
# ========================================
# 从配置文件读取 SFTP 连接参数
HOST=$(json_get "$CONFIG_FILE" "host")
PORT=$(json_get_num "$CONFIG_FILE" "port" "22")
USERNAME=$(json_get "$CONFIG_FILE" "username")

# 构建 SFTP 选项
# -P: 端口
# -i: 私钥文件
# -o: SSH 选项
SFTP_OPTS="-P $PORT"
if [ -n "$PRIVATE_KEY" ] && [ -f "$PRIVATE_KEY" ]; then
    SFTP_OPTS="$SFTP_OPTS -i $PRIVATE_KEY"
fi
```

### 版本兼容性
```bash
# 检查 bash 版本
if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
    error "需要 Bash 4.0 或更高版本"
    exit 1
fi

# 检查必需的命令
check_dependencies() {
    local deps=("git" "sftp" "grep" "sed")
    for cmd in "${deps[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            error "缺少必需的命令：$cmd"
            exit 1
        fi
    done
}
```

### 配置与代码分离
```bash
# 默认配置
readonly DEFAULT_PORT=22
readonly DEFAULT_LANGUAGE="en"
readonly DEFAULT_EXCLUDES=(".git" ".claude" "node_modules")

# 从配置文件覆盖
PORT=$(json_get_num "$CONFIG_FILE" "port" "$DEFAULT_PORT")
LANGUAGE=$(json_get "$CONFIG_FILE" "language" "$DEFAULT_LANGUAGE")
```

---

## 8.6 用户反馈处理

### 收集用户反馈
- GitHub Issues：功能请求和 Bug 报告
- 使用统计（可选）：匿名收集使用情况
- 文档评论：README 中的讨论

### 常见反馈分类
| 类型 | 处理方式 |
|------|----------|
| Bug 报告 | 复现 → 修复 → 测试 → 发布 Patch |
| 功能请求 | 评估需求 → 设计 → 实现 → 发布 Minor |
| 文档问题 | 立即修正 → 发布 Patch |
| 性能问题 | 性能分析 → 优化 → 基准测试 |

### 版本发布节奏
- **Patch 版本**：随时发布（Bug 修复）
- **Minor 版本**：按需发布（新功能累积）
- **Major 版本**：谨慎发布（破坏性变更）

---

## 8.7 故障排查清单

### Skill 不触发
- [ ] 检查 SKILL.md 触发词定义
- [ ] 重新加载 Plugin：`/plugin marketplace remove sftp-cc` 然后重新 add
- [ ] 检查 marketplace.json 配置

### 变量未解析
- [ ] 确认 ${CLAUDE_PLUGIN_ROOT} 在 Skill 上下文中使用
- [ ] 直接在 shell 中执行时使用绝对路径

### JSON 解析失败
- [ ] 检查配置文件格式
- [ ] 使用 `cat` 查看实际内容
- [ ] 检查 grep/sed 模式是否匹配

### SFTP 连接失败
- [ ] 检查网络连接
- [ ] 验证服务器地址和端口
- [ ] 检查私钥权限（600）
- [ ] 使用 `sftp -v` 详细调试

### 增量检测失效
- [ ] 检查 .last-push 文件
- [ ] 验证 git 仓库状态
- [ ] 删除 .last-push 强制全量上传

---

## 8.8 扩展开发方向

### 新增功能建议
1. **多服务器支持**：同时部署到多个环境
2. **下载功能**：从服务器拉取文件
3. **文件监听**：自动检测并上传变更
4. **回滚支持**：记录历史版本并支持回滚
5. **差异预览**：上传前显示文件差异

### 集成扩展
1. **CI/CD 集成**：GitHub Actions、GitLab CI
2. **Webhook 通知**：部署完成后通知
3. **日志收集**：集中管理部署日志
4. **监控告警**：部署失败时告警

### 性能优化方向
1. **并行上传**：同时上传多个文件
2. **断点续传**：大文件分块上传
3. **增量压缩**：减少传输数据量
4. **缓存优化**：复用已有连接

---

## 8.9 学习资源

### Shell 编程
- 《Advanced Bash-Scripting Guide》
- 《Bash Cookbook》
- GNU Bash 官方文档

### Claude Code 开发
- Claude Code 官方文档
- Plugin Marketplace 示例
- 社区 Skill 分享

### 相关工具
- `shellcheck`：Shell 脚本静态分析
- `shfmt`：Shell 代码格式化
- `git`：版本控制

---

## 本书总结

通过开发 sftp-cc 这个完整的 Claude Code Skill，你已经掌握了：

1. **理解 Plugin 架构**：SKILL.md、marketplace.json、${CLAUDE_PLUGIN_ROOT}
2. **编写 Skill 定义**：触发词设计、YAML frontmatter、执行指引
3. **Shell 脚本开发**：JSON 解析、错误处理、日志系统
4. **多语言支持**：i18n 方案、语言加载、消息管理
5. **调试与测试**：set 选项、verbose 模式、dry-run
6. **发布与分发**：版本管理、GitHub API、Marketplace

### 下一步
- 基于本项目模板开发你自己的 Skill
- 发布到 Plugin Marketplace 与社区分享
- 持续优化和迭代你的 Skill

祝你开发愉快！

---

## 附录：完整项目结构参考

```
sftp-cc/
├── .claude-plugin/
│   └── marketplace.json            # Plugin 配置
├── skills/
│   └── sftp-cc/
│       └── SKILL.md                # Skill 定义（Plugin 安装）
├── scripts/
│   ├── sftp-push.sh                # 核心上传脚本
│   ├── sftp-init.sh                # 初始化配置
│   ├── sftp-keybind.sh             # 私钥绑定
│   ├── sftp-copy-id.sh             # 公钥部署
│   └── i18n.sh                     # 多语言支持
├── templates/
│   └── sftp-config.example.json    # 配置模板
├── skill.md                        # Skill 定义（手动安装）
├── install.sh                      # 手动安装脚本
├── README.md                       # 英文文档
├── README_CN.md                    # 中文文档
├── README_JP.md                    # 日文文档
├── CLAUDE.md                       # 开发指南
└── LICENSE                         # 开源协议
```
