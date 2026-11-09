# Governance Rules — Rationale ("为什么需要这个规则")

`.claude/rules/` 下的常时加载 governance 文件在 Phase 124.1（常时加载 context 盘点）中，将
契约条款（禁止事项・检查清单・步骤）的背景说明抽出到
本文件。契约本身原封不动地保留在原文件。本文件是补足的
背景资料，内容是摘要・改変せず将原文原封不动移设。

## self-audit.md

settings.json 的 deny 规则是"约束 agent 自身的锁"。
锁的数量减少了的话，可能是非意图的缓和或篡改。
通过检测减少方向而非绝对数量，允许正当的追加同时捕捉缓和。

将 settings.local.json 的 hook 注入另立监视的原因是，deny
（`Write/Edit(.claude/settings*)`）是**通过工具路径阻止的 preventive 层**，
而对于 Bash 重定向等残余路径（guardrail 仅 warn 为止）需要
**detective 的 backstop**。preventive（deny 不让写）和
detective（事后发现注入）的两段捕捉"解锁"篡改。

## workflow-test-wiring.md

将 `.github/workflows/` 的 AI 编辑 deny 和"新测试的 CI 布线"并立的规则。
operator 裁定 (2026-07-16)：deny 的本质是**报酬 hack 防止**，不是"AI 不能触碰测试网"。

v5.1.0 新设的 2 测试（`test-hermes-agent-candidate.sh` / `test-lsp-workflow-wiring.sh`）
处于"workflows 是 AI 编辑 deny → operator 手动 patch 等"状态而 CI 未布线残留（HG-3。
本规则制定同一 batch 中通过 `tests/validate-plugin.sh` 布线已解决）。
实现者本人（AI 会话）能弱化检查自己变更的测试的状态是报酬 hack，
将范围扩展到"追加"方向完全倒向人工手动是过度防御。按方向区分。

## autonomous-confirmation-scope.md

自律执行中频繁停止于非本质确认（review 对象候选选择、commit message 文言选择等）时，
用户感到"被问是否推测就能决定的事"，自律执行的价值丧失。特别是这些
确认多用英语提示，判断材料也匮乏，用户无法正确回答。

通过缩小可以确认的事项，真正需要停止的场面（外部发送・安全性・委托执行可否）才
浮出水面。

## shared-file-discipline.md

Phase 92.1.1 的并行准备中，2 个 worker 同时尝试追加 `CHANGELOG.md` 时
发生 cherry-pick 冲突的风险浮现。Lead 指示两 worker 禁止 CHANGELOG，
改为集成时汇总 2 entry 追加的运用。

同样 `Plans.md` / `spec.md` 由多 worker 同时编辑时，
即使是 append-only 也会在 cherry-pick 时在同一行附近发生冲突。
在 worktree 内 bump `VERSION` 会破坏与 trunk 的 3 点同步（VERSION / plugin.json / harness.toml）。
在 worktree 各自重新生成 `bin/harness` 或 mirror（`opencode/skills/` 等），
是二进制冲突和 mirror drift 的温床。

将这 3 个不变量（invariant）明确记载在 Lead / Worker 的 sprint contract 中，
不在每次并行执行时重新协商。
