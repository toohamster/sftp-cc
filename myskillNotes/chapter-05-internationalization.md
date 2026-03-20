# 第 5 章：多语言支持 (i18n)

## 5.1 为什么要做多语言

### 用户体验优先
当用户使用 Skill 时，看到的输出应该是他熟悉的语言：
- 英语用户：`"Upload complete!"`
- 中文用户：`"上传完成！"`
- 日文用户：`"アップロード完了！"`

### 国际化原则
1. **用户语言优先**：根据用户配置自动切换
2. **零外部依赖**：不用 gettext，不用 Python
3. **简单可维护**：纯 Shell 实现，易于扩展

---

## 5.2 方案设计：变量式多语言

### 为什么不选 gettext
| 对比项 | gettext | 变量式方案 |
|--------|---------|-----------|
| 外部依赖 | 需要安装 | 无 |
| 学习成本 | 需要理解 .po/.mo | 普通变量 |
| Shell 兼容性 | 复杂 | 原生支持 |
| 代码侵入性 | 需要包装函数 | 直接替换变量 |

### 变量式方案核心
```bash
# 定义阶段（按语言加载）
MSG_UPLOAD_COMPLETE="上传完成！"

# 使用阶段（直接引用）
info "$MSG_UPLOAD_COMPLETE"

# 带参数的消息（使用 printf）
printf "$MSG_UPLOADING_FILES" "10" "server:/var/www"
```

---

## 5.3 i18n.sh 工具库实现

### 完整代码
```bash
#!/bin/bash
# i18n.sh — Internationalization support for sftp-cc
# Multi-language support: English (en), Chinese (zh), and Japanese (ja)
# Default language: English

# Initialize language from config
# Usage: init_lang <config_file>
init_lang() {
    local config_file="$1"
    local lang=""

    if [ -f "$config_file" ]; then
        lang=$(grep '"language"' "$config_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    fi

    # Default to English if not set or invalid
    if [ -z "$lang" ] || [ "$lang" = "null" ]; then
        lang="en"
    fi

    # Load language messages
    load_messages "$lang"
}

# Load messages for specified language
load_messages() {
    local lang="$1"

    case "$lang" in
        zh|zh_CN|zh_TW)
            # Chinese messages
            MSG_CONFIG_DIR_CREATED="已创建配置目录：%s"
            MSG_UPLOAD_COMPLETE="上传完成！"
            MSG_CHECKING_KEYBIND="检查私钥绑定..."
            # ... 更多消息
            ;;
        ja|ja_JP)
            # Japanese messages
            MSG_CONFIG_DIR_CREATED="設定ディレクトリを作成しました：%s"
            MSG_UPLOAD_COMPLETE="アップロード完了！"
            MSG_CHECKING_KEYBIND="秘密鍵のバインドを確認中..."
            # ... 更多消息
            ;;
        *)
            # English messages (default)
            MSG_CONFIG_DIR_CREATED="Configuration directory created: %s"
            MSG_UPLOAD_COMPLETE="Upload complete!"
            MSG_CHECKING_KEYBIND="Checking private key binding..."
            # ... 更多消息
            ;;
    esac
}

# Helper function to print formatted message
# Usage: printf_msg "$MSG_FORMAT" "arg1" "arg2" ...
printf_msg() {
    local format="$1"
    shift
    printf "%s\n" "$(printf "$format" "$@")"
}
```

### 核心函数说明

#### init_lang()
- 从配置文件读取 `language` 字段
- 支持的语言代码：`en`, `zh`, `zh_CN`, `zh_TW`, `ja`, `ja_JP`
- 无效或缺省时回退到英语

#### load_messages()
- 使用 `case` 语句按语言加载消息
- 所有消息以 `MSG_` 前缀命名
- 支持 `printf` 格式化字符串（`%s`, `%d`）

#### printf_msg()
- 封装 `printf`，简化调用
- 自动添加换行

---

## 5.4 在脚本中使用 i18n

### sftp-push.sh 中的使用示例

#### 1. 引入 i18n 库
```bash
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/i18n.sh"
init_lang "$CONFIG_FILE"
```

#### 2. 使用简单消息
```bash
# 之前（硬编码英文）
info "Upload complete!"

# 之后（多语言）
info "$MSG_UPLOAD_COMPLETE"
```

#### 3. 使用格式化消息
```bash
# 之前
info "Uploading $count files to $server:$path ..."

# 之后
info "$(printf "$MSG_UPLOADING_FILES" "$count" "$server:$path")"
```

#### 4. 错误消息多语言化
```bash
if [ ! -f "$CONFIG_FILE" ]; then
    error "$(printf "$MSG_CONFIG_MISSING" "$CONFIG_FILE")"
    error "$MSG_RUN_INIT_FIRST"
    exit 1
fi
```

