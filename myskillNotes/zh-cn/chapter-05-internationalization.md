# 第 5 章：多语言支持 (i18n)

> "好的国际化不是翻译，而是本地化。" — 国际化最佳实践

本章你将学到：
- 为什么要做多语言支持（用户体验、市场覆盖）
- 变量式多语言方案的设计原理
- i18n.sh 工具库的完整实现
- 如何在脚本中使用多语言消息
- 消息命名规范和管理技巧
- 多语言触发词设计
- 如何扩展新语言
- 多语言测试和验证方法

---

## 5.1 为什么要做多语言

### 5.1.1 用户体验优先

想象以下场景：

```
场景 1：英语用户
$ bash sftp-push.sh
[push] Upload complete! 15 files synced to server.
→ ✅ 理解无障碍

场景 2：中文用户（不懂英语）
$ bash sftp-push.sh
[push] Upload complete! 15 files synced to server.
→ ❌ 看不懂，不知道成功与否

场景 3：中文用户（配置了中文）
$ bash sftp-push.sh
[push] 上传完成！已同步 15 个文件到服务器。
→ ✅ 一目了然
```

**多语言的价值**：
- 降低使用门槛
- 减少用户困惑
- 提升专业形象
- 扩大用户群体

### 5.1.2 目标用户分析

#### sftp-cc 的用户语言分布

根据项目 GitHub 访问数据（假设）：

| 地区 | 语言 | 占比 |
|------|------|------|
| 北美/欧洲 | English | 45% |
| 中国大陆/港澳台 | 中文 | 35% |
| 日本 | 日本語 | 15% |
| 其他地区 | 其他 | 5% |

**决策**：优先支持 English、中文、日本語三种语言。

### 5.1.3 国际化原则

```
原则 1：用户语言优先
  用户配置什么语言，输出就用什么语言

原则 2：零外部依赖
  不使用 gettext、不依赖 Python
  纯 Shell 实现，开箱即用

原则 3：简单可维护
  添加新语言只需修改一处
  消息集中管理，易于翻译
```

---

## 5.2 方案设计：变量式多语言

### 5.2.1 方案对比

#### 方案 1：gettext（传统方案）

```bash
# 需要 .po 文件
msgid "Upload complete"
msgstr "上传完成"

# 需要编译 .mo 文件
msgfmt -o messages.mo messages.po

# 脚本中使用
eval_gettext "Upload complete"
```

**问题**：
- ❌ 需要安装 gettext 工具
- ❌ 需要理解 .po/.mo 格式
- ❌ 编译步骤增加复杂度
- ❌ 不是所有系统都有 gettext

#### 方案 2：变量式方案（本项目采用）

```bash
# 直接定义变量
MSG_UPLOAD_COMPLETE="上传完成"

# 直接使用
echo "$MSG_UPLOAD_COMPLETE"
```

**优势**：
- ✅ 零外部依赖
- ✅ 无需学习新工具
- ✅ 纯 Shell 原生支持
- ✅ 即改即用

### 5.2.2 变量式方案核心设计

```
┌─────────────────────────────────────────────────────────┐
│              变量式多语言架构                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  1. 语言初始化                                          │
│     init_lang "$CONFIG_FILE"                           │
│     ↓                                                   │
│  2. 读取配置中的 language 字段                           │
│     lang=$(grep '"language"' "$CONFIG_FILE" ...)       │
│     ↓                                                   │
│  3. 根据语言加载消息                                    │
│     load_messages "$lang"                              │
│     ↓                                                   │
│  4. 设置 MSG_XXX 变量                                   │
│     MSG_UPLOAD_COMPLETE="上传完成"                      │
│     ↓                                                   │
│  5. 脚本中使用变量                                     │
│     info "$MSG_UPLOAD_COMPLETE"                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### 5.2.3 消息分类设计

将消息按功能分类，便于管理和查找：

```bash
# 初始化相关 (CONFIG_*)
MSG_CONFIG_DIR_CREATED
MSG_CONFIG_FILE_EXISTS
MSG_CONFIG_FILE_CREATED
MSG_INIT_COMPLETE

# 私钥绑定相关 (KEY_*)
MSG_KEYBIND_COMPLETE
MSG_KEY_PERMISSIONS_FIXED
MSG_NO_KEY_FOUND

