# Claude Code upstream snapshot - 2026-05-15

本 snapshot 确认了 Phase 62 追従完毕的 `2.1.112`-`2.1.132` 以后发布的
**`2.1.133`-`2.1.142`** (合计 10 版本)，作为 Phase 69 中
Harness 的 Tier 1 5 件 + Tier 2 5 件实现的记录。

确认日：

- 2026-05-15 (Asia/Tokyo)

本地确认：

- `claude --version`: `2.1.142 (Claude Code)` 想定
- (CHANGELOG 从 GitHub 官方来源确认)

现有 Harness 的追従完毕点：

- Claude Code `2.1.112`-`2.1.132` (Phase 62, `docs/upstream-update-snapshot-2026-05-07.md`)

一次信息：

- Claude Code GitHub CHANGELOG: <https://raw.githubusercontent.com/anthropics/claude-code/main/CHANGELOG.md>
- Claude Code docs CHANGELOG: <https://code.claude.com/docs/en/changelog>

分类：

- `A: 検証強化`: 在本次 Phase 69 中通过 snapshot / Feature Table / CHANGELOG / tests / 实现固定。
- `C: 自動継承`: 继承 Claude Code 本体的修正。不叠加 Harness wrapper。
- `P: Plans 化`: 对 Harness 有使用价值，但本 snapshot 中不进行 runtime 实现，切为后续 task。
- `B: 書<minimax:tool_call>仅仅`: **0 件** (本 snapshot 中不做 `B`)。全部署为 `A` / `C` / `P`。

## Version-by-version breakdown

