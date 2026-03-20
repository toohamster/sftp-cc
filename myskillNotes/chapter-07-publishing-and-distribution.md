# 第 7 章：发布与分发

## 7.1 Plugin Marketplace 架构

### 两种安装方式
| 安装方式 | 路径 | 说明 |
|----------|------|------|
| Plugin 安装 | `~/.claude/plugins/marketplaces/sftp-cc/` | 推荐，自动更新 |
| 手动安装 | `.claude/skills/sftp-cc/` | 兼容旧版本 |

### marketplace.json 结构
```json
{
  "$schema": "https://anthropic.com/claude-code/marketplace.schema.json",
  "name": "sftp-cc",
  "description": "Universal SFTP upload tool for Claude Code.",
  "owner": {
    "name": "toohamster"
  },
  "plugins": [
    {
      "name": "sftp-cc",
      "description": "Universal SFTP upload tool with incremental upload.",
      "source": "./",
      "strict": false,
      "skills": [
        "./skills/sftp-cc"
      ]
    }
  ]
}
```

### 字段说明
| 字段 | 说明 |
|------|------|
| `name` | Plugin 名称（唯一标识） |
| `description` | Plugin 描述，出现在市场中 |
| `owner.name` | 作者名称 |
| `plugins[].source` | 插件源码路径（相对路径） |
| `plugins[].skills` | Skill 定义文件路径数组 |
| `strict` | 是否严格模式（false 允许更多灵活性） |

---

## 7.2 版本管理

### SemVer 语义化版本
```
主版本号。次版本号。修订号
MAJOR.MINOR.PATCH
```

| 版本变化 | 说明 | 示例 |
|----------|------|------|
| MAJOR | 破坏性变更 | v1.0.0 → v2.0.0 |
| MINOR | 向后兼容的新功能 | v2.0.0 → v2.1.0 |
| PATCH | 向后兼容的问题修复 | v2.1.0 → v2.1.1 |

### 版本号递增规则
- **MAJOR**: 删除 API、修改触发词导致不兼容
- **MINOR**: 新增功能、新增触发词
- **PATCH**: Bug 修复、文档更新

### 使用 GitHub Releases
```bash
# 查看最新 tag
git describe --tags --abbrev=0

# 查看所有 tag
git tag -l

# 计算新版本号（PATCH + 1）
LAST_TAG="v2.1.0"
NEW_TAG=$(echo "$LAST_TAG" | awk -F. '{print $1"."$2"."$3+1}')
echo "$NEW_TAG"  # v2.1.1
```

---

## 7.3 使用 GitHub HTTP API 发布

### 为什么使用 HTTP API
| 对比项 | git tag/push | HTTP API |
|--------|--------------|----------|
| 需要本地 git tag | 是 | 否 |
| 需要推送 tag | 是 | 否 |
| 可自动化 | 较复杂 | 简单 |
| 适合 CI/CD | 一般 | ✅ |

### 完整发布流程

#### 1. 提交所有更改
```bash
git add -A
git commit -m "feat: description

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
```

#### 2. 推送代码到 main 分支
```bash
git push origin main
```

#### 3. 获取 GitHub Token
```bash
# 从 git credential 获取
GITHUB_TOKEN=$(echo "url=https://github.com" | git credential fill | grep password | cut -d= -f2)
```

#### 4. 获取最新 commit hash
```bash
COMMIT_HASH=$(git rev-parse HEAD)
```

#### 5. 计算新版本号
```bash
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v2.0.0")
NEW_TAG=$(echo "$LAST_TAG" | awk -F. '{print $1"."$2"."$3+1}')
```

#### 6. 创建 Git Tag 引用
```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/toohamster/sftp-cc/git/refs \
  -d "{\"ref\":\"refs/tags/$NEW_TAG\",\"sha\":\"$COMMIT_HASH\"}"
```

#### 7. 创建 GitHub Release
```bash
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/toohamster/sftp-cc/releases \
  -d "{\"tag_name\":\"$NEW_TAG\",\"target_commitish\":\"$COMMIT_HASH\",\"name\":\"$NEW_TAG - Release\",\"body\":\"Release $NEW_TAG\",\"draft\":false,\"prerelease\":false}"
```

### 注意事项
1. **JSON body 中禁止使用反引号** `` ` `` — 会被 bash 解析为命令替换
2. **使用单引号包裹 JSON** — 防止变量提前展开
3. **错误处理** — 检查 API 返回状态码

---

## 7.4 完整的发布脚本

### release.sh 示例
```bash
#!/bin/bash
# release.sh — Automated release script
set -euo pipefail

# 1. 检查是否有未提交的更改
if [ -n "$(git status --porcelain)" ]; then
    echo "Error: 有未提交的更改，请先提交"
    exit 1
fi

# 2. 获取当前分支
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Error: 请在 main 分支上发布"
    exit 1
fi

# 3. 提交更改（如果有）
read -p "是否提交当前更改并推送？(y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    git add -A
    git commit -m "chore: prepare release

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"
    git push origin main
fi

# 4. 获取 GitHub Token
GITHUB_TOKEN=$(echo "url=https://github.com" | git credential fill | grep password | cut -d= -f2)
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: 无法获取 GitHub Token"
    exit 1