# 上传相关 (UPLOAD_*)
MSG_CHECKING_CHANGES
MSG_FOUND_FILES_INCREMENTAL
MSG_UPLOADING_FILES
MSG_UPLOAD_COMPLETE

# 错误相关 (ERROR_*)
MSG_CONFIG_MISSING
MSG_CONFIG_INCOMPLETE
MSG_UPLOAD_FAILED
```

---

## 5.3 i18n.sh 工具库完整实现

### 5.3.1 文件结构

```
scripts/
└── i18n.sh
    ├── init_lang()       # 语言初始化
    ├── load_messages()   # 加载消息
    ├── printf_msg()      # 格式化输出
    └── MSG_XXX 变量定义   # 所有语言的消息
```

### 5.3.2 完整代码解析

```bash
#!/bin/bash
# i18n.sh — Internationalization support for sftp-cc
# Multi-language support: English (en), Chinese (zh), and Japanese (ja)
# Default language: English
#
# Usage:
#   source "$SCRIPT_DIR/i18n.sh"
#   init_lang "$CONFIG_FILE"
#   echo "$MSG_UPLOAD_COMPLETE"
```

#### init_lang() 函数

```bash
init_lang() {
    local config_file="$1"
    local lang=""

    # 从配置文件读取 language 字段
    if [ -f "$config_file" ]; then
        lang=$(grep '"language"' "$config_file" 2>/dev/null | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
    fi

    # 默认使用英语（如果未设置或无效）
    if [ -z "$lang" ] || [ "$lang" = "null" ]; then
        lang="en"
    fi

    # 加载对应语言的消息
    load_messages "$lang"
}
```

**工作流程**：

```
输入：config_file = "sftp-config.json"
       文件内容：{"language": "zh", ...}

步骤 1: grep '"language"' sftp-config.json
       结果："language": "zh",

步骤 2: sed 's/.*: *"\([^"]*\)".*/\1/'
       结果：zh

步骤 3: lang="zh"

步骤 4: load_messages "zh"
       → 加载中文消息
```

#### load_messages() 函数

```bash
load_messages() {
    local lang="$1"

    case "$lang" in
        zh|zh_CN|zh_TW)
            # 中文消息
            MSG_CONFIG_DIR_CREATED="已创建配置目录：%s"
            MSG_CONFIG_FILE_EXISTS="配置文件已存在：%s"
            MSG_CONFIG_FILE_CREATED="已创建配置文件：%s"
            MSG_INIT_COMPLETE="初始化完成！"
            # ... 更多消息
            ;;

        ja|ja_JP)
            # 日文消息
            MSG_CONFIG_DIR_CREATED="設定ディレクトリを作成しました：%s"
            MSG_CONFIG_FILE_EXISTS="設定ファイルは既に存在します：%s"
            MSG_CONFIG_FILE_CREATED="設定ファイルを作成しました：%s"
            MSG_INIT_COMPLETE="初期化が完了しました！"
            # ... 更多消息
            ;;

        *)
            # 英语消息（默认）
            MSG_CONFIG_DIR_CREATED="Configuration directory created: %s"
            MSG_CONFIG_FILE_EXISTS="Config file already exists: %s"
            MSG_CONFIG_FILE_CREATED="Configuration file created: %s"
            MSG_INIT_COMPLETE="Initialization complete!"
            ;;
    esac
}
```

**设计要点**：

| 设计点 | 说明 |
|--------|------|
| `case` 语句 | 清晰的语言分支 |
| 语言别名 | `zh|zh_CN|zh_TW` 统一使用中文 |
| 默认分支 | `*` 兜底，防止未知语言 |
| 变量命名 | `MSG_` 前缀，避免冲突 |

#### printf_msg() 辅助函数

```bash
printf_msg() {
    local format="$1"
    shift
    printf "%s\n" "$(printf "$format" "$@")"
}
```

**使用示例**：

```bash
# 定义格式化消息
MSG_UPLOADING_FILES="正在上传 %s 个文件到 %s ..."

# 使用 printf_msg
printf_msg "$MSG_UPLOADING_FILES" "15" "server:/var/www"

