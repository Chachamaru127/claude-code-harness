# Live CLI smoke — コピペだけ版

**あなたがやること**

1. CCH リポジトリをカレントにした状態で、各 CLI を開く
2. 下のプロンプトを **そのまま貼る**
3. 終わったら、この Grok/Claude チャットに結果 1 行を返す

**あなたがやらなくていいこと**

- 長い bash の準備
- `setup-*.sh` の再実行（すでに入れてあれば）
- 成果物パスを自分で考える

成果物は AI 側が書いてくれる想定:
`out/workflow-smoke/live/<host>/plan-artifact.md`

---

## 返す言葉（これだけ）

```text
LIVE: claude PASS
LIVE: codex PASS
LIVE: cursor PASS
LIVE: grok PASS
```

失敗したら:

```text
LIVE: grok FAIL: <一言>
```

---

## Claude Code に貼る

（`claude-code-harness` を開いた Claude Code の入力欄へ）

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

## Codex に貼る

（同じ repo で Codex を開いて貼る。CLI なら `codex` 起動後でも、`codex exec '...'` でも可）

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

## Cursor に貼る

（同じ repo を Cursor で開き、Agent 入力欄へ。`/harness-plan` が出るなら先にそれを起動してからでも可）

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

## Grok に貼る

（同じ repo で `grok` を開いて入力欄へ）

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

## 終わったあと（任意・確認用）

ファイルができたかだけ見るなら:

```bash
for h in claude codex cursor grok; do
  f="out/workflow-smoke/live/$h/plan-artifact.md"
  if test -f "$f"; then echo "OK  $h"; else echo "NG  $h"; fi
done
```

このチャットには **`LIVE: <host> PASS`** を貼るだけでよい。

---

## メモ

- まだ CCH を入れてない CLI だけ、初回はいつもどおり install が必要（Grok: `setup-grok`、Cursor: `setup-cursor` など）。**毎回のテストでは不要**。
- structural 自動テストとは別。これは「その CLI で本当に plan が回ったか」用。
- 印刷: `bash scripts/print-live-cli-smoke.sh claude` など（プロンプトだけ出す）。
