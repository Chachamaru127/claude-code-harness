# `/harness-work all` Evidence Pack

最终更新: 2026-03-06

此 evidence pack 旨在通过「执行后会留下什么」来验证 `/harness-work all` 的各项主张。
当前的前提是，Worker 的自我检查不能单独作为完成依据，而是需要通过 `sprint-contract` 和独立 review artifact 来确认完成后，方可视为完成——这是新的契约。

## What is included

| Scenario | Goal | Expected result |
|----------|------|-----------------|
| success | 用 `work all` 完成一个小型 TODO repo | 测试 green，并留下额外提交 |
| failure | 投放不可能完成的任务以确认 quality gate | 测试保持 fail，不会产生额外提交 |

## Fixtures

- `tests/fixtures/work-all-success/`
- `tests/fixtures/work-all-failure/`

两者在 baseline 状态下 `npm test` 均设计为失败。

## Smoke vs Full

| Mode | Command | What it does |
|------|---------|--------------|
| CI smoke | `./scripts/evidence/run-work-all-smoke.sh` | 检查 fixture 的一致性和 baseline failure，并留下 Claude 执行命令 preview |
| Local full | `./scripts/evidence/run-work-all-success.sh --full` | 用 Claude CLI 执行 success scenario，当遇到 rate limit 时使用 replay overlay 完成 artifact |
| Local full (strict) | `./scripts/evidence/run-work-all-success.sh --full --strict-live` | 不使用 replay，仅通过 live Claude 执行来证明 success |
| Local full | `./scripts/evidence/run-work-all-failure.sh --full` | 用 Claude CLI 执行 failure scenario，确认 commit 没有增加 |

artifact 默认保存在 `out/evidence/work-all/`。

## Prerequisites for full runs

- `claude --version` 能正常执行（使用 strict live 时必须）
- 已通过 Claude Code 认证
- 从本 repo 的 root 执行

full mode 在内部使用以下命令：

```bash
claude --plugin-dir /path/to/claude-code-harness \
  --dangerously-skip-permissions \
  --output-format json \
  --no-session-persistence \
  -p "$(cat PROMPT.md)"
```

## Saved artifacts

- `baseline-test.log`
- `claude-stdout.json`
- `claude-stderr.log`
- `elapsed-seconds.txt`
- `git-status.txt`
- `git-diff-stat.txt`
- `git-diff.patch`
- `git-log.txt`
- `commit-count.txt`
- `result.txt`
- `execution-mode.txt`
- `sprint-contract.json` 或 contract 生成日志
- `review-result.json`
- `fallback-reason.txt`
- `rate-limit-detected.txt`
- `replay.log`（当发生 rate limit fallback 时）

## Interpretation

- success 时若 `post_test_status=0` 且 `final_commits > baseline_commits`，则在最小场景下可作为「走完全程并到达 commit」的证据
- 进一步地，若 `review-result.json` 为 `APPROVE`，则可作为「通过独立 review 完成」的证据
- failure 时若 `post_test_status!=0` 且 `final_commits == baseline_commits`，则可作为「没有隐藏失败就 commit」的证据
- 即使在 failure fixture 中发生了测试篡改，diff artifact 也会保留，便于审查 quality gate 的行为

## Live vs Replay

- `execution_mode=live` 表示 Claude CLI 完整走完 success scenario 的 artifact
- `execution_mode=replay-after-rate-limit` 表示 Claude 执行因 rate limit 中断，通过应用 fixture 自带的 replay overlay 生成了 happy path artifact
- 若想在公开场合声称「已通过 live Claude run 证明」，请另行获取 `--strict-live` 的成功 artifact