# 输出
正在上传 15 个文件到 server:/var/www ...
```

### 5.3.3 完整消息列表

以下是 sftp-cc 中使用的完整消息列表（部分）：

```bash
# ============================================================================
# 初始化相关 (sftp-init.sh)
# ============================================================================
MSG_CONFIG_DIR_CREATED="已创建配置目录：%s"
MSG_CONFIG_FILE_EXISTS="配置文件已存在：%s"
MSG_CONFIG_FILE_CREATED="已创建配置文件：%s"
MSG_CONFIG_FIELDS_UPDATED="已更新配置字段"
MSG_MISSING_FIELDS="以下字段尚未配置：%s"
MSG_EDIT_CONFIG="请编辑 %s 补充配置"
MSG_INIT_COMPLETE="初始化完成！"
MSG_NEXT_STEPS="下一步："
MSG_STEP_EDIT_CONFIG="  1. 编辑 %s 填写服务器信息"
MSG_STEP_PLACE_KEY="  2. 将私钥文件放入 %s"
MSG_STEP_TELL_CLAUDE="  3. 告诉 Claude：\"把代码同步到服务器\""

# ============================================================================
# 私钥绑定相关 (sftp-keybind.sh)
# ============================================================================
MSG_KEYBIND_COMPLETE="私钥已绑定且权限正确：%s"
MSG_KEY_PERMISSIONS_FIXED="已修正私钥权限：%s -> 600"
MSG_NO_KEY_FOUND="未在 %s 下找到私钥文件"
MSG_SUPPORTED_KEYS="支持的文件：%s"
MSG_PLACE_KEY_IN_DIR="请将私钥文件放入 %s"
MSG_KEY_BOUND="已绑定私钥：%s"
MSG_CONFIG_UPDATED="配置已更新：%s"

# ============================================================================
# 公钥部署相关 (sftp-copy-id.sh)
# ============================================================================
MSG_USING_PROJECT_PUBKEY="使用项目私钥对应的公钥：%s"
MSG_USING_SYSTEM_PUBKEY="使用系统默认公钥：%s"
MSG_NO_PUBKEY_FOUND="未找到公钥文件"
MSG_GENERATE_KEYPAIR="请生成密钥对：ssh-keygen -t ed25519"
MSG_NEED_SSH_COPY_ID="需要 ssh-copy-id 命令（OpenSSH 自带）"
MSG_DEPLOYING_TO="部署公钥到 %s"
MSG_PUBKEY_FILE="公钥文件：%s"
MSG_ENTER_PASSWORD="根据提示输入服务器密码（密码不会显示）"
MSG_PUBKEY_DEPLOYED="完成！公钥已部署到服务器"

# ============================================================================
# 文件上传相关 (sftp-push.sh)
# ============================================================================
MSG_CHECKING_KEYBIND="检查私钥绑定..."
MSG_TARGET_SERVER="目标服务器：%s"
MSG_CHECKING_CHANGES="检测文件变更..."
MSG_FIRST_UPLOAD_FULL="首次上传，无历史推送记录，执行全量上传"
MSG_SCANNING_FILES="全量扫描项目文件..."
MSG_FOUND_FILES_FULL="找到 %s 个文件（全量）"
MSG_FOUND_FILES_INCREMENTAL="检测到 %s 个变更文件（增量）"
MSG_FOUND_FILES_DELETED="检测到 %s 个已删除文件"
MSG_DELETE_NOT_ENABLED="未启用 --delete，跳过远程删除"
MSG_NO_CHANGES="没有检测到文件变更，无需上传"
MSG_UPLOADING_FILES="正在上传 %s 个文件到 %s ..."
MSG_UPLOADING_DIR="正在上传目录 %s ..."
MSG_SYNCING_INCREMENTAL="正在增量同步到 %s (上传 %s, 删除 %s) ..."
MSG_ENSURE_REMOTE_DIR="确保远程目录存在..."
MSG_UPLOAD_COMPLETE="上传完成！"
MSG_DRY_RUN_MODE="[预览模式]"
MSG_DRY_RUN_WILL_UPLOAD="[预览模式] 将上传 %s 个文件到 %s"
MSG_FILE_NOT_FOUND="文件不存在，跳过：%s"
MSG_UPLOAD_SUCCESS="已记录推送点：%s"
MSG_PUSHING_DIR="推送目录：%s -> %s"

