# S5 Acceptance Ledger — redesign 区间分隔发布 (2026-07-08)

**判定: 11 项全 green（M2 CI 侧注记あり）。区间发布 gate 通过。**

GOD_plans.md §7「稳定运行的验收标准」11 项的机械验证 evidence。
正本 GOD_plans.md 为 local-only，从 branch 不可达，因此将基准正文 inline 转记于此（使台账 self-contained）。

| # | 基准 (inline) | 验证命令 | 结果 | evidence |
|---|---|---|---|---|
| 1 | `bash tests/validate-plugin.sh` exit 0・失败 0 | tests/validate-plugin.sh | ✅ | 失败: 0 / 全测试合格 |
| 2 | `go test ./...` 全 package exit 0・FAIL 0 | cd go && go test ./... | ✅ | 44 package ok / FAIL 0（在 main-loop 环境下执行）|
| 3 | `bash scripts/ci/check-consistency.sh` 全 gate exit 0 | scripts/ci/check-consistency.sh | ✅ | exit 0「所有检查均通过」（包含 binary drift gate）|
| 4 | R15 相当规则在 go/internal/policy 中存在，秘密文件的 git add 合成输入导致 pre-tool exit 2 | grep R15 rules.go + 现有 bypass test | ✅ | rules.go:186 `R15:no-stage-secret-file`、Phase 104.1 bypass test PASS |
| 5 | Plans.md Depends↔Status 整合检查器存在且违反 0 | check-consistency.sh Plans dependency closure gate | ✅ | check-consistency.sh:1026 closure gate，全 gate 包含在内 |
| 6 | HARNESS_AUTO_APPROVE=on 时跳过审批 test ≥1，或主张已撤回 | grep README/spec | ✅（撤回）| README「records enablement gate... not skipped」+ sub-spec auto-approve scope 节中 deferred 明记 (984456bf) |
| 7 | bridge/mailbox/bridgedelivery/triaddispatcher/impactscore 各 package 的 importer≥1 或已记录撤回 | 存在确认 + importer grep | ✅ | bridge系4=删除+retired-aliases 注册，impactscore=go/cmd/harness/impact_score.go 为 importer |
| 8 | platform binary 与 go/ source 的 checksum 一致 CI gate green | check-binary-source-drift.sh | ✅ | 109.0 中 4 platform 决定论再生，drift OK (49024b95) |
| 9 | tests/test-hooks-sync.sh 为 7/7 PASS | tests/test-hooks-sync.sh | ✅ | 7/7 passed |
| 10 | main merge-base 以后的安全 commit 已 port/waive 记录且未处理 0 件 | docs/branch-alignment-ledger.md | ✅ | 86 commit 全部分类（port 27 / already-included 7 / waive 52，未分类 0）|
| 11 | bin/harness self-audit 的 deny-baseline 非回归检查为 green | harness self-audit baseline | ✅ | current_sha256 == baseline_sha256 (ok) |

## 注记

- **M2 (CI 侧 binary build flags)**: `.github/workflows/validate-plugin.yml` 使用 plain `go build`（无 -trimpath）覆盖 committed binary 后进行 drift check 的结构，因此在 M2 patch（operator 手动应用）未适用的期间，**仅 CI 侧** drift gate 可能变红。**本地已在基准 3 中确认 green**。M2 是保护 path，仅限 human-only。
- 基准 2 为了避免 sandbox 约束（network bind）在 main-loop 环境下执行 → 44 package ok / FAIL 0。