| Version | Upstream item | 这样会更好 | Category | Harness surface | Harness action |
|---------|---------------|------------|----------|-----------------|----------------|
| Claude Code `2.1.133` | `worktree.baseRef` setting (`fresh` \| `head`) | 可以明确 `--worktree` / `EnterWorktree` / agent-isolation worktree 的起点 | A | `templates/claude/settings.security.json.template` (`.claude-plugin/settings.json` 因 self-protect deny 由 operator 手动应用) | Phase 69.1.1 中在 template 中明确 `fresh` 为 baseline。breezing / Worker isolation 的 base ref 固定为 `origin/<default>`，对想把 unpushed commits 带入新 worktree 的 team 以 `head` 作为 opt-in 提示。Plugin 本体 `.claude-plugin/settings.json` 因 CLAUDE.md Permission Boundaries 的 self-write deny agent 无法rewrite，因此由 operator 在 release 时手动 merge |
| Claude Code `2.1.133` | `sandbox.bwrapPath` / `sandbox.socatPath` managed settings | Linux/WSL 中可以明确 bwrap/socat 的实体 | C | sandbox runtime | Harness 侧不持有固定值。委托 CC 本体的解决逻辑 |
| Claude Code `2.1.133` | `parentSettingsBehavior` admin-tier key | SDK `managedSettings` 可以 opt-in 到 policy merge | P | docs (admin governance) | 面向个人开发者的 Harness 不强制 merge。enterprise context 出现时 docs 化 |
| Claude Code `2.1.133` | Hooks receive `effort.level` JSON + `$CLAUDE_EFFORT` env | hook 可以根据当前的 effort 分支 | A | `scripts/hook-handlers/*.sh`, `.claude/rules/hooks-2.1.139-plus.md` | Phase 69.1.2 中明文化 `$CLAUDE_EFFORT` 作为 opt-in 的分支轴。在 rules 中记述，同意 Bash 内也可以引用 `$CLAUDE_EFFORT` 的前提统一 |
| Claude Code `2.1.133` | parallel sessions credential race / `Edit`/`Write` allow-rule on drive root / `--add-dir` mapped drives etc. | runtime bug fix | C | runtime | 自动继承 |
| Claude Code `2.1.133` | `/effort` cross-session leak fix | session 间的 effort 独立 | C | runtime | 自动继承 |
| Claude Code `2.1.133` | Subagents 不发现 Skill 修正 / `claude --help` `--remote-control` 追记 | runtime fix | C | runtime | 自动继承 |
| Claude Code `2.1.134` | (no changelog entries) | --- | C | --- | 自动继承 |
| Claude Code `2.1.135` | (no changelog entries) | --- | C | --- | 自动继承 |
| Claude Code `2.1.136` | `settings.autoMode.hard_deny` 无条件块规则 | Auto Mode classifier 可以处理"无论许可意图如何都一定 deny" | A | `templates/claude/settings.security.json.template` (`.claude-plugin/settings.json` 因 self-protect deny 由 operator 手动应用) | Phase 69.1.3 中在 template 中明文化 baseline 7 件 (`Bash(sudo:*)` / `Bash(rm -rf:*)` / `Bash(rm -fr:*)` / `Bash(git push -f:*)` / `Bash(git push --force:*)` / `Bash(git reset --hard:*)` / `mcp__codex__*`) 为 hard_deny。Plugin 本体 `.claude-plugin/settings.json` 由 operator 在 release 时手动 merge |
| Claude Code `2.1.136` | `CLAUDE_CODE_ENABLE_FEEDBACK_SURVEY_FOR_OTEL` | 通过 OTel 获取反馈 | C | OTel | Harness 不强制 OTel pipeline。enterprise opt-in 时 CC 本体解释 |
| Claude Code `2.1.136` | MCP server `/clear` 消失修正 / OAuth refresh race fix / extended thinking redaction 400 fix | runtime 稳定化 | C | MCP / auth | 自动继承 |
| Claude Code `2.1.136` | `--resume`/`--continue` underscore path / plan mode `Edit(...)` allow 阻碍 / WSL2 image paste / `SessionStart` `CLAUDE_ENV_FILE` 再注入 | runtime fix | C | runtime | 自动继承 |
| Claude Code `2.1.136` | 视觉整合性 (slash dialog 统一, markdown 色, CJK ellipsis, jump-to-bottom artifact 等) | UX 改进 | C | UX | 自动继承 |
| Claude Code `2.1.137` | VSCode 扩展 activation Windows 修正 | runtime | C | IDE | 自动继承 |
| Claude Code `2.1.138` | Internal fixes | runtime | C | runtime | 自动继承 |
| Claude Code `2.1.139` | Agent view (`claude agents`) Research Preview | 可以从 1 个画面监控所有 CC session | A | `agents/worker.md`, `agents/team-composition.md`, `docs/agent-view-policy.md` | Phase 69.2.2 中将 `claude agents` 作为与 breezing teammate 独立的 1st-class operator entrypoint 进行 policy 化。Harness 内 spawn 继续限于 Lead |
| Claude Code `2.1.139` | `/goal` command | 可以在 turn 跨越中保持完成条件 | A | `docs/codex-plugin-workflows-policy.md`, `skills/harness-plan/SKILL.md`, `skills/harness-work/SKILL.md` | Phase 69.2.1 中将 CC native `/goal` 也与 Codex `/goal` 同样**限于 session continuation memo 用途**。`Plans.md` / DoD 作为唯一的 task SSOT 保持。在 rules 中追加将 `/goal` 和 Plans.md 双重化的 grep gate |
| Claude Code `2.1.139` | `/scroll-speed` | mouse wheel UX | C | UX | 自动继承 |
| Claude Code `2.1.139` | `claude plugin details <name>` | 可以可视化 plugin 的 component 内訳和 token cost | A | `scripts/ci/check-consistency.sh`, `docs/plugin-managed-settings-policy.md` | Phase 69.2.4 中将 `claude plugin details` 的输出定位为 `bin/harness doctor` / consistency check 的辅助信息，docs 化当 token cost 超过 1 plugin 中 session 预算阈值时的对应步骤 |
| Claude Code `2.1.139` | Transcript view navigation (`?`, `{`/`}`, `v`) | UX | C | UX | 自动继承 |
| Claude Code `2.1.139` | Hook `args: string[]` (exec form) | 不通过 shell 中介即可直接 spawn command | A | `.claude/rules/hooks-2.1.139-plus.md` | Phase 69.1.4 中在 rules 中化 exec form 的使用条件：包含 path placeholder 的 hook 优先使用 exec form，只有在需要 shell metacharacter 展开时维持现有的 `type: "command"` |
| Claude Code `2.1.139` | Hook `continueOnBlock` for PostToolUse | hook 可以将 rejection reason 返回给 Claude 并继续 turn | A | `.claude/rules/hooks-2.1.139-plus.md` | Phase 69.1.4 中追加将 `continueOnBlock` 限于"安全的诊断反馈"用途的 rule。必须 deny 的 guard rail (R01-R13) 保持 `continueOnBlock: false` |
| Claude Code `2.1.139` | MCP stdio receives `CLAUDE_PROJECT_DIR` | MCP server 可以解决 project dir | C | MCP | 自动继承 |
| Claude Code `2.1.139` | Compaction prompt 保留 user instructions | session 中的 rule 在 compaction 中不容易消失 | C | compaction | 自动继承 |
| Claude Code `2.1.139` | `x-claude-code-agent-id` / `parent-agent-id` headers + OTEL `agent_id` attrs | subagent 监视性提升 | C | OTel/telemetry | 自动继承 |
| Claude Code `2.1.139` | 设置 `ANTHROPIC_API_KEY` 时禁用 Remote Control 等 | enterprise auth boundary 明确 | C | auth | 自动继承 |
| Claude Code `2.1.139` | hook 在 terminal 写入时导致 prompt corruption → no terminal access | hook 稳定化 | C | runtime | 自动继承 |
| Claude Code `2.1.139` | `Skill(name *)` wildcard prefix match | permission rule 的表现力 | C | permission | 自动继承 |
| Claude Code `2.1.140` | `subagent_type` case-/separator-insensitive matching | agent 名表記揺容耐性 | C | agent | 自动继承 |
| Claude Code `2.1.140` | Updated agent color palette | UX | C | UX | 自动继承 |
| Claude Code `2.1.140` | `/goal` 无音 hang fix on `disableAllHooks` | runtime fix | C | runtime | 自动继承 |
| Claude Code `2.1.140` | Settings hot-reload symlink fix / `/loop` redundant wakeups / Windows where.exe stall | runtime fix | C | runtime | 自动继承 |
| Claude Code `2.1.140` | Plugins warn when default folder silently ignored | plugin lifecycle 可视性 | C | plugin | 自动继承 |
| Claude Code `2.1.141` | `terminalSequence` field for hook JSON output | hook 可以在没有 controlling terminal 的情况下触发 desktop 通知 / window title / bell | A | `scripts/hook-handlers/webhook-notify.sh`, `scripts/hook-handlers/notification-handler.sh`, `.claude/rules/hooks-2.1.139-plus.md` | Phase 69.1.5 中实现 `HARNESS_TERMINAL_NOTIFY` env (0/1/`bell`/`title`/`osc9`) opt-in，使 `task-completed` 系 hook 可以在不需外部 webhook 的情况下发出 local notification |
| Claude Code `2.1.141` | `CLAUDE_CODE_PLUGIN_PREFER_HTTPS` | 无 SSH key 环境中也可以 clone plugin | C | plugin | 自动继承 |
| Claude Code `2.1.141` | `ANTHROPIC_WORKLOAD_ID` (workload identity federation) | token scoping | P | enterprise auth | enterprise context 出现时通过 docs/plugin-managed-settings-policy.md -docs 化 |
| Claude Code `2.1.141` | `claude agents --cwd <path>` | 可以按 directory scope 过滤 session 列表 | A | `docs/agent-view-policy.md` | 与 Phase 69.2.2 同期：将 agent view 按 project 分离的运用 docs 化 |
| Claude Code `2.1.141` | `/feedback` includes recent sessions | 跨 session 的 bug report | C | feedback | 自动继承 |
| Claude Code `2.1.141` | Rewind "Summarize up to here" | context compression 中间状态保持 | C | session | 自动继承 (与 `.claude/rules/commit-safety.md` 的 `/undo` policy 整合) |
| Claude Code `2.1.141` | Auto mode dialog 说明来自 `permissions.ask` | permission UX | C | permission | 自动继承 |
| Claude Code `2.1.141` | IDE diff view restore on file-edit permission prompt | IDE | C | IDE | 自动继承 |
| Claude Code `2.1.141` | Background agents preserve permission mode | `/bg` / `←←` 启动的 agent 不会回到 default | A | `agents/worker.md`, `agents/team-composition.md`, `docs/agent-view-policy.md` | Phase 69.2.3 中明文化 breezing teammate / Worker isolation worktree 的 permission mode 期望值 |
| Claude Code `2.1.141` | `claude agents` Completed state for background-shell-leaking sessions | agent view 显示 | C | agent | 自动继承 |
| Claude Code `2.1.141` | Spinner 10s amber warm-up / plugin menu nav / 多数 hooks / MCP / Remote Control / SDK / Bedrock / VSCode 修正 | runtime fix | C | runtime | 自动继承 |
| Claude Code `2.1.141` | 修复 hooks 在 `EnterWorktree` 后 `transcript_path` 失效 | runtime fix | C | hook | 自动继承 (确认 Harness 侧没有信赖 `transcript_path` 的地方) |
| Claude Code `2.1.142` | `claude agents` 新 flag 群 (`--add-dir`, `--settings`, `--mcp-config`, `--plugin-dir`, `--permission-mode`, `--model`, `--effort`, `--dangerously-skip-permissions`) | dispatched background session 的构成变得声明式 | A | `docs/agent-view-policy.md`, `agents/team-composition.md` | 与 Phase 69.2.2 同期：将各 flag 的使用条件和与 Harness deny 规则的冲突 (例: `--dangerously-skip-permissions` 不用于 protected branch) 落入 rule |
| Claude Code `2.1.142` | Fast mode Opus 4.7 default + `CLAUDE_CODE_OPUS_4_6_FAST_MODE_OVERRIDE` | fast mode 始终在 Opus 4.7 上运行 | C | model | 自动继承 (因已作为 Opus 4.7 default 处理，Harness 侧无需变更) |
| Claude Code `2.1.142` | Plugins with root-level `SKILL.md` and no `skills/` subdir surfaced | 单个 SKILL plugin 被识别 | C | plugin | 自动继承 (Harness 将 `skills/` 配下作为 SSOT，因此无影响) |
| Claude Code `2.1.142` | `/plugin` details + `claude plugin details` now show LSP servers | LSP 可视性 | C | plugin | 自动继承 |
| Claude Code `2.1.142` | `/web-setup` warns before replacing GitHub App connection | safety | C | web setup | 自动继承 |
| Claude Code `2.1.142` | `MCP_TOOL_TIMEOUT` raises per-request fetch timeout for HTTP/SSE | MCP long-running call 发挥作用 | C | MCP | 自动继承 |
| Claude Code `2.1.142` | Background sessions 识别 pre-existing worktree / macOS sleep/wake / daemon binary upgrade cleanup / Chrome extension shim 等多数 fix | runtime 稳定化 | C | runtime | 自动继承 |
| Claude Code `2.1.142` | Hook config error: SessionStart/Setup/SubagentStart 中 prompt/agent 型 hook 会报错 | hook config error 早期检测 | A | `.claude/rules/hooks-2.1.139-plus.md` | 在 Phase 69.1.4 的同一 rule 内明文化"SessionStart/Setup/SubagentStart 只用 command 型"，使 Harness hooks.json 的对应箇所可 grep 化 |
| Claude Code `2.1.142` | Improved reactive compaction (first summarize seeds from overflow size) | compaction 效率 | C | session | 自动继承 |
| Claude Code `2.1.142` | Removed stale `/model claude-sonnet-4-20250514` suggestion | UX | C | runtime | 自动继承 |

