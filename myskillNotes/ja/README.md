# Claude Code Skill の書き方

> sftp-cc プロジェクトからの実践ガイド

**サブタイトル**: ゼロから初めての Claude Code Plugin を構築

---

## 言語バージョン

| 言語 | バージョン | リンク |
|------|-----------|--------|
| 中文 | 簡体字中国語 | [中文版](../zh-cn/README.md) |
| English | 英語 | [English Version](../en/README.md) |
| 日本語 | 日本語 | [日本語版](README.md) |

---

## 本書の概要

本書は、SFTP アップロードツール（sftp-cc）を構築することで、Claude Code Skill 開発の完全なプロセスをガイドします。学習できること：

- Claude Code Plugin アーキテクチャの理解
- SKILL.md 作成テクニックの習得
- 多言語サポート（i18n）の実装
- Plugin Marketplace への公開

---

## 目次

| 章 | タイトル | コアコンテンツ |
|---------|-------|--------------|
| 第 1 章 | [Claude Code Skill とは](chapter-01-introduction.md) | Plugin アーキテクチャ、SKILL.md 構造、${CLAUDE_PLUGIN_ROOT} 変数 |
| 第 2 章 | [プロジェクト計画と設計](chapter-02-planning.md) | 要件分析、機能設計、ディレクトリ構造 |
| 第 3 章 | [初めての Skill を書く](chapter-03-writing-skill.md) | トリガーワード設計、YAML frontmatter |
| 第 4 章 | [スクリプト開発](chapter-04-script-development.md) | Shell スクリプト、JSON パース、エラーハンドリング |
| 第 5 章 | [国際化 (i18n)](chapter-05-internationalization.md) | 多言語設計、変数式 i18n |
| 第 6 章 | [デバッグとテスト](chapter-06-debugging-and-testing.md) | ローカルテスト、Plugin 検証 |
| 第 7 章 | [公開と配布](chapter-07-publishing-and-distribution.md) | GitHub Release、marketplace 設定 |
| 第 8 章 | [トピックとベストプラクティス](chapter-08-advanced-topics.md) | ベストプラクティス、パフォーマンス最適化 |

---

## 著者について

**toohamster** - GitHub: [@toohamster](https://github.com/toohamster)

本書は、sftp-cc（Claude Code SFTP アップロードツール）の開発における著者の実践経験に基づいています。

詳細は [著者について](authors.md) をご覧ください。

---

## ライセンス

### 電子版（GitHub リポジトリ）
**初版（デジタル版）, 2026 年 3 月**

[MIT License](../LICENSE) の下で公開されています。

- ✅ 無料で閲覧、複製、修正可能
- ✅ 個人学習での利用
- ✅ GitHub 等プラットフォームでの共有

### 印刷版/商業版
© 2026 toohamster. All Rights Reserved.

本書の印刷版および商業電子版（PDF、EPUB、書籍など）は著作権法により
保護されています。出版者の書面による許可なく、本書のいかなる部分も
複製または送信することはできません。

---

© 2026 toohamster
