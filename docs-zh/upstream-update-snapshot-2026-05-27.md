# Upstream snapshot - 2026-05-27 (Phase 80)

将 Claude Code `2.1.143`-`2.1.152` 和 Codex `0.131`-`0.134` 作为 Phase 80 盘点，
分类为 Harness 中将采用的项目，仅为 A/C/P/Reject 的记录。

## 确认元数据

| Field | Value |
|-------|-------|
| 确认日 | 2026-05-27 (Asia/Tokyo) |
| Local Claude | `claude --version` → `2.1.152 (Claude Code)` |
| Local Codex | `codex --version` → `codex-cli 0.134.0` |
| harness-mem versions | 双方均为 `up_to_date` (2026-05-27 时点) |
| Observed gap | Claude `2.1.143`-`2.1.152` (10 versions); Codex `0.131`-`0.134` (4 releases) 自 Phase 69 / Phase 67 snapshots 起 |

## 一次信息

| Source | URL |
|--------|-----|
| Claude Code GitHub CHANGELOG | <https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md> |
| Claude Code docs CHANGELOG | <https://code.claude.com/docs/en/changelog> |
| Codex `rust-v0.131.0` | <https://github.com/openai/codex/releases/tag/rust-v0.131.0> (published `2026-05-18T17:39:34Z`) |
| Codex `rust-v0.132.0` | <https://github.com/openai/codex/releases/tag/rust-v0.132.0> |
| Codex `rust-v0.133.0` | <https://github.com/openai/codex/releases/tag/rust-v0.133.0> (published `2026-05-21T16:48:03Z`) |
| Codex `rust-v0.134.0` | <https://github.com/openai/codex/releases/tag/rust-v0.134.0> (published `2026-05-26T19:13:26Z`) |
| Codex compare `0.133→0.134` | <https://github.com/openai/codex/compare/rust-v0.133.0...rust-v0.134.0> |

## 现有 Harness 追従地点

- Claude Code `2.1.133`-`2.1.142` (Phase 69, `docs/upstream-update-snapshot-2026-05-15.md`)
- Codex `0.130.0` stable (Phase 67, `docs/upstream-update-snapshot-2026-05-10.md`)

## 分类规则

- `A: 検証強化 / 採用`: 在 Phase 80 中连接到 docs / rules / tests / settings。
- `C: 自動継承`: 继承 Claude Code / Codex 本体修正。不叠加 Harness wrapper。
- `P: Plans 化`: 有价值但 Phase 80 runtime 实现不做。切为后续 task。
- `Reject`: 与 Harness 方针冲突，或公式 source 中未确认的 subagent claim。
- `B: 書<minimax:tool_call>仅仅`: **0 件**。全部有连接到 A/C/P/Reject 的理由。

## Subagent validation summary

从 Product / Architecture / Local-map / Skeptic 角度将公式 source 和 repo SSOT 交叉验证。
Codex subagent 主张的"granular approval 全面替换""structured codex exec --output-schema 既定化"在
`rust-v0.134.0` release body 中没有明确记载 **Unknown → Reject (Phase 80 中不采用)**。
只有记载在公式 source 上的项目才分类为 A/C/P。

---

## Claude Code version-by-version (`2.1.143`-`2.1.152`)

| Version | Upstream item | Category | Harness action |
|---------|---------------|----------|----------------|
| `2.1.143` | Plugin dependency enforcement on disable/enable | C | 自动继承 |
| `2.1.143` | `worktree.bgIsolation: "none"` | P | enterprise / 非 git VCS 向け docs 候选。Phase 80 中不改变 template |
| `2.1.143` | PowerShell `-ExecutionPolicy Bypass` default | C | 自动继承 |
| `2.1.144` | `/resume` for background sessions | C | 自动继承 |
| `2.1.144` | Sandbox worktree allowlist fix (shared `.git` only) | C | 自动继承。Harness worktree policy 维持 Phase 69 baseline |
| `2.1.145` | `claude agents --json` | A | 在 `docs/agent-view-policy.md` 中追记 diagnostic / scripting 用途 |
| `2.1.145` | `claude plugin validate` flags `skills:` pointing at file not directory | A | 强化 `.claude/rules/skill-editing.md` + validate guidance |
| `2.1.145` | Stop/SubagentStop `background_tasks` / `session_crons` hook input | C | 自动继承 |
| `2.1.147` | `/simplify` renamed to `/code-review`; cleanup behavior removed | A | 保留历史 CHANGELOG，新 docs/rules 参照 `/code-review`。`/code-review --fix` 为 operator-local spike |
| `2.1.147` | Pinned background sessions stay alive + restart in place | C | 自动继承 |
| `2.1.149` | Sandbox write allowlist in git worktrees scoped to `.git` shared dir | C | 自动继承 |
| `2.1.149` | PowerShell permission bypass fixes | C | 自动继承 |
| `2.1.150` | Internal infrastructure only | C | 自动继承 |
| `2.1.152` | Skill/slash `disallowed-tools` frontmatter | A | `.claude/rules/skill-frontmatter-2.1.152-plus.md` + skill-editing SSOT |
| `2.1.152` | `/reload-skills` command | A | `CLAUDE.md` + skill-editing: `/reload-skills` 与 `/reload-plugins` 的区分使用 |
| `2.1.152` | `SessionStart.reloadSkills: true` | A | hooks rules: 在同一 session 中启用 hook 安装的 skill |
| `2.1.152` | `hookSpecificOutput.sessionTitle` on SessionStart | A | hooks rules: 仅 opt-in session title，不将 secret 放入 title |
| `2.1.152` | `MessageDisplay` hook event | A | `docs/message-display-policy.md`: 带 audit 的 opt-in，禁止默示改写 |
| `2.1.152` | Auto mode no longer requires opt-in consent | A | adoption plan: 不以 upstream 缓和为由将 Harness `--auto-mode` 默认化或缓和 hard_deny |
| `2.1.152` | `/code-review --fix` applies findings to working tree | P | 因是 working-tree write，在自动 DoD 外。为 operator-local spike |
| `2.1.152` | `pluginSuggestionMarketplaces` managed setting | P | enterprise admin 向け。Harness 配布 template 中未设置 |
| `2.1.152` | Fallback model for rest of session when primary not found | C | 自动继承 |

