# Codex 並列レビュー実行ガイド

Codex モード時に4つのエキスパートを並列で呼び出すためのオーケストレーション手順。

## 概要

Codex モードでは、レビュータイプに応じて**4つのエキスパート**を MCP 経由で並列呼び出しします。

### レビュータイプ別エキスパート

| Review Type | 4 Experts |
|-------------|-----------|
| **Code** | Security, Performance, Quality, Accessibility |
| **Plan** | Clarity, Feasibility, Dependencies, Acceptance |
| **Scope** | Scope-creep, Priority, Scope-feasibility, Impact |

```
Claude (オーケストレーター)
    ↓
レビュータイプ判定
    ↓
並列 MCP 呼び出し (4エキスパート)
    ↓
結果統合 → 判定
```

---

## ⚠️ 並列呼び出し必須ルール（MANDATORY）

### 禁止事項

| 禁止 | 理由 |
|------|------|
| ❌ 1回の MCP 呼び出しで複数エキスパートをまとめる | 各エキスパートの専門性が薄まる |
| ❌ experts/*.md を読まずに汎用プロンプトを送る | 専門家プロンプトの知見が活かされない |

### 必須事項

| 必須 | 方法 |
|------|------|
| ✅ 各エキスパートを **個別の MCP 呼び出し** で実行 | `mcp__codex__codex` を4回呼び出し |
| ✅ experts/*.md から **個別にプロンプトを読み込む** | 例: `security-expert.md` → Security 呼び出し |
| ✅ **1つのレスポンス内で4つの MCP 呼び出しを並列実行** | Claude の並列ツール呼び出し機能を使用 |

---

## 実行フロー

### Step 1: レビュータイプ判定

`/harness-review` の文脈判断結果に従う:

| review_type | 使用するエキスパート |
|-------------|---------------------|
| `code` | security, performance, quality, accessibility |
| `plan` | clarity, feasibility, dependencies, acceptance |
| `scope` | scope-creep, priority, scope-feasibility, impact |

### Step 2: 4並列 MCP 呼び出し

**Code Review:**
```
mcp__codex__codex({prompt: security-expert.md})
mcp__codex__codex({prompt: performance-expert.md})
mcp__codex__codex({prompt: quality-expert.md})
mcp__codex__codex({prompt: accessibility-expert.md})
```

**Plan Review:**
```
mcp__codex__codex({prompt: clarity-expert.md})
mcp__codex__codex({prompt: feasibility-expert.md})
mcp__codex__codex({prompt: dependencies-expert.md})
mcp__codex__codex({prompt: acceptance-expert.md})
```

**Scope Review:**
```
mcp__codex__codex({prompt: scope-creep-expert.md})
mcp__codex__codex({prompt: priority-expert.md})
mcp__codex__codex({prompt: scope-feasibility-expert.md})
mcp__codex__codex({prompt: impact-expert.md})
```

### Step 3: 出力制限ルール

各エキスパートの応答制約（experts/*.md に埋め込み済み）:

| 制約 | 内容 |
|------|------|
| 言語 | **English only**（Claude が統合時に日本語化） |
| 最大文字数 | 1500 文字 |
| 件数制限 | Critical/High: 全件、Medium/Low: 各3件まで |
| 問題なし | `Score: A / No issues.` のみ |

### Step 4: 結果統合 → 判定

| 集計 | 判定 |
|------|------|
| Critical ≥ 1 | REJECT |
| High ≥ 1 または Medium > 3 | REQUEST_CHANGES |
| それ以外 | APPROVE |

---

## 関連ファイル

### Code Review Experts
- `experts/security-expert.md`
- `experts/performance-expert.md`
- `experts/quality-expert.md`
- `experts/accessibility-expert.md`

### Plan Review Experts
- `experts/clarity-expert.md`
- `experts/feasibility-expert.md`
- `experts/dependencies-expert.md`
- `experts/acceptance-expert.md`

### Scope Review Experts
- `experts/scope-creep-expert.md`
- `experts/priority-expert.md`
- `experts/scope-feasibility-expert.md`
- `experts/impact-expert.md`
