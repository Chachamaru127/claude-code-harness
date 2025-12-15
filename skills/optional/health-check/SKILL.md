---
name: ccp-health-check
description: "環境診断（依存/設定/利用可能機能の確認）。環境が正しくセットアップされているか確認したい場合に使用します。"
allowed-tools: ["Read", "Bash"]
metadata:
  skillport:
    category: optional
    tags: [health-check, diagnosis, environment, setup]
    alwaysApply: false
---

# Health Check Skill

プラグインを使用する前に、環境が正しくセットアップされているかを診断するスキル。

---

## トリガーフレーズ

- 「この環境で動くかチェックして」
- 「何が足りない？」
- 「環境を診断して」
- 「使える機能を教えて」

---

## チェック項目

### 必須ツール
- Git
- Node.js / npm（該当する場合）
- GitHub CLI（オプション）

### 設定ファイル
- `claude-code-harness.config.json` の存在と妥当性
- `.claude/settings.json` の存在

### ワークフローファイル
- `Plans.md` の存在
- `AGENTS.md` の存在
- `CLAUDE.md` の存在

---

## 出力形式

```
## 環境診断レポート

### 必須ツール
✅ git (2.40.0)
✅ node (v20.10.0)
⚠️ gh (未インストール - CI自動修正に必要)

### 設定ファイル
✅ claude-code-harness.config.json
✅ .claude/settings.json

### 利用可能な機能
✅ /work, /plan-with-agent, /sync-status
⚠️ CI自動修正 (gh が必要)
```
