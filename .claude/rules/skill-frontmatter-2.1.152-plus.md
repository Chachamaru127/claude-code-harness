# Skill Frontmatter (Claude Code 2.1.152+) Rules

CC `2.1.152` で skill / slash command frontmatter に `disallowed-tools` が追加された。
skill 活性中だけ model から特定 tool を除外できる。

## `allowed-tools` vs `disallowed-tools`

| Field | 意味 | 誤解しやすい点 |
|-------|------|----------------|
| `allowed-tools` | skill が **使ってよい** tool の allowlist (従来) | restriction list ではない |
| `disallowed-tools` | skill 活性中に model から **除外する** tool (2.1.152+) | permission deny ではない。skill 非活性時は復帰 |

permission deny / ask は `.claude-plugin/settings.json` と guardrail (R01-R13) が担当する。
`disallowed-tools` は skill scope の model tool surface 調整のみ。

## 推奨パターン

### Read-only 判定 skill

```yaml
disallowed-tools: ["Write", "Edit", "MultiEdit", "Bash"]
```

`disable-model-invocation: true` より柔軟。Skill tool 経由起動は維持しつつ write を抑止できる。

### Dangerous side-effect skill

従来通り `disable-model-invocation: true` を優先。
追加で Bash だけ外したい場合に `disallowed-tools: ["Bash"]` を併用してよい。

## 禁止

- `disallowed-tools` で `Skill` 自身を除外し Skill tool 起動を壊す設定
- guard rail で deny すべき tool を `disallowed-tools` だけに頼る (多層防御を弱めない)
- `allowed-tools` を空にして「全部禁止」と解釈する運用

## `/reload-skills`

skill frontmatter を編集した後、同一 session で反映するには `/reload-skills`。
plugin 側変更は `/reload-plugins` (詳細: `.claude/rules/hooks-2.1.152-plus.md`)。

## 関連

- `.claude/rules/skill-editing.md`
- `docs/upstream-update-snapshot-2026-05-27.md`
