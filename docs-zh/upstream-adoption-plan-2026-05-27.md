# Phase 80 Upstream Adoption Plan - 2026-05-27

关于 Claude Code `2.1.143`-`2.1.152` 和 Codex `0.131`-`0.134` 如何在 Harness 中采用的采用判断 SSOT。
依据 snapshot: `docs/upstream-update-snapshot-2026-05-27.md`

## 採用サマリー

| Decision | Count | 方針 |
|----------|-------|------|
| **Adopt** | Claude 8 / Codex 4 | 连接到 docs / rules / tests |
| **Auto-inherit** | Claude 12 / Codex 10 | 仅本体修正。不追加 Harness wrapper |
| **Defer** | Claude 4 / Codex 3 | enterprise 或 operator-local。Phase 80 实现外 |
| **Reject** | 2 | 公式 source 未确认的 subagent claim |

## Claude Code 採用判断

| Item | Decision | Why |
|------|----------|-----|
| `disallowed-tools` skill frontmatter | **Adopt** | 在 dangerous side-effect skill 中可以仅在 skill 激活中移除 Write/Bash。比 `disable-model-invocation` 更细粒度。在 `.claude/rules/skill-frontmatter-2.1.152-plus.md` 中 SSOT 化 |
| `/reload-skills` | **Adopt** | skill 编辑后反映到同一 session。plugin cache 保持为 `/reload-plugins` (`CLAUDE.md`) |
| `SessionStart.reloadSkills` | **Adopt** | hook 安装 skill 后可以在同一 session 中启用。条件是 secret 不包含在 hook 输出中 |
| `hookSpecificOutput.sessionTitle` | **Adopt** | operator UX 改进。只设 rule 不将 secret / PII 放入 session title |
| `MessageDisplay` | **Adopt (opt-in)** | 仅带 audit 的显示辅助。在 Harness 既定 hook 中禁止 assistant output 的默示改写·隐藏 (`docs/message-display-policy.md`) |
| Auto mode consent 廃止 | **Defer (维持 Harness default)** | 即使 upstream 缓和了 opt-in 屏障，Harness 也不将 `--auto-mode` 默认化或缓和 `autoMode.hard_deny` |
| `/simplify` → `/code-review` | **Adopt** | 新参照为 `/code-review`。`/code-review --fix` 因是 working-tree write，为 operator-local spike |
| `claude agents --json` | **Adopt** | 仅用于 diagnostic / scripting。不作为 teammate spawn 替代 |
| `claude plugin validate` skills directory check | **Adopt** | 与 skill-editing SSOT 整合。维持 Harness `skills/` 配下 directory SSOT |
| `pluginSuggestionMarketplaces` | **Defer** | enterprise admin 设置。Harness 配布 template 中未设置 |
| Sandbox / worktree / PowerShell fixes | **Auto-inherit** | CC 本体修正。与 Phase 69 baseline 无矛盾 |

## Codex 採用判断

| Item | Decision | Why |
|------|----------|-----|
| `--profile` primary 化 | **Adopt** | 在 companion / setup docs 中以 `--profile` 为主。在新 docs 中不推荐 legacy profile v1 selector |
| `on-failure` approval deprecation | **Defer** | 在新 docs/config 中不推荐 `on-failure`。现有 companion 保持 `--ask-for-approval on-request` 等 |
| MCP environment targeting / OAuth | **Defer** | operator MCP 设置 docs 候选。Harness 配布 default 中不写 secret |
| Read-only MCP parallel (`readOnlyHint`) | **Auto-inherit** | 本体优化。不改变 Harness companion policy |
| Connector schema `$ref`/`$defs` | **Auto-inherit** | 本体修正 |
| Subagent identity hook input | **Auto-inherit** | 本体修正。与 Harness Claude hook path 独立 |
| curl/PowerShell installer | **Adopt** | 在 `scripts/setup-codex.sh` / `codex/AGENTS.md` install 节中追记公式 installer URL |
| `--full-auto` / raw `codex exec` default | **Reject (regression)** | 维持 companion policy。不恢复为 default route |
| Granular approval 全面替换 (subagent claim) | **Reject** | 公式 `0.134.0` release body 未确认 |
| `codex exec --output-schema` default (subagent claim) | **Reject** | 公式 release body 未确认 |

## Support-tier / supply-chain gates

| Surface | Tier | Phase 80 action |
|---------|------|-----------------|
| Codex CLI | `internal-compatible` | 维持。README / tool-capability-matrix 不过大主张 |
| Codex app | `candidate` | 维持。不以 CLI help 为 app support 依据 |
| Claude Code | `supported` | Phase 80 Claude items 通过 rules/docs/tests 追従 |
| `claude-codex-upstream-update` skill | **local-only operator tooling** | 不昇格为配布 surface。marketplace 同梱维持现状，不主张 public support |

## Security / threat model highlights

1. **MessageDisplay**: transform/hide 仅为 opt-in hook。不隐藏 R01-R13 guard rail 输出。
2. **Auto mode consent 廃止**: Harness `breezing --auto-mode` 保持 opt-in rollout。 不缓和 `templates/claude/settings.security.json.template` 的 `autoMode.hard_deny` baseline。
3. **Codex profile migration**: 在 Harness 新规 docs 中不推荐 legacy profile config。users 使用 `--profile` + explicit sandbox。
4. **Installers**: curl/PowerShell installer 仅指向公式 GitHub release asset。Harness 不配布 third-party mirror。

## Verification

- `bash tests/test-spec-ssot-workflow.sh`
- `bash tests/test-claude-upstream-integration.sh`
- `bash tests/test-codex-package.sh`
- `bash tests/test-tool-capability-matrix.sh`
- `bash tests/test-support-claim-wording.sh`
- `bash scripts/sync-skill-mirrors.sh --check`
- `bash tests/validate-plugin.sh`
