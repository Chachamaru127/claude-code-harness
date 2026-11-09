# Live CLI smoke——仅复制粘贴版

**你需要做的**

1. 将 CCH 仓库设为当前目录，然后打开各个 CLI
2. 将下面的 prompt **原样粘贴**
3. 完成后，在这个 Grok/Claude 聊天中返回一行结果

**你不需要做的**

- 繁琐的 bash 准备
- 重新运行 `setup-*.sh`（如果已经安装的话）
- 自己思考 artifact 路径

Artifact 路径由 AI 端编写：
`out/workflow-smoke/live/<host>/plan-artifact.md`

---

## 返回的话（仅此而已）

```text
LIVE: claude PASS
LIVE: codex PASS
LIVE: cursor PASS
LIVE: grok PASS
```

如果失败：

```text
LIVE: grok FAIL: <一言>
```

---

## 粘贴到 Claude Code

（在打开 `claude-code-harness` 的 Claude Code 输入栏中）

```text
Live H4 only. Use harness-plan if available. Do NOT implement code.

Write one short plan for: "Add a single-line comment to README.md that says live-h4-claude".

Save the full plan markdown to exactly:
out/workflow-smoke/live/claude/plan-artifact.md
(create directories if needed)

The file MUST include a heading "Acceptance criteria" with at least 2 bullets.

When the file is written, reply with exactly this one line and nothing else:
LIVE: claude PASS
```

---

## 粘贴到 Codex

（在同一个仓库中打开 Codex 后粘贴。CLI 的话可以在启动 `codex` 后，`codex exec '...'` 也可以）

```text
Live H4 only. Use $harness-plan or harness-plan skill if available. Do NOT implement code.

Write one short plan for: "Add a single-line comment to README.md that says live-h4-codex".

Save the full plan markdown to exactly:
out/workflow-smoke/live/codex/plan-artifact.md
(create directories if needed)

The file MUST include a heading "Acceptance criteria" with at least 2 bullets.

When the file is written, reply with exactly this one line and nothing else:
LIVE: codex PASS
```

---

## 粘贴到 Cursor

（在同一个仓库中用 Cursor 打开，在 Agent 输入栏中粘贴。如果出现 `/harness-plan`，可以先启动它）

```text
Live H4 only. Use harness-plan skill if available. Do NOT implement code. Prefer plan/ask read-only if possible.

Write one short plan for: "Add a single-line comment to README.md that says live-h4-cursor".

Save the full plan markdown to exactly:
out/workflow-smoke/live/cursor/plan-artifact.md
(create directories if needed)

The file MUST include a heading "Acceptance criteria" with at least 2 bullets.

When the file is written, reply with exactly this one line and nothing else:
LIVE: cursor PASS
```

---

## 粘贴到 Grok

（在同一个仓库中打开 `grok` 并在输入栏中粘贴）

```text
Live H4 only. Use harness-plan skill (/harness-plan) if available. Do NOT implement code.

Write one short plan for: "Add a single-line comment to README.md that says live-h4-grok".

Save the full plan markdown to exactly:
out/workflow-smoke/live/grok/plan-artifact.md
(create directories if needed)

The file MUST include a heading "Acceptance criteria" with at least 2 bullets.

When the file is written, reply with exactly this one line and nothing else:
LIVE: grok PASS
```

---

## 结束后（可选・确认用）

仅检查文件是否生成：

```bash
for h in claude codex cursor grok; do
  f="out/workflow-smoke/live/$h/plan-artifact.md"
  if test -f "$f"; then echo "OK  $h"; else echo "NG  $h"; fi
done
```

在这个聊天中只需粘贴 **`LIVE: <host> PASS`**。

---

## 备注

- 尚未安装 CCH 的 CLI，初始安装照常进行（Grok：`setup-grok`、Cursor：`setup-cursor` 等）。**每次测试不需要**。
- 与结构性自动测试不同。这是用于验证"该 CLI 是否真正运行了 plan"。
- 打印：`bash scripts/print-live-cli-smoke.sh claude` 等（仅输出 prompt）。