# ============================================================================
# 错误相关
# ============================================================================
MSG_CONFIG_MISSING="配置文件不存在：%s"
MSG_RUN_INIT_FIRST="请先运行 sftp-init.sh 初始化配置"
MSG_CONFIG_INCOMPLETE="配置不完整，缺少：%s"
MSG_UNKNOWN_OPTION="未知选项：%s"
MSG_UNKNOWN_PARAMETER="未知参数：%s"
MSG_REQUIRES_SFTP="需要 sftp 命令"
MSG_UPLOAD_FAILED="上传失败 (exit code: %s)"
MSG_NO_FILES_TO_UPLOAD="没有找到需要上传的文件"
MSG_DIR_NOT_EXISTS="目录不存在：%s"
```

---

## 5.4 在脚本中使用 i18n

### 5.4.1 引入 i18n 库

```bash
#!/bin/bash
# sftp-push.sh

# 1. 确定脚本目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 2. source i18n 库
source "$SCRIPT_DIR/i18n.sh"

# 3. 初始化语言（从配置文件读取）
CONFIG_FILE="$PROJECT_ROOT/.claude/sftp-cc/sftp-config.json"
init_lang "$CONFIG_FILE"

# 4. 现在可以使用 MSG_XXX 变量
info "$MSG_UPLOAD_COMPLETE"
```

### 5.4.2 替换硬编码消息

#### Before（硬编码英文）

```bash
#!/bin/bash
# 旧的代码

info "Upload complete!"
error "Configuration file not found: $CONFIG_FILE"
warn "No changes detected, nothing to upload"
```

#### After（多语言）

```bash
#!/bin/bash
# 新的代码

info "$MSG_UPLOAD_COMPLETE"
error "$(printf "$MSG_CONFIG_MISSING" "$CONFIG_FILE")"
warn "$MSG_NO_CHANGES"
```

### 5.4.3 处理参数化消息

#### 简单参数

```bash
# 定义
MSG_UPLOADING_FILES="正在上传 %s 个文件到 %s ..."

# 使用（单个参数）
info "$(printf "$MSG_UPLOADING_FILES" "$count" "$target")"

# 输出
正在上传 15 个文件到 user@server:/var/www ...
```

#### 多个参数

```bash
# 定义
MSG_SYNCING_INCREMENTAL="正在增量同步到 %s (上传 %s, 删除 %s) ..."

# 使用
info "$(printf "$MSG_SYNCING_INCREMENTAL" "$SFTP_TARGET" "$upload_count" "$delete_count")"

# 输出
正在增量同步到 user@server:/var/www (上传 5, 删除 2) ...
```

### 5.4.4 在日志函数中使用

```bash
# 定义日志函数
info()  { echo -e "${GREEN}[push]${NC} $*"; }
error() { echo -e "${RED}[push]${NC} $*" >&2; }

# 使用 i18n 消息
info "$MSG_CHECKING_KEYBIND"
info "$(printf "$MSG_TARGET_SERVER" "$SFTP_TARGET:$REMOTE_PATH")"

# 错误消息
if [ ! -f "$CONFIG_FILE" ]; then
    error "$(printf "$MSG_CONFIG_MISSING" "$CONFIG_FILE")"
    error "$MSG_RUN_INIT_FIRST"
    exit 1
fi
```

### 5.4.5 条件消息

```bash
# 根据条件选择不同的消息
if [ "$change_count" -eq 0 ]; then
    info "$MSG_NO_CHANGES"
else
    info "$(printf "$MSG_FOUND_FILES_INCREMENTAL" "$change_count")"
fi

# 根据模式选择
if $DRY_RUN; then
    info "$MSG_DRY_RUN_MODE"
else
    info "$MSG_UPLOAD_COMPLETE"
