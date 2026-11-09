# 零基础重新设计 — 0 ベース再设计提案（最终模型）

状态：**实现完成** — Phase 91.1–91.8 已实现到本 repo (2026-06-06)。
分发模型从最初草稿的"manifest/mirror 为 untrack + gitignore + install 时生成"落地为
**generated-and-committed + CI drift-check**。原因：Claude plugin marketplace
直接 clone repo 并读取 `.claude-plugin/*`，Codex/OpenCode 的 setup script
复制 committed mirror — ＝ install 时无 `harness gen` 路径，untrack 会导致分发破坏。
权威契约是 root `spec.md` 的 Host Distribution Contract（本文的"gitignore 生成物"描述是最初方案的历史记录）。
基础 commit：v4.14.0 (`4c26acd9`)
方法：18-agent 多视角工作流（4 独立方案 → 2 镜计分 → 综合）＋ owner review 4 往返收敛
置信度：**高**
相对侧：[cursor-adapter-candidate.md](./cursor-adapter-candidate.md)（ACP 未采用的旧判断。本文将其更新为"通过 native hook 收敛 ACP 不需要 enforcement"）

> 主题：如果将与当前 Claude Code 一起构建的东西，在考虑 CC 更新、Codex/Cursor 对应和情况变化的基础上，从零开始重建，会怎样？
> owner 约束：不需要后向兼容/阶段性引入 / 可以脱离插件层 CLI 化 / ACP 不需要。

---

## 结论（最终模型）

**脱离插件成为单一 CLI 二进制文件 `harness`。** 架构为 **1 模型**：

> **生成的 skill/agent ＋ 单一 harness CLI ＋ 各 host 的 native hook（全部调用同一个 `bin/harness hook pretool`，deny 统一为 exit 2）＋ 全 host 共同的 FLOOR。ACP 不采用。**

- value-bearing Go 约 20%（R01-R13 policy engine 等）verbatim 保留。
- host 耦合约 80%（4 manifest・mirror 树・95 hookhandler・7-way 版本同步）删除。
- host 差分在 `hosts.toml` 1 个文件。各 host 的薄 shim（skill/agent/hooks.json）由 `harness gen` 生成（gitignore）。
- **enforcement 为 3 host 都通过 native 事前阻止**（Claude/Codex/Cursor 全部拥有 `PreToolUse` 系 hook）。ACP 和 companion 整体委托对 enforcement 都不需要。

---

## 为什么是这个结论（判断轴）

当前结构的"原罪"是 **R01-R13  guardrail 被螺栓固定在 CC 的 hook bus 上**，只有 Claude 被保护。最初的重设计方案试图用 ACP（per-action gating 通用协议）来均衡。

**但 owner review 和 3 个官方文档确认确定 ACP 不需要。** Claude / Codex / Cursor 3 个 host 都已收敛到**与 CC 几乎相同的 native hook（`PreToolUse` 系、`permission deny` / exit 2、`hooks.json`）**。修正不是 ACP，而是：

> **仅生成各 host 的 native hook 调用"同一个 `bin/harness hook pretool`"。1 个 policy engine adjudicate 3 个 host。**

这是"复制而非 routing"（1 个 engine 从多个 trigger 调用）的最简单实现，完全不需要 ACP/协议的新实现。

---

## 更新历史（2026-06-05 收敛）

本文最初推荐"C 的脊柱 + A 的 ACP opt-in seam"，但通过 owner review 4 往返更新为**ACP 不采用・native hook 收敛**。经过：

| 往返 | owner 指出 | 设计反映 |
|---|---|---|
| 1 | ACP 不需要 | 将 ACP 降格为 opt-in seam（最初） |
| 2 | Codex/Cursor「从」使用的运营存在（host→harness 方向） | 将 direction #2 升格为一级市民。与 #1（harness 驱动）分离 |
| 3 | 能否全部统一为"生成的 skill/agent + harness CLI"。Codex 也有 Agent 和 hook | 承认 3-tier enforcement 分隔过度，简化为 1 模型 |
| 4 | 确认官方文档 | **确认 Codex/Cursor 都有 native pre-action hook → 将 ACP 完全从 enforcement 中排除（不采用）** |

