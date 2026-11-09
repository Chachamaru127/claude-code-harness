# MessageDisplay Hook Policy (Claude Code 2.1.152+)

CC `2.1.152` 新增了 `MessageDisplay` hook event。
hook 可以在 assistant message 显示之前 transform 或 hide 其 text。

Harness 限定为 **带 audit 的 opt-in 显示辅助**，禁止对 assistant output 的隐式改写。

## 适用范围

| 对象 | 方针 |
|------|------|
| Harness 配布 hooks (`.claude-plugin/hooks.json`, `hooks/hooks.json`) | Phase 80 时点 **不添加 MessageDisplay hook** |
| Operator / project custom hooks | 仅在遵循本 policy 时才可 opt-in |
| Codex | 不适用（Claude Code hook surface） |

## 允许的用途（opt-in）

- 面向本地 locale 的 **非安全性** 显示整形（例如：把已知 status marker 替换为面向用户的表述）
- 隐藏重复的 footer / debug banner（**不隐藏 guard rail 或 deny 原因**）
- operator 明确启用的 `HARNESS_MESSAGE_DISPLAY=1` 之下的 notification 整形

## 禁止

- 隐藏或 rewrite Permission deny / ask 原因、R01-R13 guard rail 输出、secret 值、`.env` 内容
- transform Reviewer `REQUEST_CHANGES` / Worker `advisor-request` 等 **证据消息**
- 未经用户批准改变 assistant 回答的含义（用摘要导致事实缺失的 rewrite）
- 通过隐藏 Auto mode classifier 输出而掩盖风险

## Audit 要求

向 project 添加 MessageDisplay hook 时：

1. 在 `.claude/rules/hooks-2.1.152-plus.md` 或 project rules 中用 1 行记录 hook script 名和触发条件
2. 记录 transform 前后的 jsonl，或使 `/doctor` 可以确认 hook 已注册
3. hide 对象限定在 allowlist（固定 prefix / 已知 debug tag）内

## 与 Auto mode consent 的关系

即便 upstream 废除了 Auto mode 的 opt-in consent，Harness 也不会
把 `MessageDisplay` 当作启用 Auto mode 的替代手段。
也不会将其用作 `--auto-mode` 默认化或放宽 `autoMode.hard_deny` 的理由。

## 相关

- `docs/upstream-adoption-plan-2026-05-27.md`
- `.claude/rules/hooks-2.1.152-plus.md`
- `templates/claude/settings.security.json.template` (`autoMode.hard_deny`)
