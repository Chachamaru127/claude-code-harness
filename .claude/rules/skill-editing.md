# Skill File Editing Rules

SSOT (Single Source of Truth) rules for editing skill files (`skills/<skill-name>/`).

> **Note**: As of v2.17.0, custom slash commands have been migrated to skills.
> Skills are the preferred approach for new functionality.

## SSOT Principles

### 1. Directory Structure

Each skill lives in its own directory:

```
skills/
└── <skill-name>/
    ├── SKILL.md           # Main skill definition (required)
    └── references/        # Supporting files (optional)
        ├── feature1.md
        ├── feature2.md
        └── ...
```

> **CC v2.1.69+ 推奨**: `SKILL.md` から参照ファイルへリンクする場合は、
> `references/...` の相対パスではなく `${CLAUDE_SKILL_DIR}/references/...` を使用する。
> これにより、スキル実行場所に依存せず安定して参照できる。

### 2. YAML Frontmatter Format (Required)

**All SKILL.md files must use this frontmatter**:

```yaml
---
name: skill-name
description: "English description for auto-loading. Include trigger phrases."
description-ja: "日本語の説明。トリガーフレーズを含む。"
allowed-tools: ["Read", "Write", "Edit", "Bash", ...]
---
```

### 3. Available Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (matches directory name) |
| `description` | Yes | English description for auto-loading (include trigger phrases). Token-efficient. |
| `description-ja` | Recommended | Japanese description for i18n. Use `scripts/set-locale.sh ja` to swap into `description`. |
| `allowed-tools` | No | Tools the skill can use (allowlist — not a restriction list) |
| `disallowed-tools` | No | CC 2.1.152+: tools to remove from the model while the skill is active |
| `argument-hint` | No | Usage hint (e.g., `"[option1|option2]"`) |
| `disable-model-invocation` | No | Set `true` for dangerous operations |
| `user-invocable` | No | Set `false` for internal-only skills |
| `context` | No | `fork` for isolated context |
| `hooks` | No | Event hooks configuration |

### 4. File Size Guidelines

| Guideline | Recommendation |
|-----------|----------------|
| SKILL.md | 推奨 500 行以下 |
| Large content | Split into `references/` files |
| References | Use descriptive filenames |

> **Note (CC 2.1.32+)**: スキルの文字バジェットはコンテキスト窓の **2%** に自動スケールされます。
> 500 行はあくまで推奨値であり、実効上限はモデルのコンテキスト窓サイズに依存します。
> 大きなスキルファイルは自動的にトリミングされる可能性があるため、
> 重要な情報は SKILL.md の先頭付近に配置し、詳細は `references/` に分割してください。

### 5. Description Best Practices

The `description` field is critical for auto-loading. Include:
- What the skill does
- Trigger phrases (e.g., "Use when user mentions...")
- What NOT to load for (e.g., "Do NOT load for: ...")

**Good example**:
```yaml
description: "Manages CI/CD failures. Use when user mentions CI failures, build errors, or test failures. Do NOT load for: local builds or standard implementation."
```

**Bad example**:
```yaml
description: "CI skill"
```

## Skill File Structure Template

### SKILL.md Template

```markdown
---
name: skill-name
description: "Description with trigger phrases. Use when... Do NOT load for..."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
argument-hint: "[subcommand|option]"
---

# Skill Name

Overview description of the skill.

## Quick Reference

- "**trigger phrase 1**" → this skill
- "**trigger phrase 2**" → this skill

## Features / Deliverables

| Feature | Reference |
|---------|-----------|
| **Feature 1** | See [feature1.md](${CLAUDE_SKILL_DIR}/references/feature1.md) |
| **Feature 2** | See [feature2.md](${CLAUDE_SKILL_DIR}/references/feature2.md) |

## Execution Flow

1. Parse user request
2. Load appropriate reference file
3. Execute steps from reference
4. Report results

## Related Skills

- `related-skill-1` - Description
- `related-skill-2` - Description
```