确认的官方文档（2026-06-05）：
- developers.openai.com/codex/hooks
- cursor.com/ja/docs/hooks
- （Claude Code hooks 在现有实现中确认）

---

## 3 host 的 hook 收敛到同一模型（本文依据）

| | Claude Code | Codex | Cursor |
|---|---|---|---|
| 事前阻止事件 | `PreToolUse` | `PreToolUse` | `preToolUse`（＋ `beforeShellExecution` / `beforeMCPExecution` / `beforeReadFile`） |
| deny 手段 | `permissionDecision:"deny"` / **exit 2** | `permissionDecision:"deny"` / **exit 2** | `permission:"deny"` / **exit 2** |
| 配置文件 | `hooks.json` | `hooks.json` | `hooks.json` |
| 配置位置 | `.claude-plugin/` | `~/.codex/`・`<repo>/.codex/` | `~/.cursor/`・`<repo>/.cursor/` |
| 横切目标 | Bash/Edit/Write/MCP | Bash/`apply_patch`/Edit/Write/MCP | shell/file/read/MCP |
| 任意 command hook | ✅ | ✅ | ✅ |
| stdin（差分） | `session_id`, `tool_name`, `tool_input` | `session_id`, `tool_name`, `tool_input`, `tool_use_id` | `conversation_id`, `tool_name`, `command`/`file_path` |

**共同点 = "type:command 的 hook 能以 exit code 2 deny"。** 这在 3 个 host 上都有效，因此 host 之间的输出 JSON 差分甚至不需要吸收（`bin/harness hook pretool` 在 deny 时 exit 2）。剩余差分（`permissionDecision` vs `permission`、`session_id` vs `conversation_id`、事件名 casing）由 **harness hook 侧的薄 stdin codec 1 个文件**正规化，rule engine 本体不变。

---

## 采用模型的架构

图：[redesign-visuals/after.svg](./redesign-visuals/after.svg)（PNG・before/after・HTML 也在同一文件夹）

```
   you ── harness work 1.1.1 / plan / review / release / gen / doctor ──▶ harness（単一CLIバイナリ）

   ┌──────────────── hosts.toml（host差分はこの1枚）──▶ harness gen ──▶ 各host の shim を生成（gitignore）────────────┐
   ▼                                   ▼                                   ▼
 ┌──────────────┐                ┌──────────────┐                  ┌──────────────────────┐
 │ Claude Code   │                │ Codex        │                  │ Cursor                │
 │ 生成 skill/agent│                │ 生成 skill/agent│                  │ 生成 skill/agent       │
 │ native hook:  │                │ native hook: │                  │ native hook:          │
 │ PreToolUse    │                │ PreToolUse   │                  │ preToolUse (+before*) │
 └──────┬───────┘                └──────┬───────┘                  └──────────┬───────────┘
        │  deny=exit2                   │  deny=exit2                          │  deny=exit2
        └───────────────────────────────┴──────────────────────────────────────┘
                                         ▼  （3 host が native 合流）
                       ┌───────────────────────────────────────────────┐
                       │  bin/harness hook pretool ＝ 単一の enforcement 面 │
                       │  → R01–R13 policy engine（核・約80%再利用・stdlib）│
                       └───────────────────────┬───────────────────────┘
                                               ▼  ★ FLOOR（全 host 共通の最終 backstop）
                       ┌───────────────────────────────────────────────┐
                       │  worktree + cherry-pick で harness policy check 再評価 │
                       │  → nested subagent / in-proc shell の穴を埋める      │
                       └───────────────────────────────────────────────┘
  ACP: 不採用（native hook で per-action gating 達成済み）
  companion 丸投げ: 「harness が他ツールを engine として駆動する」時だけ（direction #1 専用）
```

### 两个方向都支持

| 方向 | 谁是主角 | harness 的立场 | enforcement |
|---|---|---|---|
| #1 harness 驱动 | harness | 司令塔（spawn engine） | companion + FLOOR |
| **#2 从 host 使用**（Codex/Cursor「从」使用） | host | 生成的 skill/agent ＋ `harness` CLI ＋ host 的 native hook | **native 事前阻止 ＋ FLOOR** |