fi
```

---

## 5.5 语言配置详解

### 5.5.1 sftp-config.json 中的 language 字段

```json
{
  "host": "example.com",
  "port": 22,
  "username": "deploy",
  "remote_path": "/var/www/html",
  "local_path": ".",
  "private_key": "",
  "language": "zh",
  "excludes": [".git", ".claude", "node_modules"]
}
```

### 5.5.2 支持的语言代码

| 代码 | 语言 | 备注 |
|------|------|------|
| `en` | English | 默认语言 |
| `zh` | 中文 | 简体中文 |
| `zh_CN` | 中文（中国大陆） | 同 `zh` |
| `zh_TW` | 中文（台湾） | 同 `zh`（当前） |
| `ja` | 日本語 | 日语 |
| `ja_JP` | 日本語（日本） | 同 `ja` |

### 5.5.3 扩展新语言：韩语示例

#### 步骤 1：添加 case 分支

```bash
load_messages() {
    local lang="$1"

    case "$lang" in
        # ... 现有语言 ...

        ko|ko_KR)
            # 韩语消息
            MSG_CONFIG_DIR_CREATED="설정 디렉토리를 생성했습니다：%s"
            MSG_CONFIG_FILE_EXISTS="설정 파일이 이미 존재합니다：%s"
            MSG_CONFIG_FILE_CREATED="설정 파일을 생성했습니다：%s"
            MSG_INIT_COMPLETE="초기화가 완료되었습니다!"

            MSG_KEYBIND_COMPLETE="개인 키가 바인딩되었습니다：%s"
            MSG_KEY_PERMISSIONS_FIXED="개인 키 권한 수정：%s -> 600"
            MSG_NO_KEY_FOUND="%s 에서 개인 키를 찾을 수 없습니다"

            MSG_UPLOAD_COMPLETE="업로드 완료!"
            MSG_CHECKING_KEYBIND="개인 키 바인드 확인 중..."
            MSG_TARGET_SERVER="대상 서버：%s"
            MSG_CHECKING_CHANGES="파일 변경 확인 중..."
            MSG_FOUND_FILES_INCREMENTAL="%s 개의 변경 파일 감지 (증분)"
            MSG_UPLOADING_FILES="%s 개의 파일을 %s 에 업로드 중 ..."
            # ... 继续添加所有消息 ...
            ;;
    esac
}
```

#### 步骤 2：更新文档

````markdown
支持的语言：
- English (en)
- 中文 (zh, zh_CN, zh_TW)
- 日本語 (ja, ja_JP)
- 한국어 (ko, ko_KR)  ← 新增
````

#### 步骤 3：测试

```bash
# 修改配置
echo '{"language": "ko"}' > test-config.json

# 运行脚本
source i18n.sh
init_lang "test-config.json"

# 验证
echo "$MSG_UPLOAD_COMPLETE"
# 应输出：업로드 완료!
```

---

## 5.6 消息命名规范

### 5.6.1 命名格式

```
MSG_<模块>_<动作>_<对象>_<状态>
```

**示例解析**：

| 消息 | 命名解析 |
|------|----------|
| `MSG_CONFIG_DIR_CREATED` | CONFIG（配置）+ DIR（目录）+ CREATED（已创建） |
| `MSG_UPLOAD_COMPLETE` | UPLOAD（上传）+ COMPLETE（完成） |
| `MSG_KEY_PERMISSIONS_FIXED` | KEY（密钥）+ PERMISSIONS（权限）+ FIXED（已修正） |

### 5.6.2 命名最佳实践

```bash
# ✅ 好的命名
MSG_CONFIG_FILE_EXISTS      # 清晰、具体
MSG_UPLOAD_FAILED           # 动作 + 状态
MSG_UNKNOWN_OPTION          # 问题类型

# ❌ 差的命名
MSG_1                     # 无意义
MSG_ERROR                 # 太泛化
MSG_UPLOAD_ERR            # 缩写不清晰
```

### 5.6.3 消息清单管理

建议维护一个消息清单文件：

```bash
# docs/i18n-messages.md

# i18n 消息清单

## 初始化相关
| 键 | 英文 | 中文 | 日文 |
|----|------|------|------|
| MSG_CONFIG_DIR_CREATED | Configuration directory created: %s | 已创建配置目录：%s | 設定ディレクトリを作成しました：%s |
| MSG_INIT_COMPLETE | Initialization complete! | 初始化完成！ | 初期化が完了しました！ |

## 上传相关
| 键 | 英文 | 中文 | 日文 |
|----|------|------|------|
| MSG_UPLOAD_COMPLETE | Upload complete! | 上传完成！ | アップロード完了！ |
| MSG_NO_CHANGES | No changes detected | 没有检测到变更 | 変更が検出されませんでした |
```

---

## 5.7 多语言触发词设计

### 5.7.1 触发词 vs 输出语言

理解这两个概念的区别：

```
触发词（Trigger）输出语言（Output Language）
    ↓                    ↓
用户输入的语言       脚本输出的语言
决定调用哪个脚本     由配置文件决定

示例：
用户说："同步代码到服务器"  →  触发 sftp-push.sh
                                   ↓
                          读取 config 的 language 字段
                                   ↓
                          输出："上传完成！"（中文）
