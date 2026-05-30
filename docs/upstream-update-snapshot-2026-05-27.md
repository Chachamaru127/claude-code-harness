# Upstream snapshot - 2026-05-27 (Phase 80)

Claude Code `2.1.143`-`2.1.152` と Codex `0.131`-`0.134` を Phase 80 として棚卸しし、
Harness に採る item だけを A/C/P/Reject に分類した記録です。

## 確認メタデータ

| Field | Value |
|-------|-------|
| 確認日 | 2026-05-27 (Asia/Tokyo) |
| Local Claude | `claude --version` → `2.1.152 (Claude Code)` |
| Local Codex | `codex --version` → `codex-cli 0.134.0` |
| harness-mem versions | 両方 `up_to_date` (2026-05-27 時点) |
| Observed gap | Claude `2.1.143`-`2.1.152` (10 versions); Codex `0.131`-`0.134` (4 releases) since Phase 69 / Phase 67 snapshots |

## 一次情報

| Source | URL |
|--------|-----|
| Claude Code GitHub CHANGELOG | <https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md> |
| Claude Code docs CHANGELOG | <https://code.claude.com/docs/en/changelog> |
| Codex `rust-v0.131.0` | <https://github.com/openai/codex/releases/tag/rust-v0.131.0> (published `2026-05-18T17:39:34Z`) |
| Codex `rust-v0.132.0` | <https://github.com/openai/codex/releases/tag/rust-v0.132.0> |
| Codex `rust-v0.133.0` | <https://github.com/openai/codex/releases/tag/rust-v0.133.0> (published `2026-05-21T16:48:03Z`) |
| Codex `rust-v0.134.0` | <https://github.com/openai/codex/releases/tag/rust-v0.134.0> (published `2026-05-26T19:13:26Z`) |
| Codex compare `0.133→0.134` | <https://github.com/openai/codex/compare/rust-v0.133.0...rust-v0.134.0> |

## 既存 Harness 追従地点

- Claude Code `2.1.133`-`2.1.142` (Phase 69, `docs/upstream-update-snapshot-2026-05-15.md`)
- Codex `0.130.0` stable (Phase 67, `docs/upstream-update-snapshot-2026-05-10.md`)

## 分類ルール

- `A: 検証強化 / 採用`: Phase 80 で docs / rules / tests / settings に接続する。
- `C: 自動継承`: Claude Code / Codex 本体修正。Harness wrapper を重ねない。
- `P: Plans 化`: 価値はあるが Phase 80 runtime 実装はしない。後続 task へ。
- `Reject`: Harness 方針と衝突、または公式 source で未確認の subagent claim。
- `B: 書いただけ`: **0 件**。すべて A/C/P/Reject に接続する理由を持つ。

## Subagent validation summary

Product / Architecture / Local-map / Skeptic 視点で公式 source と repo SSOT を突き合わせた。
Codex subagent が主張した「granular approval 全面置換」「structured codex exec --output-schema 既定化」は
`rust-v0.134.0` release body に明示がなく **Unknown → Reject (Phase 80 では採用しない)** とした。
公式 source に載る item のみ A/C/P に分類する。

---

## Claude Code version-by-version (`2.1.143`-`2.1.152`)

| Version | Upstream item | Category | Harness action |
|---------|---------------|----------|----------------|
| `2.1.143` | Plugin dependency enforcement on disable/enable | C | 自動継承 |
| `2.1.143` | `worktree.bgIsolation: "none"` | P | enterprise / non-git VCS 向け docs 候補。Phase 80 では template 変更なし |
| `2.1.143` | PowerShell `-ExecutionPolicy Bypass` default | C | 自動継承 |
| `2.1.144` | `/resume` for background sessions | C | 自動継承 |
| `2.1.144` | Sandbox worktree allowlist fix (shared `.git` only) | C | 自動継承。Harness worktree policy は Phase 69 baseline 維持 |
| `2.1.145` | `claude agents --json` | A | `docs/agent-view-policy.md` に diagnostic / scripting 用途を追記 |
| `2.1.145` | `claude plugin validate` flags `skills:` pointing at file not directory | A | `.claude/rules/skill-editing.md` + validate guidance を強化 |
| `2.1.145` | Stop/SubagentStop `background_tasks` / `session_crons` hook input | C | 自動継承 |
| `2.1.147` | `/simplify` renamed to `/code-review`; cleanup behavior removed | A | 歴史 CHANGELOG は残し、新 docs/rules は `/code-review` を参照。`/code-review --fix` は operator-local spike |
| `2.1.147` | Pinned background sessions stay alive + restart in place | C | 自動継承 |
| `2.1.149` | Sandbox write allowlist in git worktrees scoped to `.git` shared dir | C | 自動継承 |
| `2.1.149` | PowerShell permission bypass fixes | C | 自動継承 |
| `2.1.150` | Internal infrastructure only | C | 自動継承 |
| `2.1.152` | Skill/slash `disallowed-tools` frontmatter | A | `.claude/rules/skill-frontmatter-2.1.152-plus.md` + skill-editing SSOT |
| `2.1.152` | `/reload-skills` command | A | `CLAUDE.md` + skill-editing: `/reload-skills` vs `/reload-plugins` 使い分け |
| `2.1.152` | `SessionStart.reloadSkills: true` | A | hooks rules: hook インストール skill を同一 session で有効化 |
| `2.1.152` | `hookSpecificOutput.sessionTitle` on SessionStart | A | hooks rules: opt-in session title のみ、secret を title に入れない |
| `2.1.152` | `MessageDisplay` hook event | A | `docs/message-display-policy.md`: audit 付き opt-in、黙示改変禁止 |
| `2.1.152` | Auto mode no longer requires opt-in consent | A | adoption plan: upstream 緩和を理由に Harness `--auto-mode` default 化や hard_deny 緩和しない |
| `2.1.152` | `/code-review --fix` applies findings to working tree | P | working-tree write のため自動 DoD 外。operator-local spike |
| `2.1.152` | `pluginSuggestionMarketplaces` managed setting | P | enterprise admin 向け。Harness 配布 template では未設定 |
| `2.1.152` | Fallback model for rest of session when primary not found | C | 自動継承 |