#2 在最初方案中被低估，但由于 3 个 host 都有 native hook，**是 full enforcement 的一级市民**。

---

## 7 个核心判断（更新版）

| # | 判断 | 选择 | 置信度 |
|---|------|------|-----------|
| 1 | Go 核心再利用 vs 重建 | **Kernel-Extraction**。将 `go/internal/guardrail` 晋升为 stdlib-only `policy/`。verbatim 再利用 membridge(244 LOC)・config・operator CLI・trimmed state。复活 dead 的 breezing.Orchestrator | high |
| 2 | 是否采用 ACP | **不采用**。3 个 host 都有 native pre-action hook，因此 ACP 的 enforcement 价值为零。剩余价值仅为 live streaming UX（owner 明确不要）。将来想要 streaming 时 opt-in 重新考虑 | high |
| 3 | uniform enforcement 的实现 | **复制而非 routing**。各 host 的 native hook 调用同一个 `bin/harness hook pretool`。deny 统一为 exit 2。3 个 host 都通过 native 事前阻止 | high |
| 4 | mirror/manifest/version-sync 税 | **`harness gen`** 从 `hosts.toml`+promptpack 生成全 host artifact（各 host 的 hooks.json 也生成：Claude=`.claude-plugin/hooks.json`、Codex=`.codex/hooks.json`、Cursor=`.cursor/hooks.json`，全部指向 `bin/harness hook pretool`）。`--check` 与 golden fixture 进行 CI diff。生成物 gitignore | high |
| 5 | 是否脱离插件层 | **near-total**。一次分发 = 单一 CLI binary。manifest 和 hooks.json 是生成的 build-artifact。通过各 host 的 native hook 进行的 in-proc 事前阻止在所有 host 上保持 | high |
| 6 | orchestration / 并行 | **Go-native**。复活 breezing.Orchestrator、N 个 flat sub-run。harness 拥有所有 fan-out，backend 是单线程（将 nested 问题还原为"N flat seam"） | high |
| 7 | Plans.md 模型 | agent-read markdown SSOT 保持不变。Go 仅做 marker-tally drift heuristic | medium |

---

## 什么死了，什么诞生了

### 将死的

- 将 4 个 manifest 作为手写 source 持有（→ `harness gen` 的 gitignore 生成物）
- skill mirror 基础（codex/.codex/skills 183・opencode/skills 182・skills-codex・sync-skill-mirrors.sh・build-opencode.js ≈365 文件）→ install 时生成
- 7-way 版本同步（sync-version.sh 等）→ 1 个 git tag
- 将两个 companion script 作为"enforcement 的主要路径"（companion 降格为 direction #1 专用，正规化为 `companion-result.v1`）
- breezing.Orchestrator 的 dead code 状态（复活）。breezing skill(445L)→ harness-work `--team` mode
- 27-event hook surface 的大部分 + proprietary-event→AdditionalContext glue 系 hookhandler（intent 是 kernel service 化）
- 将 sub-5ms hook-fastpath budget 作为第一约束（在长命/CLI process 中无意义）
- migration/self-audit scaffolding 常驻（check-residue.sh・deleted-concepts.yaml・self-audit.md）→ 将 deny-list 折叠到 policy/
- version-pinned 上游追从 rule file（hooks-2.1.139/152-plus.md 等）→ **capability-detection 层**（官方文档确认发现 stale 的反思：能力通过 runtime/doc 确认来持有）
- ~22 个 skill 积累（auth/crud/ui/deploy・media gen・session cluster・coaching cluster）
- drifted/dangling docs（CLAUDE-skill-catalog.md・scaffolder 引用）
- **ACP adapter（最初方案的 opt-in seam）→ v1 删除**。native hook 收敛后不需要

### 将诞生的

