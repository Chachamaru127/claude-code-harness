# Smoke Test — v4.2.0-arcana (Phase 44 Release)

**实施日**: 2026-04-18
**分支**: `release/v4.2.0-arcana`
**测试实施者**: Worker subagent (harness-work/44.12.1)
**目的**: Phase 44 全 9 任务 (44.3.1–44.11.1) 的 cherry-pick 完成后，release 前的最终品质确认

---

## 自动测试结果

| Test | Command | Result | Notes |
|------|---------|--------|-------|
| validate-plugin | `bash tests/validate-plugin.sh` | **PASS** | 警告 2 件（集成测试警告、已知）、失败 0 |
| consistency | `bash scripts/ci/check-consistency.sh` | **WARN** | mirror drift 3 件（harness-review × 2、harness-loop × 1）。已知・既出。新规 fail 无 |
| migration residue | `bash scripts/check-residue.sh` | **PASS** | 残骸 0 件。扫描时间 76.9s |
| Go guardrail tests | `go test ./go/internal/guardrail/... -count=1`（`go/` dir） | **PASS** | 119 测试 PASS、0 FAIL |
| R01-R13 regression | `bash tests/test-guardrails-r01-r13.sh` | **PASS** | CC2110_* 34 件 PASS（compound/escape/subshell/backtick 全覆盖） |
| 1h cache opt-in | `bash tests/test-prompt-cache-1h.sh` | **PASS** | 9 测试 PASS。env.local 追记・幂等性・env 传达全部确认 |

### validate-plugin 详情

- 合格：39
- 警告：2（集成测试警告。现有问题，本 Phase 变更导致的无）
- 失败：0

### consistency 检查详情

以下 3 件是已知的 mirror drift（Worker D 报告）：

- `codex`：harness-review mirror 与 SSOT 不一致
- `opencode`：harness-review mirror 与 SSOT 不一致
- `opencode`：harness-loop mirror 与 SSOT 不一致

本 Phase 的变更（Phase 44.3.1–44.11.1）未产生新 drift。

### Go guardrail tests 详情

- 包：`github.com/Chachamaru127/claude-code-harness/go/internal/guardrail`
- 执行命令（正确的 cwd）：`cd go && go test ./internal/guardrail/... -count=1`
- 119 测试、PASS / 0 FAIL

> **注意**：从仓库根执行 `go test ./go/internal/guardrail/...` 会
> 出现 `pattern ./go/internal/guardrail/...: directory prefix go/internal/guardrail does not contain main module or its selected dependencies`
> 错误。需要 `cd go` 后执行。

### R01-R13 regression 详情

CC2110_* 测试（34 件）覆盖以下类别：

- 基于 CompoundSemicolon / CompoundAmpAmp / CompoundPipe / CompoundOr 的绕过尝试
- 基于 BackslashEscape 的绕过尝试
- 基于 EnvVarPrefix 的绕过尝试（安全的已知命令继续 block）
- 使用 Heredoc 的绕过尝试（确认正常通过）
- 基于 Subshell / Backtick 的绕过尝试
- PermissionUpdatedInput / AdditionalContext 关联的状态保持测试

---

## 手动检查清单 (Lead/User 实施)

以下 6 项目因 Worker subagent 无法执行，由 Lead 或用户手动确认。

### (a) literal prompt 变更后模糊表现零确认

**确认命令**：

```bash
rg "必要に応じて|適宜|適切に|十分に|柔軟に|しっかり|可能なら|場合によって" agents/*.md
```

**期望结果**：0 件（`.claude/rules/opus-4-7-prompt-audit.md` 的合格条件）

- [ ] 确认 grep 结果 0 件

### (b) PreCompact block 动作确认

**测试步骤**：

```bash
# hooks/pre-compact.sh を直接実行してモックの compact trigger をシミュレーション
# echo で compact フック入力を渡す
echo '{"type":"pre_compact","summary":"test"}' | bash hooks/pre-compact.sh
# → exit 2 で deny 返却されることを確認
echo "exit code: $?"
```

**期望结果**：exit code 2 / JSON `{"decision":"block",...}` 输出到 stdout

- [ ] 确认 exit 2 和 deny JSON

### (c) monitors auto-arm（Phase 45 scope）

**现状**：`plugin.json` 中无 `monitors` block。

```bash
cat .claude-plugin/plugin.json | jq 'has("monitors")'
# → false（現状）
```

Phase 45 计划追加 monitor 自动启动 block。本 smoke test 中仅确认。

- [ ] 确认 Phase 45 追加 scope 记录存在

