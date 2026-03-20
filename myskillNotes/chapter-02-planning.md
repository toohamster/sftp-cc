# 第 2 章：项目规划与设计

## 2.1 需求分析

### 从痛点出发
记录开发 sftp-cc 的初衷：
> "当使用 PhpStorm 时，内置的 SFTP 扩展会自动将文件同步到服务器。切换到 Claude Code 后失去了这个能力——每次 Claude 修改代码后，需要手动到测试服务器拉取，效率很低。"

### 需求清单
| 需求 | 优先级 | 说明 |
|------|--------|------|
| 上传文件到服务器 | ⭐⭐⭐ | 核心功能 |
| 增量上传 | ⭐⭐⭐ | 只上传变更文件 |
| 私钥自动绑定 | ⭐⭐ | 简化配置 |
| 权限修正 | ⭐⭐ | chmod 600 |
| 多语言支持 | ⭐ | 国际化 |

### 功能边界
**不做的事情**：
- 下载文件（单向同步）
- 实时监听文件变化
- 多服务器同时部署

---

## 2.2 功能设计

### 核心功能模块
```
sftp-cc
├── 配置初始化 (sftp-init.sh)
├── 私钥绑定 (sftp-keybind.sh)
├── 公钥部署 (sftp-copy-id.sh)
└── 文件上传 (sftp-push.sh)
```

### 上传模式设计
| 模式 | 命令 | 说明 |
|------|------|------|
| 增量上传 | `sftp-push.sh` | 默认，仅上传变更 |
| 全量上传 | `sftp-push.sh --full` | 上传所有文件 |
| 指定文件 | `sftp-push.sh file.php` | 上传指定文件 |
| 指定目录 | `sftp-push.sh -d src/` | 上传指定目录 |
| 预览模式 | `sftp-push.sh -n` | 只显示不执行 |

### 增量检测逻辑
```bash
# 1. 已提交的变更
git diff --name-only --diff-filter=ACMR <last_hash> HEAD

# 2. 暂存区变更
git diff --cached --name-only --diff-filter=ACMR

# 3. 工作区修改
git diff --name-only --diff-filter=ACMR

# 4. 未跟踪文件
git ls-files --others --exclude-standard
```

---

## 2.3 目录结构规划

### 最终结构
```
sftp-cc/
├── .claude-plugin/
│   └── marketplace.json        # Plugin 配置
├── skills/
│   └── sftp-cc/
│       └── SKILL.md            # Skill 定义
├── scripts/
│   ├── sftp-init.sh            # 初始化配置
│   ├── sftp-keybind.sh         # 私钥绑定
│   ├── sftp-copy-id.sh         # 公钥部署
│   ├── sftp-push.sh            # 文件上传
│   └── i18n.sh                 # 多语言支持
├── templates/
│   └── sftp-config.example.json # 配置模板
├── skill.md                     # 手动安装 Skill 定义
├── install.sh                   # 手动安装脚本
├── README.md                    # 英文文档
├── README_CN.md                 # 中文文档
├── README_JP.md                 # 日文文档
├── SPEC.md                      # 技术规格
└── CLAUDE.md                    # 开发指南
```

### 两种安装方式
| 安装方式 | 路径 | 说明 |
|----------|------|------|
| Plugin 安装 | `~/.claude/plugins/marketplaces/sftp-cc/` | 推荐，自动更新 |
| 手动安装 | `.claude/skills/sftp-cc/` | 兼容旧版本 |

---

## 2.4 配置文件设计

### sftp-config.json
```json
{
  "host": "服务器地址",
  "port": 22,
  "username": "用户名",
  "remote_path": "/远程/目标/路径",
  "local_path": ".",
  "private_key": "",
  "language": "en",
  "excludes": [".git", ".claude", "node_modules"]
}
```

### 字段说明
| 字段 | 必填 | 默认值 | 说明 |
|------|------|--------|------|
| host | 是 | - | SFTP 服务器地址 |
| port | 否 | 22 | SFTP 端口 |
| username | 是 | - | 登录用户名 |
| remote_path | 是 | - | 远程目标路径 |
| local_path | 否 | "." | 本地源目录 |
| private_key | 否 | "" | 私钥路径（自动填充） |
| language | 否 | "en" | 界面语言 |
| excludes | 否 | 见上 | 排除的文件/目录 |

---

## 2.5 触发词设计

### 上传类触发词
```
英文："sync code to server", "upload to server", "deploy code"
中文："同步代码到服务器", "上传到服务器", "部署代码"
日文："サーバーに同期する", "デプロイする"
```

### 私钥绑定触发词
```
英文："bind sftp private key", "bind ssh key"
中文："绑定 SFTP 私钥", "绑定私钥"
日文："秘密鍵をバインドする", "SSH 鍵をバインドする"
```

### 不触发的词
- "push"、"推送" — 避免与 git push 冲突

---

## 2.6 技术选型

### 为什么选择 Shell
| 对比项 | Shell | Python | Node.js |
|--------|-------|--------|---------|
| 外部依赖 | 无 | 需要 pip | 需要 npm |
| 系统兼容 | 系统自带 | 需安装 | 需安装 |
| 开发难度 | 低 | 中 | 中 |
| 执行速度 | 快 | 中 | 中 |

### 零外部依赖原则
- 使用系统自带命令：`sftp`, `git`, `grep`, `sed`
- JSON 解析用 shell 实现，不依赖 jq
- 提高兼容性和可移植性

---

## 本章小结

- 从痛点出发进行需求分析
- 规划清晰的目录结构
- 设计合理的配置文件格式
- 多语言触发词覆盖

## 下一章

第 3 章将带你编写第一个 Skill，从 SKILL.md 开始。