---

## Codex version-by-version (`0.131`-`0.134`)

| Version | Upstream item | Category | Harness action |
|---------|---------------|----------|----------------|
| `0.131.0` | `codex doctor` diagnostics | P | operator docs 候補。companion 既定 route には組み込まない |
| `0.131.0` | `@` mentions unified picker (files/plugins/skills) | C | 自動継承 |
| `0.131.0` | Plugin marketplace CLI + default-enabled plugin hooks | C | 自動継承。Harness は inline hook 推測生成しない方針維持 |
| `0.133.0` | Goals enabled by default + dedicated storage | C | 自動継承。Harness Plans.md SSOT は維持 (`/goal` policy 継続) |
| `0.133.0` | Permission profiles list APIs + managed `requirements.toml` | A | `docs/codex-permission-profiles-policy.md` を 0.134 `--profile` primary に更新 |
| `0.133.0` | AGENTS instruction loading reliability | A | `codex/AGENTS.md` の discovery 注記を更新 |
| `0.134.0` | `--profile` primary selector; legacy profile configs rejected | A | setup/companion/docs: `--profile` を primary に、legacy selector を新規 docs で推奨しない |
| `0.134.0` | MCP per-server environment targeting + OAuth for streamable HTTP | P | MCP setup docs 候補。Harness 配布 default MCP には secret を書かない |
| `0.134.0` | Connector schema `$ref`/`$defs` preservation + compaction | C | 自動継承 |
| `0.134.0` | Read-only MCP tools parallel when `readOnlyHint` | C | 自動継承 |
| `0.134.0` | Subagent identity in hook inputs | C | 自動継承 |
| `0.134.0` | Plugin skills reuse plugin-level icon assets | C | 自動継承 |
| `0.134.0` | curl/PowerShell installer docs in README | A | `scripts/setup-codex.sh` header + `codex/AGENTS.md` install 節 |
| `0.134.0` | Managed network proxy for Node-based tools | C | 自動継承 |
| `0.134.0` | Release packaging simplification (native artifacts) | C | 自動継承。Harness release artifact gate は別 phase |
| Unknown (subagent) | Granular approval replaces `on-failure` everywhere | Reject | 公式 `0.134.0` body に未記載。Phase 80 では `on-failure` を新規推奨しないのみ |
| Unknown (subagent) | `codex exec --output-schema` as default companion route | Reject | 公式 release body に未記載。companion は raw exec default に戻さない |

---

## Phase 80 implementation tiers

### Tier 1 — Claude runtime / skill-hook (80.1.3)

| ID | Artifact |
|----|----------|
| 80.1.3a | `.claude/rules/skill-frontmatter-2.1.152-plus.md` (`disallowed-tools`) |
| 80.1.3b | `.claude/rules/hooks-2.1.152-plus.md` (`MessageDisplay`, `sessionTitle`, `reloadSkills`) |
| 80.1.3c | `docs/message-display-policy.md` |
| 80.1.3d | `CLAUDE.md` `/reload-skills` vs `/reload-plugins` |
| 80.1.3e | `docs/agent-view-policy.md` (`claude agents --json`) |
| 80.1.3f | `.claude/rules/skill-editing.md` (`allowed-tools` vs `disallowed-tools` 誤解修正) |

### Tier 2 — Codex native config / companion (80.1.4)

| ID | Artifact |
|----|----------|
| 80.1.4a | `docs/codex-permission-profiles-policy.md` (`--profile` primary, `on-failure` 非推奨) |
| 80.1.4b | `codex/.codex/config.toml` 0.134 comments |
| 80.1.4c | `scripts/setup-codex.sh` curl/PowerShell installer note |
| 80.1.4d | `codex/AGENTS.md` install + profile guidance |

### Tier 3 — SSOT / validation (80.1.5-80.1.6)

| ID | Artifact |
|----|----------|
| 80.1.5a | `docs/CLAUDE-feature-table.md` Phase 80 row |
| 80.1.5b | `CHANGELOG.md` `[Unreleased]` |
| 80.1.6a | `tests/test-claude-upstream-integration.sh` Phase 80 detection |

## B: 書いただけ 0 件

すべての行が A (Harness artifact 接続)、C (本体継承)、P (後続 Plans)、Reject (未確認 claim) のいずれかに分類済み。
Feature Table だけに書いて file/test に接続しない項目は作っていない。
