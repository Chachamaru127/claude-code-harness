---
name: harness-release
description: "Unified release skill for Harness v3. CHANGELOG, version bump, tag, GitHub Release automation. Use when user mentions: release, version bump, create tag, publish, /harness-release. Do NOT load for: implementation, code review, planning, or setup."
description-ja: "Harness v3 統合リリーススキル。CHANGELOG・バージョンバンプ・タグ・GitHub Release を自動化。以下で起動: リリース、バージョンバンプ、タグ作成、公開、/harness-release。実装・コードレビュー・プランニング・セットアップには使わない。"
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[patch|minor|major|--dry-run|--announce]"
effort: medium
context: fork
---

# Harness Release (v3)

Harness v3 の統合リリーススキル。
以下の旧スキルを統合:

- `release-har` — 汎用リリース自動化
- `x-release-harness` — Harness 専用リリース自動化
- `handoff` — PM へのハンドオフ・完了報告

## Quick Reference

```bash
/release          # インタラクティブ（バージョン種別を確認）
/release patch    # パッチバージョンバンプ（バグ修正）
/release minor    # マイナーバージョンバンプ（新機能）
/release major    # メジャーバージョンバンプ（破壊的変更）
/release --dry-run  # プレビューのみ（実行しない）
/release --announce # Slack 等への告知も実行
```

## Release-only policy

- 通常 PR: `VERSION` / `.claude-plugin/plugin.json` / versioned `CHANGELOG.md` entry は触らない
- 通常 PR の変更履歴: `CHANGELOG.md` の `[Unreleased]` に追記する
- `/release` 実行時だけ version bump、versioned CHANGELOG entry、tag / GitHub Release をまとめて更新する

## ブランチポリシー

- **単独開発**: main への直接 push を許容（CI が品質ゲートとして機能）
- **共同開発**: PR 経由のマージが必須
- force push（`--force` / `--force-with-lease`）は常に禁止

## 実行フロー

### Pre-flight チェック（必須）

```bash
# 1. gh コマンド確認
command -v gh &>/dev/null || echo "⚠️ gh なし: GitHub Release はスキップ"

# 2. 未コミット変更確認
git diff --quiet && git diff --cached --quiet || {
  echo "⚠️ 未コミット変更あり。先にコミットしてください。"
  exit 1
}

# 3. CI 状態確認
gh run list --branch main --limit 3 --json status,conclusion
```

### Step 1: 現在バージョン取得

```bash
CURRENT=$(cat VERSION 2>/dev/null || jq -r '.version' package.json 2>/dev/null)
```

### Step 2: 新バージョン算出

セマンティックバージョニング（SemVer）に従う:
- `patch`: x.y.Z → x.y.(Z+1)（バグ修正）
- `minor`: x.Y.z → x.(Y+1).0（新機能・後方互換）
- `major`: X.y.z → (X+1).0.0（破壊的変更）

### Step 3: CHANGELOG 更新

release entry は、通常 PR で溜めた `[Unreleased]` の変更を versioned section へ確定するつもりで整理する。

**詳細 Before/After フォーマット**（日本語）で記述する。
各機能を番号付きセクションに分け、「今まで」と「今後」を具体例付きで説明する。

```markdown
## [X.Y.Z] - YYYY-MM-DD

### テーマ: [変更全体を一言で]

**[ユーザーにとっての価値を1〜2文で]**

---

#### 1. [機能名]

**今まで**: [旧動作を具体的に。ユーザーが「あるある」と感じる課題描写]

**今後**: [新動作を具体的に。何が解決するか]

```
[実際の出力例やコマンド例]
```

#### 2. [次の機能名]

**今まで**: ...

**今後**: ...
```

**書き方のルール**:

| ルール | 説明 |
|--------|------|
| 言語 | **日本語** |
| 各機能を独立セクションに | `#### N. 機能名` で番号付き |
| 「今まで」は課題描写 | ユーザーが体験していた不便を具体的に書く |
| 「今後」は解決を示す | 何がどう変わるか + 具体例（コード/出力） |
| 具体例を必ず含める | コマンド例、出力例、Plans.md のスニペット等 |
| テクニカル詳細は最小限に | ファイル名やステップ番号は「今後」の補足として |
| 長くてOK | 各機能3〜10行。読みやすさが最優先 |

### Step 4: バージョンファイル更新

```bash
echo "$NEW_VERSION" > VERSION
# package.json がある場合
jq --arg v "$NEW_VERSION" '.version = $v' package.json > tmp && mv tmp package.json
# .claude-plugin/plugin.json がある場合
jq --arg v "$NEW_VERSION" '.version = $v' .claude-plugin/plugin.json > tmp && mv tmp .claude-plugin/plugin.json
```

### Step 5: コミット & タグ

```bash
git add CHANGELOG.md VERSION package.json .claude-plugin/plugin.json
git commit -m "chore: release v$NEW_VERSION"
git tag -a "v$NEW_VERSION" -m "Release v$NEW_VERSION"
git push origin main --tags
```

### Step 6: GitHub Release 作成

```bash
gh release create "v$NEW_VERSION" \
  --title "v$NEW_VERSION - $(head -n 2 CHANGELOG.md | tail -n 1)" \
  --notes "$(cat <<'EOF'
## What's Changed

**[変更の概要]**

### Before / After

| Before | After |
|--------|-------|
| 旧状態 | 新状態 |

---

Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

## GitHub Release Notes フォーマット

必須要素:
- `## What's Changed` セクション
- **太字**の1行サマリー
- Before / After テーブル
- `Generated with [Claude Code](...)` フッター
- 言語: **英語**（日本語禁止）

## PM ハンドオフ

リリース後に PM への完了報告:

```markdown
## リリース完了報告

**バージョン**: v{{NEW_VERSION}}
**リリース日**: {{DATE}}

### 実施内容
{{CHANGELOG の内容}}

### GitHub Release
{{URL}}

### 次のアクション
- PM によるリリースノートの確認
- 本番環境へのデプロイ（該当する場合）
```

## 関連スキル

- `review` — リリース前にコードレビューを実施
- `execute` — リリース後の次のタスクを実装
- `plan` — 次バージョンの計画を作成
