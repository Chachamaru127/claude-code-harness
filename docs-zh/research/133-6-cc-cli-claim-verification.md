# 133.6 — CC CLI Claim Verification (subagent depth/concurrency + sandbox masking)

## 目的

先行的 research agent 通过 WebFetch 获取的摘要中报告了 2 个集群的 CC CLI 功能，
直接获取一次信息（raw CHANGELOG.md），通过字面一致进行确认。

## 一次信息

`https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md`

**获取方法的注记**: WebFetch 工具本身由小型模型进行摘要，
仅靠它与二手信息实质相同（存在幻觉风险）。本次用 WebFetch 的摘要结果，
通过 `curl` 获取的 raw 文件（5455 行）的 `grep` 进行独立验证。以下的引用全部来自通过 curl 获取的 raw 文件确认。

## (i) Subagent nested-spawn depth limit + concurrency env var

**状态: `confirmed`**

在 `CHANGELOG.md` 中，以下版本标题下确认到相关行：

- **`## 2.1.217`**:
  > Added a cap on concurrently-running subagents (default 20, override with `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`) so one message can't fan out unbounded background agents

  > Changed subagents to no longer spawn nested subagents by default; set `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` to allow deeper nesting

- **`## 2.1.219`**:
  > Subagents can now spawn nested subagents up to depth 3 by default (was 1); set CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH=1 to disable nesting

也就是说实际经过是 2 阶段: 2.1.217 将嵌套 spawn 设为默认 OFF（depth 1）并引入 `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` env var + 引入并发数上限（默认 20）via `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`。2.1.219 将默认值放宽到 depth 3。

先行的 research agent 的报告（「nested-spawn depth limit + concurrency env var」）
与此 2 版本的实际变更一致。

## (ii) Sandbox credential-masking + strictAllowlist

**状态: `confirmed`**

- **`## 2.1.219`**:
  > Added `sandbox.network.strictAllowlist` setting to deny non-allowlisted hosts for sandboxed commands without prompting

- **`## 2.1.221`**:
  > Added `mode: "mask"` for sandbox credential files on Linux and WSL — sandboxed commands read a sentinel copy (the whole file, or just the spans captured by an `extract` regex) while the sandbox proxy substitutes the real value on egress; on macOS file masking falls back to `deny`

- **`## 2.1.224`**:
  > Added sandbox credential-masking options: `extract` and `onExtractNoMatch` for structured env values, `decode: "jwt"` with `maskClaims` for JWT-aware masking, and `awsPairs`/`sigv4` for AWS SigV4 re-signing; these need `network.tlsTerminate` and are honored only from user, managed, or `--settings` settings

跨越 3 个版本的阶段性功能添加: 2.1.219 添加 `strictAllowlist`（网络侧）、
2.1.221 添加 credential file 的 `mode: "mask"`（macOS 上 fallback 到 `deny`）、
2.1.224 添加 JWT / AWS SigV4 对应的结构化 masking 选项。

## 注记: 版本差距

本 repo 的 `docs/CLAUDE-feature-table.md` 当前追踪的最新版本是 `2.1.152` 台
(Phase 80)。本次确认到的行是 `2.1.217`〜`2.1.224`，其间的 `2.1.153`〜`2.1.216`
不在本任务的验证范围内（未确认）。本任务是 2 件个别 claim 的点验证，
不是完整版本同步。

## 验证命令

```bash
curl -sL https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md -o /tmp/cc-changelog-raw.md
grep -n "MAX_SUBAGENT\|CONCURRENT_SUBAGENT\|SUBAGENT_SPAWN" /tmp/cc-changelog-raw.md
grep -ni "strictAllowlist\|credential.mask\|maskClaims" /tmp/cc-changelog-raw.md
```

## 分类 (Feature Table 反映方针)

`docs/rules/cc-update-policy.md` 要求将 Feature Table 添加与 A (有实现) / C (CC 自动继承)
二者之一关联。本任务仅为验证，不伴随实现，因此使用本 repo 现有 addendum 节（Phase 58/62/69/80 等）采用的 `P: Plans 化`
（本次不直接实现，继承给后续任务）来向 Feature Table 追加记录。
不符合 `B`（仅记录/无实现且无 C 明确记载）的条件。