```

### 5.7.2 SKILL.md 中的触发词分组

````markdown
## When to trigger this Skill

**SFTP 上传/部署类**:
- "sync code to server", "upload to server", "deploy code"  # 英文
- "同步代码到服务器"、"上传到服务器"、"部署代码"            # 中文
- "サーバーに同期する"、"デプロイする"                      # 日文

**私钥绑定类**:
- "bind sftp private key", "bind ssh key"                  # 英文
- "绑定 SFTP 私钥"、"绑定私钥"                              # 中文
- "秘密鍵をバインドする"、"SSH 鍵をバインドする"           # 日文

**配置初始化类**:
- "initialize sftp config", "setup sftp"                   # 英文
- "初始化 SFTP 配置"、"配置 SFTP"                          # 中文
- "SFTP 設定を初期化"、"SFTP 設定"                         # 日文
````

### 5.7.3 触发词设计原则

```
原则 1：自然语言
  ✅ "sync code to server"  （用户会说的话）
  ❌ "execute_sftp_upload"  （像函数名）

原则 2：多语言覆盖
  英文 + 中文 + 日文（至少覆盖目标用户语言）

原则 3：避免歧义
  ❌ "push"  （与 git push 冲突）
  ✅ "sftp push"  （明确是 SFTP）
```

---

## 5.8 调试与测试

### 5.8.1 验证语言加载

```bash
# 在脚本中添加调试输出
VERBOSE=true
if $VERBOSE; then
    echo "[DEBUG] Language: $lang" >&2
    echo "[DEBUG] MSG_UPLOAD_COMPLETE: $MSG_UPLOAD_COMPLETE" >&2
    echo "[DEBUG] MSG_CONFIG_MISSING: $MSG_CONFIG_MISSING" >&2
fi
```

### 5.8.2 测试不同语言

#### 方法 1：临时修改配置

```bash
# 备份原配置
cp sftp-config.json sftp-config.json.bak

# 测试中文
echo '{"language": "zh"}' > sftp-config.json
bash scripts/sftp-push.sh -n

# 测试日文
echo '{"language": "ja"}' > sftp-config.json
bash scripts/sftp-push.sh -n

# 恢复
mv sftp-config.json.bak sftp-config.json
```

#### 方法 2：环境变量覆盖

```bash
# 在 i18n.sh 中添加环境变量支持
init_lang() {
    local config_file="$1"
    local lang=""

    # 环境变量优先
    if [ -n "$SFTP_CC_LANGUAGE" ]; then
        lang="$SFTP_CC_LANGUAGE"
    elif [ -f "$config_file" ]; then
        lang=$(grep '"language"' "$config_file" ... )
    fi

    # ...
}