---

## Codex version-by-version (`0.131`-`0.134`)

| Version | Upstream item | Category | Harness action |
|---------|---------------|----------|----------------|
| `0.131.0` | `codex doctor` diagnostics | P | operator docs 候选。不集成到 companion 既定 route |
| `0.131.0` | `@` mentions unified picker (files/plugins/skills) | C | 自动继承 |
| `0.131.0` | Plugin marketplace CLI + default-enabled plugin hooks | C | 自动继承。维持 Harness 不推测生成 inline hook 的方针 |
| `0.133.0` | Goals enabled by default + dedicated storage | C | 自动继承。维持 Harness Plans.md SSOT (`/goal` policy 继续) |
| `0.133.0` | Permission profiles list APIs + managed `requirements.toml` | A | 将 `docs/codex-permission-profiles-policy.md` 更新到 0.134 `--profile` primary |
| `0.133.0` | AGENTS instruction loading reliability | A | 更新 `codex/AGENTS.md` 的 discovery 注记 |
| `0.134.0` | `--profile` primary selector; legacy profile configs rejected | A | setup/companion/docs: 以 `--profile` 为 primary，在新 docs 中不推荐 legacy selector |
| `0.134.0` | MCP per-server environment targeting + OAuth for streamable HTTP | P | MCP setup docs 候选。Harness 配布 default MCP 中不写 secret |
| `0.134.0` | Connector schema `$ref`/`$defs` preservation + compaction | C | 自动继承 |
| `0.134.0` | Read-only MCP tools parallel when `readOnlyHint` | C | 自动继承 |
| `0.134.0` | Subagent identity in hook inputs | C | 自动继承 |
| `0.134.0` | Plugin skills reuse plugin-level icon assets | C | 自动继承 |
| `0.134.0` | curl/PowerShell installer docs in README | A | `scripts/setup-codex.sh` header + `codex/AGENTS.md` install 节 |
| `0.134.0` | Managed network proxy for Node-based tools | C | 自动继承 |
| `0.134.0` | Release packaging simplification (native artifacts) | C | 自动继承。Harness release artifact gate 为别 phase |
| Unknown (subagent) | Granular approval replaces `on-failure` everywhere | Reject | 公式 `0.134.0` body 未记载。Phase 80 中仅不推荐新推荐 `on-failure` |
| Unknown (subagent) | `codex exec --output-schema` as default companion route | Reject | 公式 release body 未记载。companion 不恢复为 raw exec default |

---

## Phase 80 implementation tiers

### Tier 1 — Claude runtime / skill-hook (80.1.3)

| ID | Artifact |
|----|----------|
| 80.1.3a | `.claude/rules/skill-frontmatter-2.1.152-plus.md` (`disallowed-tools`) |
| 80.1.3b | `.claude/rules/hooks-2.1.152-plus.md` (`MessageDisplay`, `sessionTitle`, `reloadSkills`) |
| 80.1.3c | `docs/message-display-policy.md` |
| 80.1.3d | `CLAUDE.md` `/reload-skills` 与 `/reload-plugins` |
| 80.1.3e | `docs/agent-view-policy.md` (`claude agents --json`) |
| 80.1.3f | `.claude/rules/skill-editing.md` (`allowed-tools` vs `disallowed-tools` 误解修正) |

### Tier 2 — Codex native config / companion (80.1.4)

| ID | Artifact |
|----|----------|
| 80.1.4a | `docs/codex-permission-profiles-policy.md` (`--profile` primary, `on-failure` 非推荐) |
| 80.1.4b | `codex/.codex/config.toml` 0.134 comments |
| 80.1.4c | `scripts/setup-codex.sh` curl/PowerShell installer note |
| 80.1.4d | `codex/AGENTS.md` install + profile guidance |

### Tier 3 — SSOT / validation (80.1.5-80.1.6)

| ID | Artifact |
|----|----------|
| 80.1.5a | `docs/CLAUDE-feature-table.md` Phase 80 row |
| 80.1.5b | `CHANGELOG.md` `[Unreleased]` |
| 80.1.6a | `tests/test-claude-upstream-integration.sh` Phase 80 detection |

## B: 書<minimax:tool_call>仅仅 0 件

所有行已分类为 A (连接到 Harness artifact)、C (本体继承)、P (后续 Plans)、Reject (未确认 claim) 之一。
未创建只写在 Feature Table 上不连接到 file/test 的项目。