fi

# 5. 获取最新 commit hash
COMMIT_HASH=$(git rev-parse HEAD)

# 6. 获取当前最新 tag 并计算新版本
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v2.0.0")
NEW_TAG=$(echo "$LAST_TAG" | awk -F. '{print $1"."$2"."$3+1}')

echo "当前 tag: $LAST_TAG"
echo "新版本：$NEW_TAG"
echo "Commit: $COMMIT_HASH"
echo ""

# 7. 用户确认
read -p "确认发布 $NEW_TAG？(y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "已取消"
    exit 0
fi

# 8. 创建 tag 引用
echo "正在创建 tag 引用..."
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/toohamster/sftp-cc/git/refs \
  -d "{\"ref\":\"refs/tags/$NEW_TAG\",\"sha\":\"$COMMIT_HASH\"}"

# 9. 创建 Release
echo "正在创建 Release..."
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/toohamster/sftp-cc/releases \
  -d "{\"tag_name\":\"$NEW_TAG\",\"target_commitish\":\"$COMMIT_HASH\",\"name\":\"$NEW_TAG\",\"body\":\"Release $NEW_TAG\",\"draft\":false,\"prerelease\":false}"

echo ""
echo "发布完成！"
echo "查看：https://github.com/toohamster/sftp-cc/releases/tag/$NEW_TAG"
```

---

## 7.5 CLAUDE.md 中的操作规范

### 发布指令
当用户说 "提交打标签和发布" 时，自动执行以下完整流程：

```bash
# 1. 提交所有更改
git add -A
git commit -m "feat: description

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

# 2. 推送代码
git push origin main

# 3. 从 git credential 获取 GitHub Token
GITHUB_TOKEN=$(echo "url=https://github.com" | git credential fill | grep password | cut -d= -f2)

# 4. 获取最新 commit hash
COMMIT_HASH=$(git rev-parse HEAD)

# 5. 获取当前最新 tag 并计算新版本
LAST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v2.0.0")
NEW_TAG=$(echo "$LAST_TAG" | awk -F. '{print $1"."$2"."$3+1}')

# 6. 使用 GitHub API 创建 tag 引用
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/toohamster/sftp-cc/git/refs \
  -d "{\"ref\":\"refs/tags/$NEW_TAG\",\"sha\":\"$COMMIT_HASH\"}"

# 7. 使用 GitHub API 创建 Release
curl -s -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/toohamster/sftp-cc/releases \
  -d "{\"tag_name\":\"$NEW_TAG\",\"target_commitish\":\"$COMMIT_HASH\",\"name\":\"$NEW_TAG - Release\",\"body\":\"Release $NEW_TAG\",\"draft\":false,\"prerelease\":false}"
```

### 提交流程规范
1. 完成修改后 → 展示更改内容（`git diff`）
2. 等待用户回复确认 → 再执行 `git commit`
3. 不要擅自提交

**例外**：只有当用户明确说 "提交打标签和发布" 时，才自动执行完整发布流程。

---

## 7.6 安装与测试

### Plugin 安装命令
```bash
# 从 GitHub 仓库安装
/plugin marketplace add https://github.com/toohamster/sftp-cc

# 从本地目录安装（开发测试）
/plugin marketplace add /path/to/sftp-cc

# 移除 Plugin
/plugin marketplace remove sftp-cc

# 查看已安装的 Plugin
/plugin list
```

### 手动安装
```bash
# 运行安装脚本
bash install.sh /path/to/target-project

# 或手动复制文件
cp -r skill.md .claude/skills/sftp-cc/
cp -r scripts/ .claude/skills/sftp-cc/
```

### 验证安装
```bash
# 验证 Plugin 结构
claude plugin validate .

# 在 Claude Code 中测试触发词
# "sync code to server"
# "绑定 SFTP 私钥"
```

---

## 7.7 多语言 README

### 文档结构
```
README.md        # 英文文档（主文档）
README_CN.md     # 中文文档
README_JP.md     # 日文文档
```

### 更新策略
- 新增功能时同步更新所有语言版本
- 可以借助 AI 翻译快速生成
- 保持结构和内容一致

### 文档内容清单
- [ ] 项目简介
- [ ] 安装方法（Plugin + 手动）
- [ ] 配置说明
- [ ] 使用示例
- [ ] 触发词列表
- [ ] Troubleshooting
- [ ] License

---

## 7.8 持续集成（可选）

### GitHub Actions 示例
```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Validate Plugin
        run: |
          # 安装 claude-code
          npm install -g @anthropic-ai/claude-code
          claude plugin validate .

  release:
    needs: validate
    if: startsWith(github.ref, 'refs/tags/')
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          draft: false
          prerelease: false
```

---

## 本章小结

- marketplace.json 定义 Plugin 元数据
- 使用 SemVer 管理版本
- GitHub HTTP API 自动化发布
- 完整的发布流程：提交 → 推送 → 创建 tag → 创建 Release
- 支持 Plugin 安装和手动安装两种方式
- 多语言 README 提升用户体验

## 下一章

第 8 章将介绍进阶技巧与最佳实践。
