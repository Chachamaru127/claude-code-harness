# Known Limitations

在真实使用 Harness 时观察到、且根本原因不在 Harness 控制范围内的问题。本文件记录 Harness 所采取的应对措施，以及可以重新审视该限制的触发条件。

---

## Multi-host safety is not uniform (Phase 111)

### Symptom

运维人员可能认为 Claude Code、Codex CLI、Cursor 和 Grok 都会以相同方式阻止危险操作，因为它们都有安装路径。

### Root cause

各 host 在 hook 覆盖范围和遏制（containment）方面存在差异：

| Host | Pre-action stop | Containment notes |
|------|-----------------|-------------------|
| Claude Code | Strong multi-tool PreToolUse | Primary product floor |
| Codex CLI | Bash-only PreToolUse floor + post quality/merge gates | 在 hook 路径上非 Bash 不做 hard-deny |
| Cursor | preToolUse 可 deny（已实证） | **没有传统 FS jail**；allowlist 是 best-effort；非 exit-2 时 fail-open |
| Grok | hookcodec HostGrok 使用 Claude 兼容的 deny envelope | Floor 成员资格是 codec 级别的；project hooks 需要 `.grok/hooks` 配线 |

### Mitigation Harness applies

1. 公开层面的措辞：只有 EN `supported`（当前是 Claude）才标注 正式対応。
2. 能力矩阵 + hardening-parity 文档说明强度差异。
3. 未来任何公开提升的 H1–H8 门槛（`docs/spec/planning-and-host-adapter.md`）。

### Revisit when

Live CI workflow smoke（用 host CLI 跑 plan→artifact）变绿，且 host 特有的遏制限制已在 README 中被接受以进行提升 PR。

---

## cyber-safeguard interruption during security review (#172)

### Symptom

当 `claude-code-harness:reviewer`（Opus 4.7 时代）审查具有安全影响的变更时，它可能检测到问题后，在输出中途以类似 "This request triggered cyber-related safeguards." 的消息停止。
裁定 JSON 从未生成。下游 skill（`harness-release` Review Gate、commit guard 等）看不到 `review-result.json`，工作流就此中断。

### Root cause

这是 Anthropic 的 Opus 4.7 时代产品行为中模型侧的 safeguard。
当模型检测到自身输出正在趋向 exploit code、攻击 PoC 或类似进攻性安全工具的内容时，可以自我中断。
Harness 位于模型之上，无法关闭该 safeguard；那需要推断侧的 opt-out，而这不是 Harness 能控制的。

### Mitigation Harness applies

1. **Reviewer prompt 已被收窄**，将安全发现记录为中性事实（漏洞类型 / 位置 / 严重程度），而不是 exploit code 或 PoC。
   参见 `agents/reviewer.md` § "Security finding 記述ルール"。
2. CVE / CWE / OWASP 标识符仅按 ID 引用；攻击步骤和绕过技术不在正文中展开。
3. 缓解指导描述修复方向（例如「使用参数化查询」「对输入进行转义」），而不是攻击手法。

这缩小了触发 safeguard 的范围，但并未消除它。
模型仍可能将某一段判定为过于接近进攻性内容，即使按这些规则撰写。

### Workarounds for operators

当 safeguard 仍然触发时：

- **对安全重度 PR 切换到 Opus**。Opus 系列的 safeguard 校准与 Fable 不同。设置 `--model claude-opus-5`，或通过您的设置固定 reviewer 模型（Opus 4.8 已于 2026-07-25 从 Harness 目录中退役）。
- **将纯安全 PR 上升级为人工审查**。对于其全部目的就是 exploit 研究或 red-team 工具的变更，Harness 的自动 reviewer 不是合适的 gate。
- **用手动收窄的 prompt 重新运行**。如果只是某一条发现触发了 safeguard，请用会话指令「Skip the PoC sketch, just list the file:line and CWE id.」重新运行 reviewer。

### Trigger to revisit

- Anthropic 发布了有文档说明的 cyber-safeguard opt-out 或 per-prompt 抑制机制。
- 后继模型在文档中说明该 safeguard 在安全审查用例中已移除。
- 出现某种模式：遵循当前「仅中性事实」规则的发现仍会触发 safeguard；那将意味着该规则不够严格，prompt 需要再迭代一次。

### Related

- Issue [#172](https://github.com/Chachamaru127/claude-code-harness/issues/172)
- `agents/reviewer.md` § Security finding 記述ルール