---

## Tier 1 (Phase 69.1.1-69.1.5) - 直接更新设置 / hooks / rules

| ID | Phase | 内容 | 主要 artifact |
|----|-------|------|---------------|
| 69.1.1 | settings | 在 `templates/claude/settings.security.json.template` 中明确 `worktree.baseRef: "fresh"` (plugin 本体 settings 由 operator 手动应用) | `templates/claude/settings.security.json.template` |
| 69.1.2 | hooks | 在 rules 中明文化 `effort.level` JSON + `$CLAUDE_EFFORT` env 的引用政策 | `.claude/rules/hooks-2.1.139-plus.md` |
| 69.1.3 | settings | 在 template 的 baseline 中追加 `autoMode.hard_deny` 的 baseline 7 件 (plugin 本体 settings 由 operator 手动应用) | `templates/claude/settings.security.json.template` |
| 69.1.4 | hooks | 在 rules 中化 hook `args:` exec form / `continueOnBlock` / `SessionStart`/`Setup`/`SubagentStart` 的 command-only 约束 | `.claude/rules/hooks-2.1.139-plus.md` |
| 69.1.5 | hooks | 在 `webhook-notify.sh` / `notification-handler.sh` 中 opt-in 实现 `terminalSequence` (`HARNESS_TERMINAL_NOTIFY`) | `scripts/hook-handlers/webhook-notify.sh`, `scripts/hook-handlers/notification-handler.sh` |

