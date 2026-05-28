# Hooks (Claude Code 2.1.152+) Rules

CC `2.1.152` で追加された `MessageDisplay`、`SessionStart.reloadSkills`、
`hookSpecificOutput.sessionTitle` (SessionStart resume 含む) の Harness 取り扱い SSOT。

Phase 80 (`docs/upstream-update-snapshot-2026-05-27.md`) で導入。
既存 `.claude/rules/hooks-2.1.139-plus.md` と併読する。

## 1. `SessionStart.reloadSkills: true`

### 動作

SessionStart hook の JSON 出力に `reloadSkills: true` を返すと、
同一 session 内で skill ディレクトリが再スキャンされる。
hook が skill を install した直後に `/reload-skills` 相当の反映ができる。

### Harness 利用条件

- 許可: setup hook が **新規 skill ファイル** を `${CLAUDE_SKILL_DIR}` 配下に書き込んだ後、
  同一 turn で skill を使う必要がある場合のみ opt-in。
- 禁止: 毎 SessionStart で無条件 `reloadSkills: true` (cache churn / token コスト増)。
- secret や `.env` を含む path を skill として install しない。

## 2. `hookSpecificOutput.sessionTitle`

### 動作

SessionStart (startup / resume) で session title を設定できる。

### Harness 利用条件

- 許可: project 名 + task phase 等の **非 secret** 識別子のみ。
- 禁止: API key、token、`.env` 値、ユーザー PII、未 redact の file path (home 配下 absolute path)。

## 3. `MessageDisplay` hook event

詳細 policy: `docs/message-display-policy.md`

Harness 配布 hooks では Phase 80 時点 **未使用**。
operator が追加する場合は audit 要件と hide/transform 禁止リストに従う。

## 4. `/reload-skills` vs `/reload-plugins`

| Command | 用途 |
|---------|------|
| `/reload-skills` | skill ディレクトリ再スキャン (skill 編集後) |
| `/reload-plugins` | plugin bundle / runtime cache 再読込 (plugin manifest / hooks 変更後) |

skill のみ変更した場合は `/reload-skills` を先に試す。
`.claude-plugin/` や plugin hooks を変更した場合は `/reload-plugins` を使う。

## 関連

- `.claude/rules/skill-frontmatter-2.1.152-plus.md`
- `docs/message-display-policy.md`
- `CLAUDE.md` (Development Flow step 0)
