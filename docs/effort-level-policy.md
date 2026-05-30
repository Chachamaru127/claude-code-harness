# Effort Level Policy

## 概要

CC frontmatter の `effort` フィールドと Anthropic API の effort パラメータの対応関係、および Harness における採用方針を定義する。

## CC Frontmatter と API Effort の対応マトリクス

CC v2.1.72 で `max` が廃止され、v2.1.111 で `xhigh` が追加された。

| CC frontmatter `effort` 値 | API effort 実効値 | Opus 4.8 での動作 | 非 Opus 4.8 での動作 |
|----------------------------|------------------|-------------------|---------------------|
| `low` | low | low（スコープ厳守、深掘りしない） | low |
| `medium` | medium | medium | medium |
| `high` | high | high | high |
| `xhigh` | xhigh | xhigh（最高 effort tier） | `high` にフォールバック（changelog 明記） |

**注記**:
- `xhigh` は CC v2.1.111 で frontmatter に追加された（`CLAUDE-feature-table.md` 参照）
- `max` は CC v2.1.72 で廃止済み。frontmatter に書いても無効
- `xhigh` を Opus 4.8 以外のモデル（Sonnet 系など）で指定した場合、CC が `high` に自動ダウングレードする

### Opus 4.8 の thinking モデル（重要）

Opus 4.8 では **thinking は既定 off**。`thinking: {type: "adaptive"}` を明示した時だけ adaptive thinking が働き、
effort と query 複雑度から思考量を自動調整する。`budget_tokens` 方式の extended thinking は deprecated。
CC frontmatter の `effort` は引き続き有効で、Opus 4.8 では推論深度の **主レバー**になる（過去のどの Opus より effort の影響が大きい）。

そのため Harness は「深く考えさせたい」場面で free-text marker（旧 `ultrathink`）を使わず、`effort` tier で制御する
（`harness-work` の effort スコアリングも tier 選択方式に統一済み）。

### xhigh が CC 経由で API に渡せるかの判定

**判定: 採用（xhigh を frontmatter で受け付ける証拠あり）**

根拠:
1. `docs/CLAUDE-feature-table.md` の v2.1.111 セクションに `xhigh effort` が `A: 明示追従対象` として記録されている
2. 同ファイルの Opus 4.7 セクションにも `xhigh effort` が `A: 明示追従対象` として記録されている
3. `docs/cc-2.1.99-2.1.111-impact.md` に v2.1.111 での `xhigh` 追加が文書化されている
4. Harness の `opus-4-7-prompt-audit.md` にて「`xhigh`: 呼び出し側が選ぶ推論強度」と定義されている

`xhigh` を frontmatter に書いた場合、CC は Opus 4.8 に最高 effort tier のリクエストを送る。非 Opus 4.8 モデル（Sonnet 系など）ではサイレントに `high` 相当へダウングレードされる。reject や error にはならない。

## Harness の採用方針

| フロー | 採用 effort | 理由 |
|--------|------------|------|
| Plan | `high` | 速さと整理力のバランスが良い |
| Work (Worker agent) | `high` | 実装は長考より反復確認が重要 |
| Review (Reviewer agent, harness-review) | `xhigh` | 比較・反証・抜け漏れ検知に thinking 増分の効果が出る |
| Advisor | `xhigh` | PLAN / CORRECTION / STOP の判断精度を優先 |
| Release / Setup | `high` | 手順遵守が中心で、常時 `xhigh` は過剰 |

### frontmatter 更新対象

| ファイル | 変更前 | 変更後 | 理由 |
|--------|--------|--------|------|
| `agents/reviewer.md` | `effort: medium` | `effort: xhigh` | Review に xhigh を採用 |
| `agents/advisor.md` | `effort: high` | `effort: xhigh` | Advisor に xhigh を採用 |
| `skills/harness-review/SKILL.md` | `effort: high` | 変更なし | スキルの effort は呼び出し側が上書きするため high を維持 |

## 運用ルール

1. **review と advisory を優先して `xhigh` の対象にする**
   理由: バグ検知や反証は、実装そのものより thinking 増分の効果が出やすい。

2. **work は既定 `high` を維持する**
   理由: 実装はトークン消費より、短いサイクルでの検証の方が効くことが多い。

3. **docs では「Opus 4.8 以外は `high` へフォールバック」を明記する**
   理由: 利用者が「`xhigh` と書いたのに効いていない」と誤解しやすい。

4. **全 skill / 全 agent を一律 `xhigh` にしない**
   理由: コストとレイテンシが無駄に増加する。役割差で使い分けること。

5. **`${CLAUDE_EFFORT}` は参照専用にする**
   理由: Claude Code 2.1.120 以降、skill 本文から現在の effort level を参照できる。
   ただし、これは呼び出し側が選んだ effort を読むための情報であり、skill 側が勝手に effort を上書きするための仕組みではない。

### `${CLAUDE_EFFORT}` guidance

`CLAUDE_EFFORT` は、現在の session / invocation で有効な effort level を skill 本文から参照するための変数。

使ってよい例:

```md
Current effort: `${CLAUDE_EFFORT}`.
If effort is low, report only confirmed blockers.
If effort is xhigh, include adversarial checks and edge cases.
```

避ける例:

- skill 本文で「必ず xhigh に変更する」と要求する
- `CLAUDE_EFFORT` が空の環境を失敗扱いにする
- user / parent workflow の effort 指定を無視する

Harness の方針:

- effort の選択権は呼び出し側に残す。
- skill は `CLAUDE_EFFORT` を説明、分岐、出力粒度調整にだけ使う。
- media / announcement 系のような内部起動 skill では、effort より起動契約（`user-invocable` / `disable-model-invocation`）を優先して明確化する。

## 見送り rationale（採用しないもの）

以下は採用しない。見送り理由を明記する。

| 項目 | 見送り理由 |
|------|-----------|
| Worker agent を `xhigh` にすること | 実装ループは長考より速い反復が重要。xhigh のコスト増分に見合う品質向上が得られない |
| Setup / Release スキルを `xhigh` にすること | 手順遵守が中心で、judgment より recall が重要な場面が多い |
| `max` の復活 | CC v2.1.72 で廃止済み。`xhigh` がその後継 |

## 注意点

- `xhigh` は「賢くなる魔法」ではなく、より深く考えるための余白
- 曖昧な指示のままだと、深く考えてもズレた方向に精密化される
- Opus 4.8 以外のモデルでは `xhigh` を指定しても `high` 相当にフォールバックするため、期待した効果が出ない場合がある
- `opus-4-7-prompt-audit.md` の合格条件 5: `xhigh` は「呼び出し側が選ぶ推論強度」であり、agent prompt が free-text marker から推測するものではない

## 関連ファイル

- `docs/CLAUDE-feature-table.md` — v2.1.111 / Opus 4.7 の機能一覧
- `docs/cc-2.1.99-2.1.111-impact.md` — xhigh 追加の詳細
- `docs/claude-code-setup-mcp-telemetry-provider.md` — `${CLAUDE_EFFORT}` と setup guidance
- `.claude/rules/opus-4-7-prompt-audit.md` — xhigh の運用ノブ定義
- `agents/reviewer.md` — Reviewer effort 設定
- `agents/advisor.md` — Advisor effort 設定
