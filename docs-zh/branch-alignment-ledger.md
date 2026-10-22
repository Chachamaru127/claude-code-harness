# Branch Alignment Ledger

This ledger tracks safety commits from main that must be ported or explicitly waived before redesign/mainline alignment proceeds. Status values are intentionally closed: `ported` or `waived` only.

| Commit | Area | Status | Why |
|--------|------|--------|-----|
| `1873c8a3` | R15 secret-file staging block | ported | Translated into `go/internal/policy` in Phase 104.1. |
| `6ac3eec0` | R15 git `-C` / subshell bypass | ported | Covered by Phase 104.1 bypass tests. |
| `4d7b6245` | R15 quote-aware lexing | ported | Covered by Phase 104.1 parser/policy port. |
| `3b8e64db` | R15 backslash escape | ported | Covered by Phase 104.1 bypass tests. |
| `5249ad76` | PR #218 safety contract | waived | Product contract already represented on this branch; no additional source delta required for S1. |
| `5a2d0df9` | PR #218 follow-up | waived | Same boundary as `5249ad76`; tracked to avoid silent omission. |
| `d4b8573c` | PR #219 safety contract | waived | Not required for the Phase 104 P0 gate after current source audit. |
| `d9b3fd34` | Egress owner-scope | waived | Owner-scope policy is outside Phase 104 gate implementation; keep as explicit branch-alignment item. |
| `2141c7ef` | setup-hook guard | waived | Setup hook guard does not block S1 gate completion on this branch. |
| `8097802e` | setup-hook guard follow-up | waived | Same boundary as `2141c7ef`; tracked as a paired main commit. |
| `fa88d4cf` | autonomous-confirmation scope | ported | Ported `.claude/rules/autonomous-confirmation-scope.md` (52 lines) to redesign in Phase 104.5. |

## 2026-07-07 Full Inventory (Phase 109.1 — release alignment)

Scope: `git log --no-merges 794bfc36..main` = **86 commits**（Plans.md 记载的 116 包含 merge commit 30 件）。上表的 S1 期 waive 是"Phase 104 P0 gate 不需要"的判定，在 release alignment 中重新分类（下表优先）。

| Group | Commits | Class | Basis | Rep SHA |
|---|---|---|---|---|
| 2026-07-07 guard hardening | 4 | **port (reimplement)** | redesign guard 没有 bookkeeping 免除，hooks.json wrapper 中 CLAUDE_PROJECT_DIR/$PWD 漏洞仍然存在。无法 cherry-pick，需要功能级别的重新实现 | ed6b18c9 |
| bookkeeping 免除 base + 2 rounds | 3 | **port (decision 2026-07-07)** | 没有免除的话 harness-release 的 multi-commit flow (109.5) 会以 #219 同型被阻止。包含 hardening 一起移植 | d4b8573c |
| runtimefloor egress owner-scope | 1 | **port** | redesign 中没有 HARNESS_RUNTIME_FLOOR_EGRESS=off 免除。additive（与 secret-read 侧无冲突） | d9b3fd34 |
| SubagentStop reviewer-persist backstop | 1 | **port (Go 再实现)** | redesign 的 runSubagentStop 仅限 lifecycle，不写 review-result.json | 5249ad76 |
| dependency/security bumps | 5 | **port (verify each)** | 低风险。仅确认 benchmarks/.github 下的 version 差异 | 4f962eb3 |
| known-limitations doc | 1 | **port** | redesign 中没有相当 doc，独立存在 | 08fa2331 |
| autonomous-confirmation-scope / runtimefloor 5-cat base / R15 hardening / review-result part-1 | 7 | already-included | byte 完全一致或 Phase 104.1/108.x 中已有 superseding 实现 | 1873c8a3 |
| skill refactor 链 / mirror sync / release bookkeeping / Phase 94 bookkeeping / #200 trims / hooks doc-drift / P35 footer / cross-session relay 15 件 | 43 | waive | redesign 侧已进行结构替换（channelswake/livemsg/sublead 等）或为 main 固有 bookkeeping | b1141223 |
| Phase 95 release delegation | 9 | conflict-review → 109.1b 验证 | redesign harness-release 的 references/ 未确认 | f499f577 |
| Windows harness-mem companion | 2 | conflict-review → 109.1b | redesign companion.go 中没有 Windows 分支。需要确认是否已完成 Go-native 化 | c8706db8 |
| setup-hook harness.toml bootstrap | 3 | conflict-review → 109.1b | 需要确认 fresh install 是否必需 | 8097802e |
| release-chore 内的实际 fix / bc96f759 / 小型 docs / HOTL wip | 7 | conflict-review → 109.1b | 个别轻验证后确定 port/waive | 7dd175c5 |