### 完整消息列表示例
```bash
# 初始化相关
MSG_CONFIG_DIR_CREATED="已创建配置目录：%s"
MSG_CONFIG_FILE_EXISTS="配置文件已存在：%s"
MSG_CONFIG_FILE_CREATED="已创建配置文件：%s"
MSG_INIT_COMPLETE="初始化完成！"

# 私钥绑定相关
MSG_KEYBIND_COMPLETE="私钥已绑定且权限正确：%s"
MSG_KEY_PERMISSIONS_FIXED="已修正私钥权限：%s -> 600"
MSG_NO_KEY_FOUND="未在 %s 下找到私钥文件"

# 上传相关
MSG_CHECKING_CHANGES="检测文件变更..."
MSG_FOUND_FILES_INCREMENTAL="检测到 %s 个变更文件（增量）"
MSG_UPLOADING_FILES="正在上传 %s 个文件到 %s ..."
MSG_UPLOAD_COMPLETE="上传完成！"
```

---

## 5.5 语言配置文件

### sftp-config.json 中的 language 字段
```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "language": "zh",
  "excludes": [".git", "node_modules"]
}
```

### 支持的语言代码
| 代码 | 语言 | 说明 |
|------|------|------|
| `en` | English | 默认语言 |
| `zh`, `zh_CN`, `zh_TW` | 中文 | 简体/繁体统一使用中文消息 |
| `ja`, `ja_JP` | 日本語 | 日文消息 |

### 如何扩展新语言
1. 在 `load_messages()` 中添加新的 `case` 分支
2. 定义所有 `MSG_XXX` 变量
3. 在配置文件中设置对应 language 值

```bash
ko|ko_KR)
    # Korean messages
    MSG_UPLOAD_COMPLETE="업로드 완료!"
    # ...
    ;;
```

---

## 5.6 消息命名规范

### 命名格式
```
MSG_<功能>_<动作>_<对象>
```

### 示例
| 消息 | 命名 |
|------|------|
| "配置文件不存在" | `MSG_CONFIG_MISSING` |
| "上传完成" | `MSG_UPLOAD_COMPLETE` |
| "正在检查变更" | `MSG_CHECKING_CHANGES` |
| "未知选项" | `MSG_UNKNOWN_OPTION` |

### 最佳实践
1. **全大写 + 下划线**：与 shell 环境变量风格一致
2. **语义清晰**：看到名字就知道用途
3. **避免缩写**：除非是通用缩写（如 ID, URL）

---

## 5.7 多语言触发词设计

### SKILL.md 中的触发词分组
```markdown
**SFTP 上传/部署类**:
- "sync code to server", "upload to server", "deploy code"
- "同步代码到服务器"、"上传到服务器"、"部署代码"
- "サーバーに同期する"、"デプロイする"

**私钥绑定类**:
- "bind sftp private key", "bind ssh key"
- "绑定 SFTP 私钥"、"绑定私钥"
- "秘密鍵をバインドする"、"SSH 鍵をバインドする"
```

### 触发词设计原则
1. **自然语言**：用户会说的话
2. **多语言覆盖**：英文、中文、日文
3. **避免歧义**：如 "push" 与 git push 冲突

### 触发与输出的关系
- **触发词**：用户输入的语言（决定调用哪个脚本）
- **输出语言**：脚本根据配置文件的 `language` 设置

---

## 5.8 调试技巧

### 验证语言加载
```bash
# 在脚本中添加调试输出
VERBOSE=true
if $VERBOSE; then
    echo "[DEBUG] Language: $lang" >&2
    echo "[DEBUG] MSG_UPLOAD_COMPLETE: $MSG_UPLOAD_COMPLETE" >&2
fi
```

### 测试不同语言
```bash
# 临时修改配置文件
cp sftp-config.json sftp-config.json.bak
echo '{"language": "zh"}' > sftp-config.json
bash scripts/sftp-push.sh -n
mv sftp-config.json.bak sftp-config.json
```

### 检查消息完整性
```bash
# 提取所有使用的 MSG_变量
grep -o 'MSG_[A-Z_]*' scripts/*.sh | sort -u

# 检查 i18n.sh 中是否定义
grep -c 'MSG_[A-Z_]*=' scripts/i18n.sh
```

---

## 5.9 常见问题

### Q: 为什么不使用 .po/.mo 文件？
A: gettext 需要外部依赖，增加学习和安装成本。变量式方案纯 Shell 实现，零依赖。

### Q: 如何保证所有语言都有完整的消息？
A: 建立消息清单，在添加新消息时同步翻译。暂时缺失的消息使用英语兜底。

### Q: 中文简体繁体如何处理？
A: 当前 `zh`, `zh_CN`, `zh_TW` 统一使用简体中文字符串。需要时可拆分为两个分支。

### Q: 格式化字符串如何转义？
A: 使用 `%s` 作为占位符，通过 `printf` 函数注入参数：
```bash
printf "$MSG_FORMAT" "$arg1" "$arg2"
```

---

## 本章小结

- 多语言提升用户体验
- 变量式方案零外部依赖
- `init_lang()` 从配置读取语言
- `load_messages()` 按语言加载消息
- 使用 `$MSG_XXX` 变量引用消息
- 支持英文、中文、日文三语言

## 下一章

第 6 章将介绍调试与测试技巧。
