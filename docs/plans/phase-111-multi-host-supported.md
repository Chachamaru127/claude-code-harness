# Phase 111 — Multi-host Public `supported` + N+1 Host Registry

Created: 2026-07-09
Status: structural and `internal-compatible` scope complete; live H4 promotion pending
team_validation_mode: subagent (Architecture / Security+Skeptic / QA+Product)

## Goal

Claude Code / Codex CLI / Cursor / Grok を、**false parity なし**で公開語として「正式対応 (`supported`)」に載せられる状態を作る。
将来 host（Copilot CLI 等）が増えても、コピペ gate ではなく **registry + 共通 smoke 層**で伸ばせるようにする。

## Product decision (plan freeze)

### What “正式対応” means

| EN tier | JP public | Meaning |
|---------|-----------|---------|
| `supported` | **正式対応** | H1–H8（下記）が **同一 claim path** で green |
| `internal-compatible` | **互換利用可 / 制限付き対応** | install + static/runtime 部分証明。正式対応ではない |
| `candidate` | **試験対応 / プレビュー** | 経路・静的証明のみ |
| `future/unsupported` | **非対応 / 将来** | setup 装い禁止 |

**禁止**: 4 host を脚注なしで同じ「正式対応」バッジに並べる。
**許可**: 「4 host に入口がある」+ matrix への誘導。正式対応は host ごとに H1–H8 達成時のみ。

### H1–H8 bar (multi-host `supported`, not Claude-clone)

| ID | Requirement | Claude-clone? |
|----|-------------|-----------------|
| H1 | Host dist + setup（package-local, no `..`） | No — install unit may differ |
| H2 | skill_loading 再現（CI or required-mode CLI） | No |
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

Single checklist before ladder entry:

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

- Claude: 正式対応 (`supported`)
- Codex CLI: 互換インストール対応 (`internal-compatible`) — app は別
- Cursor: ローカル導入・スキル確認済み (`internal-compatible`)
- Grok: 互換インストール対応 (`internal-compatible`) — package install / skill discovery / structural smoke まで

## Validation modes used

- Architecture explore agent
- Security/Skeptic explore agent
- QA/Product explore agent
