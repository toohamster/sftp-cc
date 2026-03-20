# 第 1 章：认识 Claude Code Skill

## 1.1 什么是 Claude Code Skill

### Skill 的定义
- Skill 是 Claude Code 的插件系统
- 通过自然语言触发
- 自动执行预定义的操作

### Skill 能做什么
- 文件操作（上传、下载、同步）
- 代码生成与转换
- 外部 API 调用
- 自动化工作流

### 与 VS Code 扩展的区别
| 对比项 | Claude Code Skill | VS Code 扩展 |
|--------|------------------|-------------|
| 触发方式 | 自然语言 | 点击按钮/快捷键 |
| 运行环境 | Claude Code CLI | VS Code |
| 开发难度 | 低（文档 + 脚本） | 高（TypeScript+API） |

---

## 1.2 Claude Code Plugin 架构

### 目录结构
```
my-plugin/
├── .claude-plugin/
│   └── marketplace.json    # Marketplace 配置
├── skills/
│   └── my-skill/
│       └── SKILL.md        # Skill 定义（核心）
├── scripts/
│   └── my-script.sh        # 执行脚本
└── README.md               # 说明文档
```

### 核心组件

#### 1. SKILL.md
- Skill 的核心定义文件
- 包含 YAML frontmatter
- 定义触发词和执行逻辑

#### 2. ${CLAUDE_PLUGIN_ROOT} 变量
```markdown
**重要**：${CLAUDE_PLUGIN_ROOT} 是 Claude Code 注入的 Skill 内部变量

- 只在 Skill 上下文中有效
- 执行时自动解析为插件根目录路径
- 示例：`~/.claude/plugins/marketplaces/my-plugin/`
```

#### 3. scripts/ 目录
- 存放可执行脚本
- 支持 shell、Python 等
- 通过 ${CLAUDE_PLUGIN_ROOT}/scripts/ 访问

---

## 1.3 Skill 工作原理

### 触发流程
```
用户输入 → Claude 识别意图 → 匹配触发词 → 加载 SKILL.md → 执行对应脚本
```

### 变量注入机制
```
用户说："同步代码到服务器"
  ↓
Claude 识别 SFTP 上传意图
  ↓
查找匹配的 Skill（sftp-cc）
  ↓
加载 SKILL.md，注入 ${CLAUDE_PLUGIN_ROOT}
  ↓
执行：bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh
```

### 常见问题

**Q: 为什么我用 bash 执行时 ${CLAUDE_PLUGIN_ROOT} 是空的？**

A: `${CLAUDE_PLUGIN_ROOT}` 只在 Skill 上下文中由 Claude Code 注入。直接在 shell 中执行时，需要改用绝对路径：
```bash
# 错误：直接执行，变量为空
bash ${CLAUDE_PLUGIN_ROOT}/scripts/sftp-push.sh

# 正确：使用绝对路径
bash ~/.claude/plugins/marketplaces/sftp-cc/scripts/sftp-push.sh
```

---

## 1.4 开发环境准备

### 安装 Claude Code
```bash
# macOS
brew install claude-code

# npm
npm install -g @anthropic-ai/claude-code
```

### 验证安装
```bash
claude --version
```

### 目录准备
```bash
# 创建项目目录
mkdir my-first-skill
cd my-first-skill

# 创建基本结构
mkdir -p .claude-plugin skills/my-skill scripts
```

---

## 本章小结

- Skill 是 Claude Code 的插件系统
- SKILL.md 是核心定义文件
- ${CLAUDE_PLUGIN_ROOT} 是内部变量，执行时自动解析
- 开发环境需要安装 Claude Code CLI

## 下一章

第 2 章将带你进行项目规划与设计，从需求分析到目录结构规划。
