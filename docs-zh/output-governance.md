# Output Governance Policy

最终更新: 2026-05-05

本文档定义了 Hook 和自动格式化处理 Claude Code 工具输出时的安全策略。

## 一句话总结

`PostToolUse.hookSpecificOutput.updatedToolOutput` 默认不使用。
如需使用，仅限于 opt-in 的 redaction / compaction / normalization，并保留审计证据和 review / test 证据。

## 打个比方

工具输出就像作业现场的监控录像。
可以为了便于阅读而做摘要，但不能擅自裁剪可能成为事故证据的部分。

## 策略

| 项目 | 判断 |
|------|------|
| 默认行为 | 不返回 `updatedToolOutput` |
| 允许用途 | 显式 opt-in 的 redaction、compaction、normalization |
| 禁止用途 | 隐藏 test failure、review finding、security finding、command error |
| 审计证据 | 保留原始输出的保存位置、转换理由、转换规则 |
| 输出契约 | stdout 为单一 JSON 对象。说明日志输出到 stderr |

## 允许的转换

### Redaction

用于遮蔽秘密信息的转换。

例:

- 将 API key 替换为 `<REDACTED:api-key>`
- 将 access token 替换为 `<REDACTED:token>`
- 将个人信息替换为 `<REDACTED:personal-data>`

禁止:

- 删除整行错误
- 删除 failing test name
- 删除 review finding 的 file:line

### Compaction

用于缩短大量输出的转换。

例:

- 折叠成功日志中的重复行
- 摘要化超过 1000 行的 dependency install log
- 在末尾保留 `full_output_path` 并将全文保存到文件

禁止:

- 省略 failure summary
- 同时删除 stack trace 的开头和结尾
- 删除 `pytest`、`vitest`、`go test`、`npm test` 的失败位置

### Normalization

用于统一显示差异的转换。

例:

- 将绝对临时路径替换为 stable placeholder
- 将 timestamp 替换为 `<TIMESTAMP>`
- 移除 progress spinner 的控制字符

禁止:

- 改变 exit code 的含义
- 将 stderr 显示为成功
- 替换 review / test 的判定语

## JSON stdout contract

Hook 向 Claude Code 返回结构化输出时，stdout 仅包含 JSON。
面向人类的日志输出到 stderr。

最小形式:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse"
  }
}
```

使用 `updatedToolOutput` 时:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "updatedToolOutput": "redacted or compacted tool output",
    "additionalContext": "Output was redacted with policy output-governance.v1. Full output is stored at .claude/state/audit/tool-output/<id>.log."
  }
}
```

必要条件:

1. 不在 stdout 中混入 JSON 以外的内容。
2. 返回 `updatedToolOutput` 时确认 opt-in 设置。
3. 保存 full output 或可恢复的 audit record。
4. 在 `additionalContext` 或 audit record 中保留转换理由和转换类型。
5. 不删除 review / test evidence。

## Harness 默认值

Harness 的默认行为是不使用 `updatedToolOutput`。
原因是，如果擅自缩短 review 和 test 的依据，之后就无法追踪"是否真的失败了"、"修复了什么"。

仅在需要时，在各个 hook 中显式指定以下内容。

```json
{
  "outputTransform": {
    "enabled": true,
    "mode": "redact",
    "auditTrail": true
  }
}
```

此配置名仅为 policy 示例，实现方持有等效的 opt-in 即可。
重要的是"默认不改写"、"改写后可追踪"、"不删除质量证据"这三点。
