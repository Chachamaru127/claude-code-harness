---
name: release
description: "Automates release process: CHANGELOG update, version bump, and tag creation. Use when user mentions release, version bump, or tag creation. Do NOT load for: release planning discussions, version number mentions, 'ship it' casual talk."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[patch|minor|major]"
disable-model-invocation: true
---

# Release Skill

Automates the claude-code-harness release process.

## Quick Reference

- "**Release a new version**" → `/release`
- "**Bump patch version**" → `/release patch`
- "**Create a minor release**" → `/release minor`

---

## Execution Flow

### Step 1: Change Verification

Run in parallel:
1. `git status` - Check uncommitted changes
2. `git diff --stat` - List changed files
3. `git log --oneline -10` - Recent commit history

### Step 2: Version Determination

Check current version:
```bash
cat VERSION
```

Determine version based on changes ([Semantic Versioning](https://semver.org/)):
- **patch** (x.y.Z): Bug fixes, minor improvements
- **minor** (x.Y.0): New features (backward compatible)
- **major** (X.0.0): Breaking changes

Ask user: "What should the next version be? (e.g., 2.5.23)"

### Step 3: CHANGELOG Update (JP + EN)

> **⚠️ 重要**: ユーザー体験に影響する変更を中心に記載。内部修正は簡潔に。

Update both `CHANGELOG_ja.md` and `CHANGELOG.md`.

#### CHANGELOG 記載ルール

| 変更タイプ | 記載方法 |
|-----------|---------|
| **ユーザー体験に影響** | `🎯 What's Changed for You` + Before/After テーブル |
| **新機能追加** | `Added` セクションで簡潔に |
| **内部修正（CI/テスト/ドキュメント）** | `Internal` セクションで1行のみ |
| **バグ修正（ユーザー影響あり）** | `Fixed` セクション |
| **バグ修正（内部のみ）** | 省略または `Internal` に統合 |

#### テンプレート

```markdown
## [X.Y.Z] - YYYY-MM-DD

### 🎯 What's Changed for You

**ユーザー体験の変化を1行で説明**

| Before | After |
|--------|-------|
| 変更前の状態 | 変更後の状態 |

### Added

- 新機能の簡潔な説明

### Internal

- 内部修正の1行サマリー
```

#### Before/After テーブルのルール

- **体験が変わる変更のみ** Before/After を記載
- 内部修正（CI、テスト、リファクタリング）には不要
- 技術詳細ではなく **ユーザー視点の変化** を記載

#### 悪い例 vs 良い例

```markdown
❌ 悪い例（技術詳細すぎる）:
- **agents/*.md**: スキル参照を更新（`review` → `harness-review`）
- **CI: validate-plugin.sh** が Skills 移行後も正常動作するように修正

✅ 良い例（ユーザー視点）:
### Internal
- CI/テスト/ドキュメントを Skills 移行後の構造に更新
```

### Step 3.5: README Update Check

> Check if README needs update (JP/EN both)

### Step 4: Version File Update

```bash
echo "X.Y.Z" > VERSION
```

Also update `.claude-plugin/plugin.json`:
```json
"version": "X.Y.Z"
```

### Step 5: Commit and Tag

```bash
git add -A
git commit -m "chore: release vX.Y.Z"
git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

### Step 6: Push

```bash
git push origin main
git push origin vX.Y.Z
```

### Step 7: GitHub Release (Optional)

```bash
gh release create vX.Y.Z \
  --title "vX.Y.Z - Title" \
  --notes "$(cat <<'EOF'
## 🎯 What's Changed for You

**ユーザー体験の変化を1行で**

| Before | After |
|--------|-------|
| 変更前 | 変更後 |

### Added / Changed / Fixed

- 簡潔な説明

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## GitHub Release Format

Follow `.claude/rules/github-release.md`:

```markdown
## 🎯 What's Changed for You

**One-line value description**

| Before | After |
|--------|-------|
| Previous state | New state |

### Added / Changed / Fixed

- Brief description

---

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

---

## Related Skills

- `verify` - Pre-release verification