# 使用
SFTP_CC_LANGUAGE=zh bash scripts/sftp-push.sh
```

### 5.8.3 检查消息完整性

```bash
# 脚本 1：提取所有使用的 MSG_变量
grep -oh 'MSG_[A-Z_]*' scripts/*.sh | sort -u > used_messages.txt

# 脚本 2：提取 i18n.sh 中定义的消息
grep -o 'MSG_[A-Z_]*=' scripts/i18n.sh | sed 's/=//' | sort -u > defined_messages.txt

# 脚本 3：比较差异
comm -23 used_messages.txt defined_messages.txt
# 输出：使用了但未定义的消息（需要补充）
```

### 5.8.4 自动化测试

```bash
#!/bin/bash
# test-i18n.sh

source scripts/i18n.sh

test_language() {
    local expected_lang="$1"
    local config_content="$2"

    echo "$config_content" > /tmp/test-config.json
    init_lang "/tmp/test-config.json"

    if [ -z "$MSG_UPLOAD_COMPLETE" ]; then
        echo "FAIL: $expected_lang - MSG_UPLOAD_COMPLETE is empty"
        return 1
    fi

    echo "PASS: $expected_lang"
    return 0
}

# 测试用例
test_language "en" '{"language": "en"}'
test_language "zh" '{"language": "zh"}'
test_language "ja" '{"language": "ja"}'
test_language "en (default)" '{"language": "invalid"}'
test_language "en (missing)" '{}'

rm -f /tmp/test-config.json
```

---

## 5.9 性能优化

### 5.9.1 懒加载消息

```bash
# 问题：每次 source 都加载所有消息
source i18n.sh  # 加载 100+ 条消息

# 优化：按需加载
load_message() {
    local key="$1"
    local lang="${2:-en}"

    # 只加载请求的消息
    case "$key" in
        MSG_UPLOAD_COMPLETE)
            case "$lang" in
                zh) echo "上传完成" ;;
                ja) echo "アップロード完了" ;;
                *) echo "Upload complete" ;;
            esac
            ;;
        # ...
    esac
}
```

### 5.9.2 缓存消息

```bash
# 将加载的消息缓存到临时文件
CACHE_FILE="/tmp/sftp-cc-i18n-cache-$lang"

if [ -f "$CACHE_FILE" ] && [ "$CACHE_FILE" -nt "$CONFIG_FILE" ]; then
    # 使用缓存
    source "$CACHE_FILE"
else
    # 重新加载并缓存
    load_messages "$lang"
    # 缓存实现（略）
fi
```

---

## 5.10 常见问题解答

### Q1: 为什么不使用 gettext？

**A**: gettext 需要额外安装，增加用户负担。变量式方案零依赖，开箱即用。

### Q2: 如何保证翻译质量？

**A**:
1. 使用母语者翻译
2. 避免机器直译
3. 添加翻译审核流程
4. 接受社区贡献（GitHub PR）

### Q3: 中文简体繁体如何处理？

**A**: 当前 `zh`, `zh_CN`, `zh_TW` 统一使用简体。如需支持繁体：
```bash
zh_TW)
    MSG_UPLOAD_COMPLETE="上傳完成"
    # ... 繁体中文消息
    ;;
```

### Q4: 消息中包含特殊字符怎么办？

**A**: 使用单引号包裹：
```bash
MSG_STEP_TELL_CLAUDE='  3. 告诉 Claude："同步代码到服务器"'
```

### Q5: 如何处理 RTL 语言（如阿拉伯语）？

**A**: 需要额外处理文本方向：
```bash
# 添加方向标记
MSG_UPLOAD_COMPLETE="<span dir=\"rtl\">تم الرفع!</span>"
```
（注：CLI 中对 RTL 支持有限，需谨慎考虑）

---

## 5.11 本章总结

### 核心知识点回顾

| 概念 | 关键点 |
|------|--------|
| 变量式方案 | 零依赖、纯 Shell、易维护 |
| init_lang() | 从配置读取 language 字段 |
| load_messages() | case 语句按语言加载 |
| 消息命名 | MSG_<模块>_<动作>_<对象> |
| 触发词 | 多语言覆盖、避免歧义 |
| 测试方法 | 临时修改配置、环境变量覆盖 |

### i18n 检查清单

在发布前确认：

- [ ] 所有用户可见消息都已翻译
- [ ] 三种语言（en/zh/ja）消息完整
- [ ] 消息命名符合规范
- [ ] 没有硬编码的消息字符串
- [ ] 测试过每种语言的输出
- [ ] 文档中说明如何切换语言

---

## 5.12 练习与实践

### 基础练习

**练习 5-1**：添加英文消息
- 检查 i18n.sh 中是否有英文默认消息
- 确保所有中文消息都有对应的英文翻译

**练习 5-2**：测试语言切换
- 创建三个测试配置文件（en/zh/ja）
- 验证每种语言的输出

### 进阶练习

**练习 5-3**：添加第四种语言
- 选择一门你熟悉的语言
- 在 load_messages() 中添加新分支
- 翻译所有消息

**练习 5-4**：创建消息清单
- 用表格整理所有 MSG_XXX 变量
- 包含英文、中文、日文三列

### 实践项目

为你的 Skill 添加多语言支持：
1. 创建 i18n.sh 文件
2. 定义 init_lang() 和 load_messages()
3. 替换所有硬编码消息
4. 测试每种语言

---

## 下一章预告

第 6 章将介绍**调试与测试技巧**：
- Shell 脚本调试基础（set 命令选项）
- 日志级别设计
- verbose 模式实现
- 临时文件管理
- 错误处理模式
- 测试方法（单元测试、集成测试、dry-run）
- 调试实战案例
- 验证工具

---

## 关于本书

**第一版（数字版）, 2026 年 3 月**

**作者**：[toohamster](https://github.com/toohamster)
**授权**：电子版 MIT License，纸质版/商业版 © All Rights Reserved
**源码**：[github.com/toohamster/sftp-cc](https://github.com/toohamster/sftp-cc)

详细说明请参阅 [LICENSE](../../LICENSE) 和 [关于作者](../authors.md)

---