## Tier 2 (Phase 69.2.1-69.2.5) - 更新 policy / docs / agent contract

| ID | Phase | 内容 | 主要 artifact |
|----|-------|------|---------------|
| 69.2.1 | docs | 将 CC native `/goal` policy 化为"限于 session continuation memo" (与 Codex `/goal` 同方针) | `docs/codex-plugin-workflows-policy.md` (rename or augment) |
| 69.2.2 | docs | `claude agents` operator entrypoint + 新 flag 群的 Harness 安全运用 policy | `docs/agent-view-policy.md` (新规) |
| 69.2.3 | agent | 在 Worker / team composition 中明文化 Background agent permission mode 保持的期望值 | `agents/worker.md`, `agents/team-composition.md` |
| 69.2.4 | ci | 在 `scripts/ci/check-consistency.sh` 的 note 中追加 `claude plugin details` 输出的用例 | `scripts/ci/check-consistency.sh` |
| 69.2.5 | rules | 设立 Phase 69 rule SSOT，也在 `opus-4-7-prompt-audit.md` 的 checklist 中追记 | `.claude/rules/hooks-2.1.139-plus.md` |

## Test 追加 / 期望

| Test | 场所 | 期望 |
|------|------|------|
| settings baseline | `tests/validate-plugin.sh` 的 section 4 (settings) | assert `worktree.baseRef` 和 `autoMode.hard_deny` 的存在 |
| hook terminalSequence | `tests/test-terminal-notify.sh` (新规) | `HARNESS_TERMINAL_NOTIFY=osc9` 时输出 `terminalSequence` 字段 |
| rule grep gate | `tests/test-rule-presence.sh` (新规 or 现有 extend) | `.claude/rules/hooks-2.1.139-plus.md` 的必需 anchors 5 件存在 |
| `/goal` SSOT gate | `tests/test-rule-presence.sh` | `docs/codex-plugin-workflows-policy.md` 或同等 doc 中存在"不使用 CC native `/goal` 作为 Plans.md SSOT"的记述 |