**Totals**: port 15 / already-included 7 / waive 43 / conflict-review (109.1b 确定) 21 = 86, 未分类 0。

## 2026-07-07 DP-2 / DP-4 裁定反映 (Phase 109.2, operator 已批准)

- **DP-2 (cut list)**: bridge/mailbox/bridgedelivery/triaddispatcher = Phase 104.4 已删除 (importer 0)。impactscore = Go 统一完成 (importer: go/cmd/harness/impact_score.go)。模糊 skill gogcli-ops/cc-cursor-cc = 已删除 + retired-aliases.v1.yaml 注册完成。agent-browser/cc-update-review = 按保留裁定继续存在。→ 无需追加作业，裁定已反映到实现。
- **DP-4 (auto-approve 主张撤回)**: README 已经是"ledger only, prompts not skipped"表述。sub-spec docs/spec/operations-memory-and-collaboration.md 中原本为空的 auto-approve scope 节已追加撤回正文 (984456bf)。→ GOD_plans §7-6 的撤回路径 green。

## 2026-07-07 conflict-review 21 件的确定 (Phase 109.1b)

精查结果: port 7 组 / waive 3 组。21 raw commit 因以代表 SHA 分组，下表进行个别解决。

| commit群 | 确定 | 依据 | port 目标文件 |
|---|---|---|---|
| Phase 95 release delegation (9, f499f577) | waive | redesign 已经没有 gh release create 调用 + release.yml + test-release-skill-no-gh-release.sh 存在。冗余 | — |
| Windows harness-mem companion (0e3d5ab6, c8706db8) | **port** | redesign companion.go 中 Windows 分支为零。Win 上会出现 "%1 is not a valid Win32 application" (#207) | go/internal/harnessmem/companion.go (手动再移植) |
| setup-hook harness.toml bootstrap (8097802e) | **port** | runSetupInit 没有 harness.toml 生成。fresh install 中 harness sync 会失败 (#201) | setup_hook.go + scaffold 提取 |
| 7dd175c5 plugin runtime cache | **port (partial)** | direct-script hook wrapper 缺少 file-existence guard + codex-companion.sh 的 MODEL_ARGS unbound (4 site)。version bump hunk 是 waive | hooks.json ×2 / sync-plugin-cache.sh / build-host-plugin-dist.sh / codex-companion.sh |
| 631ed798 CI gate | **port (test fix)** | runtimefloor_test.go 的 t.TempDir() 与 /tmp allowlist 冲突导致 Linux CI 误 fail。仅修复 home path 固定化 | runtimefloor_test.go |
| 5d537b7c codex AGENTS.md | **port** | codex/AGENTS.md 中有 3 处过时的"Hooks 未支持"（与实际不符，与 MEMORY North Star note 不一致） | codex/AGENTS.md 3 行 |
| 08fa2331 reviewer + known-limitations | **port** | 缺少 known-limitations.md + reviewer.md 中没有中立列举 instruction | agents/reviewer.md + docs/known-limitations.md |
| a6f58e20 i18n.md SSOT | **port** | 缺少 docs/i18n.md 和 pointer | docs/i18n.md + CLAUDE.md/README pointer |
| 451b4a68 cursor tier | waive (moot) | redesign 的 cursor tier 仍为 candidate。PR #174 promotion 未 merge 到 redesign 系谱。修复目标不存在 | — |
| f6cdb042 HOTL wip | waive (moot) | plan-brief/accept 已在 redesign 中独立接线（已 superseded）。progress-tracker hook 因依赖 script 不存在为 dead code。自 labeled wip | — |

**确定**: conflict-review 21 → port 12 commit相当 (8 rep SHA) / waive 9 commit相当。→ 全 86 commit 分类完成 (port 27 / already-included 7 / waive 52，未分类 0)。

## 2026-07-08 本流化 merge 策略 (Phase 109.4, operator 批准 策略1)

`git merge -s ours origin/main` 将 main 作为祖先纳入，tree 采用 redesign。理由: port 27 commit 已在 109.1a/109.1b 中手动移植，waive 52 是 redesign 故意替换/删除的 subsystem 冲突因此不纳入。merge 后 `git rev-list HEAD..origin/main` = 0 (PR conflict 0)。

**-s ours 遗漏的 main 侧差异及处理**:
- `go/go.mod` / `go.sum`: main 的 indirect→direct 升级 + jsonschema/yaml 添加。redesign 拥有独立依赖树，go test 44 package green 因此无功能缺失。不是 security bump。
- `benchmarks/breezing-bench/*/package-lock.json`: benchmark 用 Node 依赖。production 分发物外。
- **Dependabot 21 漏洞 (M6)**: main default branch 固有。redesign 本流化后另行评估。是 human-only 事项。本 merge 不处理。
