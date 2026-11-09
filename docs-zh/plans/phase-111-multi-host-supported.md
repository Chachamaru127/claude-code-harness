# Phase 111 — Multi-host Public `supported` + N+1 Host Registry

Created: 2026-07-09
Status: structural and `internal-compatible` scope complete; live H4 promotion pending
team_validation_mode: subagent (Architecture / Security+Skeptic / QA+Product)

## Goal

使 Claude Code / Codex CLI / Cursor / Grok 在**无 false parity** 的情况下，作为公开用语"正式对应 (`supported`)"。
即使将来增加 host（Copilot CLI 等），也能通过 **registry + 共通 smoke 层**而非复制粘贴 gate 来扩展。

## Product decision (plan freeze)

### What "正式对应" means

| EN tier | JP public | Meaning |
|---------|-----------|---------|
| `supported` | **正式对应** | H1–H8（如下）在**同一 claim path** 下 green |
| `internal-compatible` | **兼容利用可 / 限制对应** | install + static/runtime 部分证明。非正式对应 |
| `candidate` | **试验对应 / 预览** | 仅路径・静态证明 |
| `future/unsupported` | **非对应 / 将来** | 禁止装作已 setup |

**禁止**: 不加脚注地将 4 个 host 并列到同一"正式对应" badge。
**允许**: "4 个 host 有入口" + 引导到 matrix。正式对应仅在各个 host 达到 H1–H8 时成立。

### H1–H8 bar (multi-host `supported`, not Claude-clone)

| ID | Requirement | Claude-clone? |
|----|-------------|-----------------|
| H1 | Host dist + setup（package-local, no `..`） | No — install unit may differ |
| H2 | skill_loading 再现（CI or required-mode CLI） | No |
| H3 | Host-native bootstrap route named in contract | No — SessionStart **or** AGENTS |
| H4 | **Workflow smoke**: plan (min) produces artifact in CI-gated or release-required path | No |
| H5 | Declared safety model proven: (a) live pre_use deny → `harness hook pre-tool`, **or** (b) documented post-gate floor + limits | No — but **undeclared guard is banned** |
| H6 | review_artifact path or brain-primary handoff contract | No |
| H7 | release-preflight consumes host gates fail-closed | No |
| H8 | README / matrix / onboarding / claim-wording tests pin same tier | No |

**Not required for `supported`**: SessionStart parity, Agent Teams, Breezing multitask, memory_bridge parity.

### Promotion order (risk-aware)

1. **SSOT + registry** (blocks marketing accident)
2. **Codex CLI** → first non-Claude public `supported` (floor exists; Bash-only disclosed)
3. **Cursor** → `supported` after CI workflow smoke + FS/allowlist known-limitations
4. **Grok** → floor membership **or** explicit floor-out + H4/H5 before `supported`
5. **Claude** → regression only (already `supported`; bar must not dilute)

### Future host admission (N+1)

Entry before ladder:

1. Native intercept or explicit `safety_model=none` max-tier
2. Deny semantics (fail-open/closed)
3. Event coverage (shell/file/MCP)
4. Install unit test
5. Static smoke in CI
6. Optional runtime flag `HARNESS_${HOST}_*_SMOKE_REQUIRED`
7. Matrix + bootstrap route
8. support-claim wording entries (EN + JP)
9. Evidence research note
10. Floor join **or** explicit exclusion

## Evidence from validation (2026-07-09)

| Host | Current tier | Blocker to `supported` |
|------|--------------|------------------------|
| Claude Code | `supported` | Dilution if others promote without bar |
| Codex CLI | `internal-compatible` | H4 workflow CI; matrix/hardening SSOT drift; Bash-only disclosure |
| Cursor | `internal-compatible` | H4 CI workflow; containment/known-limitations as public text |
| Grok | `internal-compatible` | H4/H5; not on 3cli floor; no public `supported` claim |

## Spec delta (applied)

1. `docs/spec/planning-and-host-adapter.md` — Support Tiers table: add H1–H8 reference; add Grok row; update Codex/Cursor reasons.
2. `docs/spec/execution-backends-and-distribution.md` — Grok as host/engine surface where relevant; floor membership table; Cursor/Grok not silent 3cli.
3. `docs/tool-capability-matrix.md` / `hardening-parity.md` — sync pre_use_guard to 3cli + Cursor deny facts.
4. `hosts.toml` (or `hosts/registry.yaml`) — Grok + tier + setup + smoke paths as SSOT for generators/tests.

## Non-goals

- Marketplace publish to xAI/Cursor official stores
- Codex app = CLI
- Claiming Claude PreToolUse clone on every host
- Auto-promoting marketing copy before CI green

## Marketing-safe one-liners (until promotion)

- Claude: 正式对应 (`supported`)
- Codex CLI: 兼容安装对应 (`internal-compatible`) — app 另说
- Cursor: 本地导入・skill 确认完毕 (`internal-compatible`)
- Grok: 兼容安装对应 (`internal-compatible`) — package install / skill discovery / structural smoke 为止

## Validation modes used

- Architecture explore agent
- Security/Skeptic explore agent
- QA/Product explore agent