## Rollback notes

- `worktree.baseRef: "fresh"` 与 CC 2.1.133 的 default 一致。想选 `head` 的 team 在 project-level settings 中覆盖。
- `autoMode.hard_deny` 的 baseline 不是现有 `permissions.deny` 的 super-set，**只是必需核心 7 件**。不使用 auto mode 的 project 不参照，不受影响。
- `HARNESS_TERMINAL_NOTIFY` 未设置则 disable。与现有 `HARNESS_WEBHOOK_URL` 独立。
- `.claude/rules/hooks-2.1.139-plus.md` 是新规 rule。不改变现有 rules (正交追加)。

## Operator action item (.claude-plugin/settings.json 手动应用)

由于 Harness 的 self-write guardrail (`.claude/rules/self-audit.md`、CLAUDE.md Permission Boundaries)，
plugin 本体 `.claude-plugin/settings.json` 无法被 agent rewrite。
release 时 operator 手动追加以下块：

```json
"worktree": {
  "baseRef": "fresh"
},
"autoMode": {
  "hard_deny": [
    "Bash(sudo:*)",
    "Bash(rm -rf:*)",
    "Bash(rm -fr:*)",
    "Bash(git push -f:*)",
    "Bash(git push --force:*)",
    "Bash(git reset --hard:*)",
    "mcp__codex__*"
  ]
}
```

template (`templates/claude/settings.security.json.template`) 中已写入 baseline。
新規 project setup 时 `harness setup` 展开 template 到 project 时自动反映。

## 関連 docs

- `docs/upstream-update-snapshot-2026-05-07.md` (Phase 62, 2.1.112-2.1.132)
- `docs/upstream-update-snapshot-2026-05-10.md` (Phase 67, Codex 0.130.0)
- `.claude/rules/hooks-2.1.139-plus.md` (Phase 69 新规)
- `docs/agent-view-policy.md` (Phase 69 新规)
- `.claude/rules/cc-update-policy.md` (3 类别分类的 SSOT)
