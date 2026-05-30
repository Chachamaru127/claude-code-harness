# Phase 80 Upstream Adoption Plan - 2026-05-27

Claude Code `2.1.143`-`2.1.152` と Codex `0.131`-`0.134` を Harness にどう採るかの採用判断 SSOT。
根拠 snapshot: `docs/upstream-update-snapshot-2026-05-27.md`

## 採用サマリー

| Decision | Count | 方針 |
|----------|-------|------|
| **Adopt** | Claude 8 / Codex 4 | docs / rules / tests に接続 |
| **Auto-inherit** | Claude 12 / Codex 10 | 本体修正のみ。Harness wrapper 追加なし |
| **Defer** | Claude 4 / Codex 3 | enterprise または operator-local。Phase 80 実装外 |
| **Reject** | 2 | 公式 source 未確認の subagent claim |

## Claude Code 採用判断

| Item | Decision | Why |
|------|----------|-----|
| `disallowed-tools` skill frontmatter | **Adopt** | dangerous side-effect skill で Write/Bash を skill 活性中だけ外せる。`disable-model-invocation` より細粒度。`.claude/rules/skill-frontmatter-2.1.152-plus.md` で SSOT 化 |
| `/reload-skills` | **Adopt** | skill 編集後の同一 session 反映。plugin cache は `/reload-plugins` のまま (`CLAUDE.md`) |
| `SessionStart.reloadSkills` | **Adopt** | hook が skill を install した直後に同一 session で有効化できる。secret を hook 出力に含めない条件付き |
| `hookSpecificOutput.sessionTitle` | **Adopt** | operator UX 改善。session title に secret / PII を入れない rule のみ |
| `MessageDisplay` | **Adopt (opt-in)** | audit 付き表示補助のみ。assistant output の黙示改変・hide は Harness 既定 hook では禁止 (`docs/message-display-policy.md`) |
| Auto mode consent 廃止 | **Defer (Harness default 維持)** | upstream が opt-in barrier を緩めても Harness は `--auto-mode` default 化や `autoMode.hard_deny` 緩和をしない |
| `/simplify` → `/code-review` | **Adopt** | 新参照は `/code-review`。`/code-review --fix` は working-tree write のため operator-local spike |
| `claude agents --json` | **Adopt** | diagnostic / scripting のみ。teammate spawn 代替にしない |
| `claude plugin validate` skills directory check | **Adopt** | skill-editing SSOT と整合。Harness `skills/` 配下 directory SSOT を維持 |
| `pluginSuggestionMarketplaces` | **Defer** | enterprise admin 設定。Harness 配布 template では未設定 |
| Sandbox / worktree / PowerShell fixes | **Auto-inherit** | CC 本体修正。Phase 69 baseline と矛盾なし |

## Codex 採用判断

| Item | Decision | Why |
|------|----------|-----|
| `--profile` primary 化 | **Adopt** | companion / setup docs で `--profile` を primary に。legacy profile v1 selector は新規 docs で推奨しない |
| `on-failure` approval deprecation | **Defer** | 新規 docs/config で `on-failure` を推奨しない。既存 companion は `--ask-for-approval on-request` 等を維持 |
| MCP environment targeting / OAuth | **Defer** | operator MCP 設定 docs 候補。Harness 配布 default に secret を書かない |
| Read-only MCP parallel (`readOnlyHint`) | **Auto-inherit** | 本体最適化。Harness companion policy 変更なし |
| Connector schema `$ref`/`$defs` | **Auto-inherit** | 本体修正 |
| Subagent identity hook input | **Auto-inherit** | 本体修正。Harness Claude hook path とは独立 |
| curl/PowerShell installer | **Adopt** | `scripts/setup-codex.sh` / `codex/AGENTS.md` install 節に公式 installer URL を追記 |
| `--full-auto` / raw `codex exec` default | **Reject (regression)** | companion policy を維持。default route に戻さない |
| Granular approval 全面置換 (subagent claim) | **Reject** | 公式 `0.134.0` release body 未確認 |
| `codex exec --output-schema` default (subagent claim) | **Reject** | 公式 release body 未確認 |

## Support-tier / supply-chain gates

| Surface | Tier | Phase 80 action |
|---------|------|-----------------|
| Codex CLI | `internal-compatible` | 維持。README / tool-capability-matrix の過大 claim なし |
| Codex app | `candidate` | 維持。CLI help を app support 根拠にしない |
| Claude Code | `supported` | Phase 80 Claude items は rules/docs/tests で追従 |
| `claude-codex-upstream-update` skill | **local-only operator tooling** | 配布 surface に昇格しない。marketplace 同梱は現状維持、public support claim なし |

## Security / threat model highlights

1. **MessageDisplay**: transform/hide は opt-in hook のみ。R01-R13 guard rail 出力を hide しない。
2. **Auto mode consent 廃止**: Harness `breezing --auto-mode` は opt-in rollout のまま。`templates/claude/settings.security.json.template` の `autoMode.hard_deny` baseline を緩めない。
3. **Codex profile migration**: legacy profile config を Harness 新規 docs で推奨しない。users は `--profile` + explicit sandbox。
4. **Installers**: curl/PowerShell installer は公式 GitHub release asset を指すのみ。Harness は third-party mirror を配布しない。

## Verification

- `bash tests/test-spec-ssot-workflow.sh`
- `bash tests/test-claude-upstream-integration.sh`
- `bash tests/test-codex-package.sh`
- `bash tests/test-tool-capability-matrix.sh`
- `bash tests/test-support-claim-wording.sh`
- `bash scripts/sync-skill-mirrors.sh --check`
- `bash tests/validate-plugin.sh`