### Reference File Template

```markdown
# Feature Name Reference

Detailed documentation for this feature.

## When to Use

- Condition 1
- Condition 2

## Execution Steps

### Step 1: ...

### Step 2: ...

## Examples

### Example 1

...

## Troubleshooting

### Issue 1

**Cause**: ...
**Solution**: ...
```

## Editing Checklist

When creating or editing skill files:

- [ ] SKILL.md has required frontmatter (`name`, `description`)
- [ ] `name` matches directory name
- [ ] `description` includes trigger phrases and exclusions
- [ ] SKILL.md は推奨 500 行以下 (use references for large content; 2% budget scaling applies)
- [ ] References are under `references/` and linked via `${CLAUDE_SKILL_DIR}/references/...`
- [ ] Related skills documented
- [ ] Add entry to CHANGELOG.md (for new skills)
- [ ] Bump VERSION (automatic or manual)

## Migration from Commands

Commands have been migrated to skills. Key differences:

| Aspect | Commands (Legacy) | Skills (Current) |
|--------|-------------------|------------------|
| Location | `commands/` | `skills/` |
| Structure | Single file | Directory with SKILL.md + references |
| Frontmatter | `description` only | Full skill configuration |
| Auto-loading | Limited | Full description-based matching |
| Supporting files | Not supported | `references/` subdirectory |

## `context: fork` + `disable-model-invocation: true` 時の auto-start pattern

`context: fork` を持つスキルは isolated context で動作し、host project の CLAUDE.md を継承しない。
しかし実際には host session-start rules が fork 先に漏れ込み、スキルが「タスクが不明確」で停止する
現象が通算 6 回観測された (Issue #84)。このセクションはその対策パターンを定義する。

### fork 継承の仕様

- `context: fork` スキルは起動時に新しい isolated context を作成する
- 親セッションの CLAUDE.md / session-start rules は原則として継承されない
- ただし CC の実装上、host project の rules が fork 先に流入するケースが確認されている (#84)
- 流入した rules が「まず明確な指示を確認する」等の停止トリガーとして働く

### auto-start pattern の実装ガイド

`context: fork` スキルで即時自動開始が必要な場合、以下の 3 点を SKILL.md の Step 0 冒頭に実装する:

#### (1) 最冒頭 3 行以内に機械可読条件を literal に配置する

```
if $ARGUMENTS == "":
  → {自動処理の内容} を開始する
  → 「タスクが不明確」「追加の指示を待つ」は禁止行動
```

この条件ブロックを Step 0 見出しの直下 3 行以内に置くことで、
他のルールが流入しても機械的に条件分岐が先に読まれることを保証する。

#### (2) 禁止行動を明示列挙する

停止パターンを具体的な文言で 3 項目以上列挙する。
曖昧な「停止するな」ではなく、観測されたパターン（「タスクが不明確」「追加の指示をお待ちします」等）
を literal に列挙することで、host rules の override を文言レベルで上書きする。

#### (3) `*_AUTOSTART` marker の契約を明記する

引数なしで呼ばれた時、最初の応答に識別マーカーを必ず出力する契約を書く:

```
REVIEW_AUTOSTART: base_ref={ref}, type=code
```

この契約は次の効果を持つ:
- 人間・監視スクリプトが自動開始を確認できる
- marker を出力するという行動契約が、応答の最初の一手を「停止」から「実行」に固定する
- `grep -c 'REVIEW_AUTOSTART' skills/*/SKILL.md` で実装漏れを検査できる

### 参考: harness-review の実装例

`skills/harness-review/SKILL.md` Step 0 が上記 3 パターンのリファレンス実装。
同様の問題が他のスキルで発生した場合は同じパターンを適用する。

## Related Documentation

- [Claude Code Skills Documentation](https://code.claude.com/docs/en/skills)
- [command-editing.md](./command-editing.md) - Legacy command rules (deprecated)
- [CLAUDE.md](../../CLAUDE.md) - Project Development Guide