- 单一分发 binary `harness`。kernel = policy/（R01-R13・deny-list self-audit 捆绑）・plans/・membridge/・scanner/・gitport/（17 exec.Command 合并为 1 seam）・state/（trimmed）・orchestrator/（复活）・embedded promptpack
- prompt pack 1 个 = skill+agent 的 irreducible SSOT
- `hosts.toml` — host-capability 描述符。每 host：tools-available・hook 事件名（`PreToolUse`/`preToolUse`）・deny 手段・transport・model/effort
- **`harness gen`** — 生成全 host artifact（**也生成各 host 的 hooks.json**：Claude=`.claude-plugin/hooks.json`、Codex=`.codex/hooks.json`、Cursor=`.cursor/hooks.json`，全部指向 `bin/harness hook pretool`）。`--check` 与 golden fixture 进行 CI diff。生成物 gitignore
- **`harness hook pretool`** — 3 host 共同的单一 enforcement 面。stdin codec 正规化 host 差（`permissionDecision`/`permission`、`session_id`/`conversation_id`），deny 为 exit 2
- **`harness policy check`** — cherry-pick FLOOR 和 hook 都调用的 R01-R13 surface
- companion-result.v1 — direction #1（harness 驱动）的统一 return envelope
- self-verifying policy ruleset（deny-surface baseline hash、弱化时拒绝启动）
- opt-in cognitive-load extension pack（plan-brief/progress/accept）作为独立可安装包
- capability-detection 层（host 的 hook 事件名・对应能力通过 runtime/doc 来源数据持有）

---

## 阶段草图（更新版・无 ACP phase）

※ 根据 owner 约束，big-bang cutover（无后向兼容）。每个 phase 保持 green 的单位。

