# AppleScript 决定记录 — 仅允许 activate / open -a

Status: **已决定** (Phase 93.1.2, 2026-06)
Scope: Cursor  backend companion / macOS 自动化
Rule SSOT: `.claude/rules/cursor-cli-only.md` 的「AppleScript 策略」节

---

## 决定

AppleScript 以及 macOS shell 自动化，**仅允许 `activate`（应用前台化）和 `open -a`（应用启动）**。
**禁止通过 `System Events` 的 keystroke / click 注入**（2026-06 决定）。

### 背景

- UI 事件注入（键盘输入・点击）与用户操作无法区分，会绕过 Harness hook 层的 deny。
- 应用启动・前台化的副作用有限，不与 PreToolUse / R01-R13 冲突。
- 更广泛的 AppleScript 权限，延后到来源识别・sandbox・hook 对应齐全后再讨论。

---

## 再提升 4 条件

以下**任一**条件满足时，重新讨论包含 System Events 注入的 AppleScript 使用。
不需要全部 4 个条件都满足，但需明确各条件消除的风险。

### 1. hook input 添加 source-identifier

**什么变了可以向安全侧倾斜**: PreToolUse / hook 输入中附加注入事件的来源标识符
（agent / user / automation 等），可以机械地将 UI 注入与用户输入区分开来。
如果 hook deny 建立了不可绕过的审计路径，可以限定性地重新允许 System Events。

### 2. Read tool 扩展 sandbox

**什么变了可以向安全侧倾斜**: Read tool（及相关 file access）在 macOS sandbox 下
可以更严格地 confine 路径・权限，缩小 AppleScript 意外文件/UI 操作的
泄露面积。如果封堵生效，可以阶段性扩大自动化的允许范围。

### 3. Codex hooks 对非 Bash 事件对应

**什么变了可以向安全侧倾斜**: Codex 侧 hook 能够捕获・deny Bash 以外的事件（AppleScript 执行、
UI 操作等）达到 PreToolUse 相当。如果 3 host 跨域的同一 policy engine 能够
adjudicate 非 shell 自动化，注入路径也能纳入 guardrail 范围内。

### 4. Cursor 提供 AppleScript dictionary

**什么变了可以向安全侧倾斜**: Cursor 提供官方 AppleScript dictionary（允许 verb ・
副作用的契约），agent 可以带类型引用「什么可以做」。
可以从不公开文档的 System Events 滥用迁移到仅使用契约化 API 的运用。

---

## 相关

- `.claude/rules/cursor-cli-only.md` — AppleScript 策略（运用规则）
- `docs/research/cursor-adapter-candidate.md` — Cursor  backend 采用判断
- `docs/research/zero-base-redesign-2026-06.md` — 3 host native hook 收敛