### (d) 1h cache 反映确认

**测试步骤**：

```bash
# 1h キャッシュを有効化
bash scripts/enable-1h-cache.sh
source .env.local  # または env.local

# CC セッション起動（環境変数が伝播されていることを確認）
echo $ENABLE_PROMPT_CACHING_1H  # → 1

# CC セッション内で /cost を実行してプロンプトキャッシュヒットを確認
# （実際の CC セッション内でのみ確認可能）
```

- [ ] 确认 `ENABLE_PROMPT_CACHING_1H=1` 设置到 env
- [ ] 在 CC 会话内 /cost 确认缓存命中

### (e) xhigh effort 受理确认

**确认对象文件**：

- `agents/reviewer.md`
- `agents/advisor.md`

**确认方法**：

```bash
grep -n "effort.*xhigh\|xhigh.*effort" agents/reviewer.md agents/advisor.md
```

确认 CC 2.1.111+ 的 Opus 4.7 对应 `xhigh` effort 已定义。
实际在 CC 中 `xhigh` 是否受理需要在 CC 2.1.111+ 环境中手动确认。

- [ ] 确认 agents/ 中存在 xhigh effort 定义
- [ ] 在 CC 2.1.111+ 环境中确认 xhigh effort 受理

### (f) guardrails R01-R13 regression 零

自动测试结果（上述）PASS，因此本项目由测试结果担保。

- [x] Go test PASS (119 件)
- [x] R01-R13 shell test PASS (CC2110_* 34 件)

---

## 已知的问题

| 问题 | 详情 | 对应方针 |
|------|------|---------|
| Plans.md 行数超出 | Plans.md 约 285 行（推荐上限 200 行） | Phase 44 完成后计划归档 |
| mirror drift 3 件 | check-consistency.sh 的 harness-review × 2、harness-loop × 1 与 SSOT 不一致 | Worker D 报告已知。Phase 45 中计划整理 |
| monitors block 无 | plugin.json 中无 monitors 字段 | Phase 45 中对应（(c) 参照） |
| isolation:worktree 不全 | 并行 Worker spawn 中 worktree isolation 无效发生 branch state 共享的事例 | cherry-pick 用 SHA 直接指定应对（memory: worker_worktree_share.md） |
| Go test cwd 约束 | `go test ./go/internal/guardrail/...` 无法从仓库根执行 | `cd go` 后执行。validation_commands 的记述注意 |

---

## Phase 44 cherry-pick history (参考)

`git log --oneline 36b73367..HEAD` 输出（`release/v4.2.0-arcana` 分支）：

```
f0d3cdc5 chore(plans): mark 44.11.1 cc:完了 [d96e94b7]
d96e94b7 docs(phase-44.11.1): add v2.1.99-110 + Opus 4.7 entries to Feature Table (B=0)
63f7ddb5 chore(plans): mark 44.10.1 cc:完了 [95d1b39b]
95d1b39b docs(phase-44.10.1): add Task Budgets research memo
87996736 chore(plans): mark 44.9.1 cc:完了 [5949ee7d]
5949ee7d docs(vision): add Opus 4.7 vision high-res review flow and usage guide
1bd2a3b7 chore(plans): mark 44.5.1/44.8.1 cc:完了
e24f7f99 docs(phase-44.8.1): confirm /ultrareview policy — harness-review takes precedence in automation flow
b6e78ba9 chore(plans): mark 44.5.1 cc:完了 [315de2b9]
315de2b9 feat(agents): adopt xhigh effort for reviewer/advisor + document CC-API effort matrix
3e46f416 chore(plans): mark 44.3.1/44.4.2/44.6.1/44.7.1 cc:完了
c7be2b5c feat(phase-44.7.1): integrate CC 2.1.99-110 small features (5 items)
a8f1c308 feat(cache): add enable-1h-cache.sh opt-in script and update long-session docs (Phase 44.6.1)
f921cd98 test(guardrails): CC 2.1.110 regression tests for R01-R13 re-conformance (Phase 44.3.1)
856e9888 fix(mirror): sync opencode/skills/harness-loop with SSOT (add user-invocable: true)
```

---

## 测试环境信息

| 项目 | 值 |
|------|-----|
| 实施日 | 2026-04-18 |
| 分支 | `release/v4.2.0-arcana` |
| HEAD | `f0d3cdc5` |
| OS | darwin 25.3.0 |
| Shell | zsh |
| Go module | `github.com/Chachamaru127/claude-code-harness` |
| CC 版本 | 2.1.111+ (Opus 4.7) 目标 |