0. **Kernel extraction（行为不变）**：`guardrail`→`policy/`（stdlib+regexp）、membridge verbatim、17 exec.Command 合并为 `gitport/` 1 seam、state/ trim。保持 rules_test.go green = regression anchor。
1. **`harness` CLI 脊柱**：policy/+plans/+membrane/+state/+gitport/ 作为 `harness plan|work|review|release|sync|policy check|hook|doctor|mem` 的背后。embed prompt pack。在 Claude 上 headless 循环可运行。dogfood。
2. **`hosts.toml` + `harness gen`**：定义单一描述符，生成器发出 **3 host 的 hooks.json**（全部 `bin/harness hook pretool`）+ skill/agent + manifest version + docs。`--check`。生成物 gitignore。**这消除了 mirror/version 税**。
3. **3 host hook 布线 + stdin codec**：在 `harness hook pretool` 中添加 host 差正规化 codec（`permissionDecision`/`permission`、`session_id`/`conversation_id`、事件名）。生成并布线 `.codex/hooks.json`・`.cursor/hooks.json`（当前为空）。通过冒烟测试确认 3 host 的 native 事前阻止都有效。
4. **orchestrator + companion(direction #1) 路径**：复活 breezing.Orchestrator（N flat sub-run）。将 companion 正规化为 `companion-result.v1`（仅在 harness 将其他工具作为 engine 驱动时）。breezing 变为 --team mode。
5. **FLOOR 强化**：对 cherry-pick diff 调用 `harness policy check` + contract-grep（test-support-claim-wording.sh + check-consistency.sh + validate-plugin.sh）作为所有 backend 的必需 pre-merge。将 deny-list self-audit 折叠到 policy/。
6. **prune + docs 重新生成**：删除 ~22 个 accumulated skill、migration/self-audit scaffolding、version-pinned rule file（→capability-detection）。`harness gen docs` 重新生成 CLAUDE.md/catalog。
7. **cutover 验证**：在 harness repo 自身上用 `harness work` 进行 1 个完整 Plan→Ship 周期。通过后才从 committed source 删除旧 manifest/mirror。

（旧 Phase 5"opt-in ACP adapter"删除。native hook 收敛后不需要。）

---

## owner 应决定的 open question（更新版）

| # | 问题 | 状态 / 建议 |
|---|------|------|
| Q1 | 需要在 IDE 内运行 vs headless | **解决**：host 常驻（#2）和 headless（#1）都是**一级**。3 个 host 都通过 native hook 运行。"headless-first"的旧建议撤回 |
| Q2 | launch 时的第一优先级 backend | Claude + Codex + Cursor 为 v1（3 个 host 都有 native hook）。Gemini 可选 |
| Q3 | 需要 per-action gating 吗 | **解决**：通过 native hook 3 个 host 都可以事前阻止。ACP 不需要。FLOOR 是共同的 backstop |
| Q4 | ~22 个 accumulated skill | 全部删除（owner 的 brand-doc skill 在 ~/.claude global 中） |
| Q5 | self-bootstrap | 用当前 harness(v4.14.0) 构建 v1 → 自我 dogfood 后删除旧结构。始终保持 rules_test.go green |

剩余判断点仅为 Q2/Q4/Q5（scope 和删除范围）。ACP / enforcement model 已确定。

---

## 异议/pushback（更新版）

1. **（旧异议 #1"ACP 过度指定"→ 加强并确定）**：owner 的"ACP 不需要"是正确的，3 个官方文档也从技术上支持。cross-tool 协调不需要 ACP，通过"1 个 orchestrator + 各 host native hook 在同一 policy engine 汇合"实现。ACP 能添加的仅为 live streaming UX，owner 也不要。→ **ACP 完全从 v1 移除**。
2. **kernel-extraction over rebuild 保持**：value-bearing core（EvaluateRules pure・membridge 244 LOC）仅占 ~20% 且已测试。丢弃重建是在最错误的地方付出最大成本。削减 tax 的 ~80% 保留 IP。
3. **自我异议（最大风险）= big-bang cutover**：v4.0.0"Hokage" TS→Go 迁移也声称 clean one-shot，但留下了 13 件 residue（check-residue.sh 诞生的原因）。本项目的历史说"big-bang 会遗漏"。缓解是将 Phase 7 的自我 dogfood 作为 hard gate。不走并走（dual-maintenance），因为 redesign 要删除它。
4. **新注意（stale risk）**：我最初相信 repo 内备忘录（codex/AGENTS.md"Hooks 未支持"）错误地说 Codex hook 很弱。**外部工具的能力应通过官方文档每次确认**。这是"将 version-pinned rule file 替换为 capability-detection"的动机本身。

---

## 考虑的 4 方案和分数（决定 provenance）

2 镜（pragmatist / visionary）× 6 轴 30 分满分。

| 方案 | 一句话 | 总分 |
|---|---|---|
| **A** CLI-first ACP Orchestrator（harness=ACP CLIENT，通过 ACP 驱动所有 backend） | 52 |
| **C** Kernel + Prompt Pack（engine 再利用 + 生成 shim，~80% Go 再利用） | 50 |
| B Protocol-native Hub（ACP-on-both-edges，daemon） | 47 |
| D Harness-as-Agent（自备 agent loop，API 直击） | 44 |

最初采用"C 的脊柱 + A 的 ACP seam"，但**owner review 中 A 的 ACP 部分被 native hook 收敛替换，实际上收敛为"C 的脊柱 + 3 host native hook"**。A 的 per-action gating 目的通过各 host 的 native hook 免费实现。

---

## 验证的外部事实（赌注依据）

- `EvaluateRules` 是 first-match-wins，import 仅为 stdlib+regexp+hookproto → 只需将 trigger 从 hook-stdin 指向各 host hook，rule table 不变。
- `breezing.Orchestrator`(333 LOC) 是从测试外部调用的 dead code（复活对象）。
- **3 个 host 都有 native pre-action hook（官方文档确认）**：Claude `PreToolUse` / Codex `PreToolUse` / Cursor `preToolUse`，都能 deny + exit 2、hooks.json、可执行任意 command。
- **exit code 2 = deny 在 3 个 host 上通用** → 可以创建吸收 host 差的单一 enforcement 面。
- anthropics/claude-code#27203: nested sub-agent 绕过 gating → FLOOR 是所有 host 都需要的原因。

---

## 相关

- [redesign-visuals/](./redesign-visuals/) — before/after 图（SVG/PNG）＋说明 HTML
- [cursor-adapter-candidate.md](./cursor-adapter-candidate.md) — ACP 未采用的旧判断（本文通过 native hook 收敛更新）
- `go/DESIGN.md` / `go/SPEC.md` — 当前 v4 Go 架构（extraction 来源）
- `.claude/rules/migration-policy.md` — exclusion-based 验证（big-bang 遗漏对策、异议 #3 依据）

来源（2026-06-05 确认）：developers.openai.com/codex/hooks ／ cursor.com/ja/docs/hooks ／ Claude Code hooks（现有实现）
