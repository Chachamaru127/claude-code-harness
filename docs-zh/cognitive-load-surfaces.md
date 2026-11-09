# 降低认知负荷的 3 个 HTML 界面 (Phase 65)

让非工程师也能在 3 秒内把握 Claude "在思考什么"、"现在在哪里"、"完成了什么" 的 3 个 HTML 界面。

## 想做的事

与 AI 一起开发时，持续阅读 commit log 和 Plans.md (=任务列表 markdown) 认知负荷很高。
为发包方、制作人、经营者提供 3 种能在浏览器中打开就一目了然的单页 HTML。

| Surface | 为什么 | 何时查看 |
|---------|----------|----------|
| **Plan Brief** (动工前) | "Claude 是这样理解的。这样开始可以吗?" | 实现前的审批 |
| **Progress Tracker** (施工中) | "现在进行到哪里了，预计何时完成?" | 任意时机（自动再生成） |
| **Acceptance Demo** (交付时) | "这个成果物，您接收吗?" | 实现完成后的验收 |

## 做法

### Plan Brief (第 1 个界面)

```bash
# Claude セッション中に
/harness-plan-brief
```

Claude 将以下内容汇总到 1 页 HTML:
- 用户要求的 Claude 侧理解
- 选项（如果做法有多种则 each option）
- 风险（容易卡住的地方）
- 验收条件 (acceptance_criteria)
- 确信度 (0-100，有依据)

用户返回 "OK 开始"、"请修改这里"、"有疑问"。
判断以 `personal-preference.v1` schema 记录（附 sha256 哈希）。

### Progress Tracker (第 2 个界面)

```bash
# 進捗確認
/harness-progress
```

或 PostToolUse hook 在 Edit/Write/Bash 触发时 **每 60 秒** 自动再生成。

显示内容:
- progress_pct (cc:完了 / 总任务 × 100)
- 当前 WIP 任务
- 最近完成任务 5 件
- 未开始任务 5 件
- drift alert (5 种，severity 颜色区分: 红=critical / 黄=warn / 蓝=info)

### Acceptance Demo (第 3 个界面)

```bash
# 実装完了後
/harness-accept
```

Claude 将以下内容汇总到 1 页 HTML:
- 判定 (ship / wait / reject 三选一)
- 验收条件的验证（Plan Brief 各项目标记 "已确认"/"未确认"）
- 未验证的保留事项
- 过去的问题模式历史
- 提示成果物列表

用户返回 accept / override / reject。
判断以 `acceptance-decision.v1` 记录，与 Plan Brief 使用 **相同的 user_request_hash** 可进行 graph join。

## 注意事项

### 1. Plan Brief 和 Acceptance Demo 通过 user_request_hash 连接

启动 Plan Brief 时取 "用户要求文" 的 sha256 哈希并保存到 record。
Acceptance Demo 也取相同哈希并保存到 record。
**这 2 条 record 可以通过相同哈希从 `mcp__harness__harness_mem_search` 进行 graph join**。

实现 "那时那个计划，结果如何?" 的完整回顾机制。

### 2. Progress Tracker 的 rate limit (60 秒)

即使 PostToolUse hook 引起大量 Edit/Write（大型重构），HTML 再生成也限制为每 60 秒 1 次。
state file: `.claude/state/progress-last-regen.txt` (epoch seconds)。

### 3. drift alert 在 session 内累积，不持久化

5 种 alert (scope-creep / time-overrun / repeated-failure / cost-warning / high-risk-file) 是 Progress Tracker HTML 中显示 1 个 session 内状态的。
**不持久化到内存** (issue #87 方针，Lead 进程 in-memory 仅)。

用户对过去 alert 的判断由 `progress-past-judgments.sh` 汇总显示 "过去 N 件中 M 件同样提案被拒绝"，但这作为 `alert-judgment.v1` record 有 permanent storage 的设计余地（本阶段未实现）。

### 4. 客户信息处理

使用 `--cross-project-group <name>` flag 启用 cross-project search 时，
**3 层 redaction** (Layer 2a 字典 + Layer 2b NER + Layer 3 final scan) 自动应用。
详见 [cross-project-safety.md](cross-project-safety.md)

## 相关文件

| 文件 | 用途 |
|---------|------|
| `skills/harness-plan-brief/` | Plan Brief skill (Phase 65.1) |
| `skills/harness-accept/` | Acceptance Demo skill (Phase 65.2) |
| `skills/harness-progress/` | Progress Tracker skill (Phase 65.4) |
| `templates/html/plan-brief.html.template` | Plan Brief HTML 模板 |
| `templates/html/accept.html.template` | Acceptance Demo HTML 模板 |
| `templates/html/progress.html.template` | Progress Tracker HTML 模板 |
| `scripts/render-html.sh` | mustache 风 template renderer (`--with-redaction` flag 对应) |
| `scripts/plan-brief-record-decision.sh` | Plan Brief 判断记录 |
| `scripts/accept-record-decision.sh` | Acceptance Demo 判断记录 |
| `scripts/progress-snapshot.sh` | Plans.md → snapshot JSON |
| `scripts/progress-detect-drift.sh` | 5 种 alert kind 检测 |
| `scripts/progress-past-judgments.sh` | 过去判断 lookup |
| `scripts/hook-handlers/posttool-progress-regen.sh` | PostToolUse 自动再生成 hook |

## 相关 schema

- `plan-brief-context.v1` (Plan Brief render input)
- `acceptance-context.v1` (Acceptance Demo render input)
- `progress-snapshot.v1` (Progress Tracker render input)
- `personal-preference.v1` (Plan Brief 判断记录)
- `acceptance-decision.v1` (Acceptance Demo 判断记录)
- `progress-alert.v1` (drift alert)
