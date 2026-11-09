# Session ID Env Policy (Phase 62.2.4)

> **状态**: Active (2026-05-07)
> **背景**: Claude Code `2.1.132` 中 `CLAUDE_CODE_SESSION_ID` 作为
> env var 传递到 Bash subprocess。整理 Harness 的 hook handler / shell wrapper / CLI helper 中
> 获取 session ID 的路径，防止混乱。

## 一句话概括

session ID 的获取路径有 **4 种**，按用途分开使用。
hook handler 是 **stdin JSON (`.session_id`)** 正确，env var 不依赖。
Bash 子进程想读 session ID 时才用 env var (`CLAUDE_CODE_SESSION_ID`)。

## 打个比方

与"家门钥匙"和"车钥匙"不混淆相同。
hook handler 是 CC"直接递钥匙"(stdin)，用那个。
Bash 子进程（rg / jq / curl 启动的 subshell）不是 CC 直接调用，
需要从"钥匙放置处"(env var) 取。

## 4 种获取路径

| # | 路径 | 获取自 | 用途 |
|---|------|--------|------|
| 1 | stdin JSON `.session_id` | hook input | **hook handler 的主路径** |
| 2 | `CLAUDE_CODE_SESSION_ID` env var | OS env | Bash 子进程、CLI helper |
| 3 | `.claude/state/session.json` 的 `.session_id` | local state | session-monitor / session-broadcast 等长寿命 watcher |
| 4 | regex extract from `CLAUDE_TRANSCRIPT_PATH` | env var (regex) | **不使用 (legacy)** |

## 使用区分

### (1) hook handler 内 → stdin JSON

```bash
SESSION_ID="$(printf '%s' "${INPUT}" | jq -r '.session_id // ""')"
```

理由：hook handler 从 CC 接收 JSON 输入。stdin JSON 是 SSOT。

依赖 env var，多 session 并行执行时有父 session env 被误继承的风险
(Bash subprocess 继承父 env)。

### (2) Bash 子进程 → `CLAUDE_CODE_SESSION_ID` env var (CC 2.1.132+)

```bash
# 例: scripts/codex-companion.sh から起動した jq subprocess 内で session ID 必要時
SESSION_ID="${CLAUDE_CODE_SESSION_ID:-}"
if [ -z "${SESSION_ID}" ]; then
  echo "[warn] CLAUDE_CODE_SESSION_ID not set; running on CC 2.1.131 or older" >&2
  SESSION_ID="unknown"
fi
```

理由：Bash 子进程不从 CC 直接接收 stdin，所以 env 是唯一路径。
CC `2.1.131` 以下无 env var，需要 `unknown` fallback。

### (3) Long-running watcher → `.claude/state/session.json`

```bash
SESSION_ID="$(jq -r '.session_id // "unknown"' "${PROJECT_ROOT}/.claude/state/session.json")"
```

理由：session-monitor / session-broadcast 等在 session 开始后持续运行，
state file 是 SSOT。env / stdin 读不到。

### (4) regex extract from `CLAUDE_TRANSCRIPT_PATH` → 不使用

过去例：`echo "$CLAUDE_TRANSCRIPT_PATH" | sed 's|.*/\([a-f0-9-]*\)\.json|\1|'`

问题：
- transcript path 格式可能因 CC 版本变化
- regex 坏了时的 fallback 复杂
- `CLAUDE_CODE_SESSION_ID` env var 直接可用 (CC 2.1.132+)

**现行 Harness 中未使用**。新实现也不采用。

## 3 状态测试命名公约 (遵循 `.claude/rules/active-watching-test-policy.md`)

处理 session ID 获取的 test scripts 全部 cover 以下状态：

| 状态 | 名称 | 预期行为 |
|------|------|---------|
| Healthy | `TestSessionIdEnv_Healthy` | env var 有 → 原样使用 |
| NotConfigured | `TestSessionIdEnv_NotConfigured` | env 无 → state file fallback，不出警告 |
| Corrupted | `TestSessionIdEnv_Corrupted` | env / state 两者无 → `unknown` fallback，出警告 |

## 関連 doc

- `.claude/rules/active-watching-test-policy.md` — 3 状态测试公约
- `docs/long-running-harness.md` — long-running session 的 env 继承
- Claude Code 2.1.132 CHANGELOG: Added `CLAUDE_CODE_SESSION_ID` environment variable to Bash tool subprocess environment

## Acceptance 条件 (Phase 62.2.4 DoD)

- [x] 4 种路径的使用区分在 docs 中明记
- [x] 明记 hook handler 是 stdin JSON 路径（不依赖 env）
- [x] 展示 CC 2.1.131 及以下版本的回退方案
- [x] 与 3 状态测试公约 (`.claude/rules/active-watching-test-policy.md`) 一致
- [x] 明记不使用从 `CLAUDE_TRANSCRIPT_PATH` 正则提取
