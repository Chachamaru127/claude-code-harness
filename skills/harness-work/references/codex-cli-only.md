# Codex Plugin Policy

Codex の呼び出しには **公式プラグイン `openai/codex-plugin-cc`** を使用すること。

## 基本方針

raw `codex exec` の直接呼び出しは禁止。以下の 2 つの方法で Codex を呼び出す:

1. **`scripts/codex-companion.sh`** — Harness スキル・エージェント内からの呼び出し
2. **`/codex:*` コマンド** — ユーザー対話での ad-hoc 利用

## 禁止事項

- `codex exec` の直接呼び出し（`skills-codex/` 内を除く。後述の例外参照）
- `mcp__codex__codex` の使用（MCP サーバーは廃止済み）
- ToolSearch で Codex MCP を検索する行為
- `claude mcp add codex` による MCP サーバー再登録

## MCP ブロック（v2.1.78+）

settings.json の `deny` ルールで旧 MCP ツールをブロック（既設定済み）:

```json
{
  "permissions": {
    "deny": ["mcp__codex__*"]
  }
}
```

## 正しい呼び出し方

### タスク委託（実装・デバッグ・調査）

```bash
# 書き込み可能なタスク委託
bash scripts/codex-companion.sh task --write "バグを修正して"

# stdin 経由（大きなプロンプト向け）
cat "$PROMPT_FILE" | bash scripts/codex-companion.sh task --write

# 前回のスレッドを再開
bash scripts/codex-companion.sh task --resume-last --write "続きをやって"
```

### レビュー

```bash
# 作業ツリーのレビュー
bash scripts/codex-companion.sh review

# 特定の base ref からのレビュー
bash scripts/codex-companion.sh review --base "${TASK_BASE_REF}"

# 敵対的レビュー（設計判断への挑戦）
bash scripts/codex-companion.sh adversarial-review
```

### セットアップ・ジョブ管理

```bash
# Codex の利用可否を確認
bash scripts/codex-companion.sh setup --json

# 実行中ジョブの確認
bash scripts/codex-companion.sh status

# ジョブ結果の取得
bash scripts/codex-companion.sh result <job-id>

# ジョブのキャンセル
bash scripts/codex-companion.sh cancel <job-id>
```

### /codex:* コマンド（ユーザー対話）

```
/codex:setup              — Codex CLI のセットアップ確認
/codex:rescue             — タスク委託（調査・実装・デバッグ）
/codex:review             — コードレビュー
/codex:adversarial-review — 敵対的レビュー
/codex:status             — ジョブ状態確認
/codex:result             — ジョブ結果取得
/codex:cancel             — ジョブキャンセル
```

## verdict マッピング（公式プラグイン ↔ Harness）

公式プラグインの review 出力は Harness と異なるスキーマを使用する。変換ルール:

| 公式 plugin | Harness | 備考 |
|---|---|---|
| `approve` | `APPROVE` | |
| `needs-attention` | `REQUEST_CHANGES` | |
| `findings[].severity: critical` | `critical_issues[]` | verdict に影響 |
| `findings[].severity: high` | `major_issues[]` | verdict に影響 |
| `findings[].severity: medium/low` | `recommendations[]` | verdict に影響しない |

## 例外: Codex ネイティブスキル

`skills-codex/` 内のスキルは **Codex CLI 内部で動作する**ため、
`spawn_agent` / `wait_agent` / `send_input` / `close_agent` 等の
Codex ネイティブ API は引き続き使用可。ただしレビュー呼び出しは
companion 経由を推奨。

## 公式プラグインの提供機能

| 機能 | 説明 |
|------|------|
| Job 管理 | スレッドの開始・再開・キャンセル・結果取得 |
| App Server Protocol | JSON-RPC over TCP による高信頼な Codex 通信 |
| 構造化出力 | `review-output.schema.json` 準拠の構造化レビュー |
| Stop Review Gate | セッション終了時の自動レビューゲート |
| GPT-5.4 Prompting | Codex 向け最適化プロンプトガイダンス |
