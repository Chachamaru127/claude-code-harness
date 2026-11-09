# Claude Code Harness v3.10 — X (Twitter) 帖子树

> **发帖时机**：工作日 19:00〜21:00（工程师下班后的黄金时间）
> **目标**：对 AI 支援开发感兴趣的日本开发者

---

### 🧵 1/6

用"Plan → Work → Review"自律运营 Claude Code 的 Harness，升级到 v3.10 了。

整理了 Claude Code 2.1.50〜2.1.74 的全部功能，将 50 以上的 entry 汇总到 1 个 Feature Table。

"这个功能，怎么使用？"的答案在这里。

🔗 github.com/Chachamaru127/claude-code-harness

#ClaudeCode #AIDevTools #Harness

---

### 🧵 2/6

⚡ Auto Mode 对应

作为 Claude Code 的 Research Preview 开始的 Auto Mode。

在 Harness 中整理了 bypassPermissions → Auto Mode 的阶段过渡。

・shipped default 维持 bypassPermissions
・--auto-mode 是 opt-in 阶段引入
・与 Hooks 多层防御并用，安全自律运营

"安全 AI 自律运营"的现实桥梁。

#ClaudeCode #AutoMode #AIDevTools

---

### 🧵 3/6

🤖 Agent Teams 进化

向 SubagentStart / SubagentStop 添加了 matcher。可以个别追踪 Worker・Reviewer・Scaffolder・Video Generator 的启动和停止。

进一步：
・任务依赖关系的自动管理
・符合 5-6 tasks/teammate 的官方最佳实践
・在 agent 定义中声明性地描述 permissionMode

团队的可视化和控制更上一层。

#ClaudeCode #AgentTeams #Harness

---

### 🧵 4/6

🛠️ 开发体验大幅提升

📊 Status Line — 常时显示上下文使用率・成本・git 状态。超过 90% 用红色警告。

⏪ Checkpointing — 用 `/rewind` 将会话内任意点回滚。从调试迷路中脱出。

🔒 Sandboxing — OS 级别的文件系统/网络隔离。bypassPermissions 的补充层。

地味但每天使用的功能。

#ClaudeCode #DevEx #AIDevTools

---

### 🧵 5/6

📖 Feature Table 完全版

Claude Code 2.1.50〜2.1.74 的功能中 Harness 如何活用的，汇总到 1 个表。

50+ entry、1,000 行以上。

Agent Memory, Worktree, Hooks, Chrome Integration, LSP 集成, 1M Context...

开发者的"Claude Code 功能辞典"。

🔗 docs/CLAUDE-feature-table.md

#ClaudeCode #Harness #AIDevTools

---

### 🧵 6/6

🔄 Harness 是 self-referential

这个插件本身，使用 Harness 来改善自身。

用 `/breezing` 启动 Agent Teams → Worker 实现 → Reviewer review → Harness 自身写代码。

dogfooding 的极致。

想试试看的人👇
🔗 github.com/Chachamaru127/claude-code-harness

⭐ 收到会很振奋

#ClaudeCode #AIDevTools #Harness

---

## 图像 prompt 候选（Nano Banana Pro / Gemini 图像生成用）

### Post 1 用

```
A sleek infographic showing the "Plan → Work → Review" cycle as three interconnected nodes in a circular flow diagram. Dark background with blue and purple gradient accents. Text "v3.10" prominently displayed. "50+ Features" badge in the corner. Modern tech aesthetic, clean lines, minimal design. Japanese text labels for each node: 計画, 実装, レビュー. 16:9 aspect ratio.
```

### Post 2 用

```
A diagram showing a migration path from "bypassPermissions" to "Auto Mode" with a bridge metaphor. Left side labeled "Current: bypassPermissions" in blue, right side "Future: Auto Mode" in green, bridge in the middle with safety guardrails. Shield icons representing Hooks defense layers. Dark tech background. 16:9 aspect ratio.
```

### Post 3 用

```
Four agent icons (Worker, Reviewer, Scaffolder, Video Generator) arranged around a central monitoring dashboard with tracking lines for each role. Each agent has a distinct color: Worker in blue, Reviewer in green, Scaffolder in orange, Video Generator in magenta. Metrics and status indicators floating around each agent. "SubagentStart/Stop" label. Dark background, modern UI style. 16:9 aspect ratio.
```

### Post 4 用

```
A developer's terminal screen showing three feature panels: Left panel shows a status bar with context usage meter (gradient from green to yellow to red at 90%), cost counter, and git branch. Center panel shows a timeline with rewind points marked as checkpoints. Right panel shows a sandbox container with lock icon. Dark theme terminal aesthetic. "DevEx" header text. 16:9 aspect ratio.
```

### Post 5 用

```
A large reference book or encyclopedia open to a two-page spread, with a dense feature table visible on the pages. "50+" floating above the book as a badge. Small icons representing different features scattered around: gears, terminal, brain, shield, git branch. Title "Claude Code Feature Dictionary" on the cover. Blue and purple color scheme, dark background. 16:9 aspect ratio.
```

### Post 6 用

```
An ouroboros (snake eating its own tail) reimagined as a code loop: a plugin icon that points to itself with arrows labeled "improve". The cycle shows: "Harness writes code" → "Code improves Harness" → repeat. GitHub star icon in the corner with a sparkle effect. "Self-Referential" label. Minimal, modern design with dark background and accent colors. 16:9 aspect ratio.
```
