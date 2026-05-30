# Cursor Execution Backend Policy

Cursor を Harness の実装バックエンドとして使う時のガバナンスルール。
`cursor-agent` は不透明なサブプロセスであり、Harness のガードレール (R01-R13) は
その内部には適用されない。封じ込めは Cursor 側の機能ではなく Harness 側で行う。

> **重要な前提**: Cursor には「従来型サンドボックス」がない。ファイル書き込みは
> プロジェクトフォルダに**封じ込められない** (`--workspace` 外への書き込みを spike で確認済み)。
> `cursor-agent --sandbox enabled` はシェルコマンドを confine するが、
> ファイル編集ツールは confine **しない**。

## 基本方針

raw `cursor-agent` の直接呼び出しは禁止。以下の経路でのみ呼び出す:

1. **`scripts/cursor-companion.sh`** — Harness スキル・エージェント内からの唯一の呼び出し経路
2. ユーザーは `~/.claude/settings.json` の `deny` に `Bash(cursor-agent:*)` を**手動で追加**することを推奨
   - Harness / AI は settings.json を編集できない (deny + self-audit ガードで自己書き換えを防止)
   - 多層防御として、wrapper を経由しない raw 呼び出しを permission 層でも遮断する

```json
{
  "permissions": {
    "deny": ["Bash(cursor-agent:*)"]
  }
}
```

## 禁止事項

- agent 手順の標準手段としての raw `cursor-agent` 呼び出し
- `--force` / `--yolo` (= Cursor 公式の "Run Everything") による駆動 — Cursor 公式は **"Never use"**
- `--sandbox enabled` を「封じ込め済み」とみなすこと (ファイル編集は confine されない)
- Cursor の allowlist を security boundary とみなすこと (best-effort であり bypass 可能)

## --force を使わない

Cursor の "Run Everything" (`--force` / `--yolo`) は全操作を無確認で自動実行する。
Cursor 公式ドキュメントは "Never use" と明記している。Harness では使用禁止。

代わりに、自動実行したいコマンドは `~/.cursor/permissions.json` の
`terminalAllowlist` / `mcpAllowlist` で**個別にキュレートする**:

- `terminalAllowlist`: コマンド接頭辞文字列 (例: `"git status"`, `"npm:test*"`)
- `mcpAllowlist`: `"server:tool"` 形式 (ワイルドカード可、例: `"harness:*"`)
- グローバル設定 (per-user)、JSONC 形式

> **注意**: Cursor 公式は「Allowlists are best-effort convenience. They are not a
> security guarantee.」と明言している。allowlist は利便性のためのものであり、
> bypass 可能。**セキュリティ境界として依存しない**。

読み取り専用の委譲には `--mode ask` (または `--mode plan`) を使う。これは
ハードな read-only 停止であり、`--force` でも override できない (spike で確認済み)。

## Read mode delegation (lean path)

`scripts/cursor-companion.sh task "<prompt>"` は **引数なしで default `--mode ask` (hard read-only stop)** になる。`--write` を渡さない限り cursor 側はファイル書込・コマンド実行ができない。これにより重い containment を skip できる。

### read mode で省略できるもの

| 通常 (write mode) で必要 | read mode で skip 可 | 理由 |
|---|---|---|
| 専用 `.git` worktree | 不要 | cursor は書き込みできない |
| Lead diff review | 不要 | 差分が生まれない |
| cherry-pick | 不要 | 同上 |
| `worker-report.v1` / self_review 5 件 | 不要 | 実装をしないため |
| `--workspace` 引数 | optional | companion 側 workspace guard は `--write` 時のみ発火 |

### read mode でも保持必須 (軽い trust boundary)

| 項目 | 内容 |
|---|---|
| `.cursorignore` | secret ファイル (`.env` / `*.pem` / `*.key` / `.ssh` / `.aws` / `.git`) を cursor の read 対象から除外 |
| Egress allowlist | `~/.claude/settings.json` の `sandbox.network.allowedDomains` に `*.cursor.sh` |
| Filesystem allowlist | 同 `sandbox.filesystem.allowWrite` に `~/.cursor` (cursor-agent は read mode でも `~/.cursor/projects/<id>` 等に状態書込する) |
| permissions.json | `terminalAllowlist` / `mcpAllowlist` は read mode でも有効 (best-effort、security boundary ではない) |

### Topology (read mode)

```
Lead (Claude) ──[cursor-companion.sh task "<prompt>"]──> cursor-agent (--mode ask, locked)
       │
       └──[3-5 行要約]──> User
```

Worker 介在なし。Reviewer 介在なし。`worker-report.v1` / `review-result.v1` 契約は発生しない。

### read mode が適切なケース / 不適切なケース

| 適切 | 不適切 |
|---|---|
| 質問 ("この設計の弱点は？") | 実装 (ファイル編集が必要) |
| 調査 ("scripts/ で curl 使ってる箇所") | refactor (差分が必要) |
| 設計相談・敵対的視点 | bug fix (修正パッチが必要) |
| second-opinion レビュー (`harness-review --cursor`) | primary reviewer 昇格 (Opus 必須) |
| cursor-ask skill 経由の汎用質問 | breezing の team 並列実行 (write mode 必須) |

write mode が必要なケースは **`cursor-do` skill** または **`breezing --cursor`** を使う (どちらも worktree + Lead diff review + cherry-pick の full containment を起動する)。

### それでも残るリスク

- **読取漏洩**: `.cursorignore` を怠ると秘密ファイルが cursor 推論に渡る
- **誤った情報の鵜呑み**: cursor 出力は untrusted。Lead が 3-5 行要約で判断軸を残す
- **allowlist 過信**: Cursor 公式は "Allowlists are best-effort convenience" と明言

cross-ref: `skills/cursor-ask/SKILL.md` (汎用 read-only delegate) / `skills/cursor-do/SKILL.md` (write delegate with full containment) / `skills/harness-review/references/cursor-review.md` (second-opinion review)。

### `~/.cursor/permissions.json` テンプレート

```jsonc
{
  // コマンド接頭辞で自動実行を許可 (best-effort、security boundary ではない)
  "terminalAllowlist": [
    "git status",
    "git diff",
    "go test",
    "npm:test*"
  ],
  // MCP tool を server:tool 形式で許可 (ワイルドカード可)
  "mcpAllowlist": [
    "harness:*"
  ]
}
```

## Secrets

Cursor agent が秘密情報を**読み取らない**よう、`.cursorignore` を配布する。
`.cursorignore` に列挙されたファイルは agent の読み取り対象から除外される。

### `.cursorignore` テンプレート

```gitignore
.env
*.pem
*.key
.ssh
.aws
.git
```

## 封じ込めは Cursor 側ではなく Harness 側

Cursor 側には実効的な封じ込めがない (書き込みは confine されず、allowlist は best-effort)。
実際の境界は **Harness 側の以下の組み合わせ**で作る:

1. **専用 `.git` を持つ worktree** で cursor-agent を実行する (隔離)
2. **Lead が diff をレビュー**する (cursor 出力は Lead レビューまで untrusted として扱う)
3. **cherry-pick で本流へ取り込む** — この経路で R01-R13 ガードレールを通過する

| 層 | 担当 | 実効性 |
|---|---|---|
| Cursor `--sandbox enabled` | Cursor | シェルのみ。ファイル編集は confine されない |
| Cursor `terminalAllowlist` / `mcpAllowlist` | Cursor | best-effort、bypass 可能、security boundary ではない |
| 専用 `.git` worktree + Lead diff review + cherry-pick (R01-R13) | **Harness** | **唯一の実効的な境界** |

cursor-agent の出力は Lead がレビューするまで **untrusted** として扱うこと。

## エラーハンドリング

cursor-agent はエラー時に stdout の JSON を**出力しない** (exit 1, stderr テキストのみ)。
wrapper (`scripts/cursor-companion.sh`) は必ず **exit code を検査**してから出力を解釈する。

## Headless 実行に必須の flag

cursor-agent を headless (`-p`) で動かすには `--trust` が必須 (未指定だと「untrusted
directory」で拒否され何も実行できない)。`--trust` は **workspace の信頼付与のみ**で、
`--force` / `--yolo` (= Run Everything: コマンド自動実行) とは別物。`cursor-companion.sh`
は `--trust` を常に付け、`--force` / `--yolo` は決して付けない。

## Sandbox 要件 (CC 外側 sandbox を有効のまま使う場合)

`cursor-companion.sh` を CC sandbox 有効のまま動かすには、`~/.claude/settings.json` の
sandbox に **2 つ**の許可が要る (実測で確定):

1. **network**: `network.allowedDomains` に `*.cursor.sh` (`api2.cursor.sh` /
   `agentn.global.api5.cursor.sh` を含む)。未許可だと通信がブロックされハングする。
2. **filesystem write**: 公式キー **`sandbox.filesystem.allowWrite`** に `~/.cursor` を追加する。
   cursor-agent は実行時に `~/.cursor/projects/<...>` や `~/.cursor/cli-config.json.tmp` へ
   状態を書くため、未許可だと `EPERM` で失敗する (`--list-models` は状態書込不要なので通るが、
   `task` は通らない)。`~/` は sandbox 側で展開される (公式例 `["~/.kube"]`)。
   ⚠️ **キー名は `allowWrite`**: `write` という名前にすると未知キーとして無視され、設定が効かない。
   ディレクトリ指定で配下も再帰的に許可される。

どちらかが欠けると sandbox 有効下では失敗する。allowlist を設定できない場合の代替は
per-run の sandbox 無効化 (Risk Gate) だが、`*.cursor.sh` + `~/.cursor` の 2 点を
allowlist する方が sandbox の他防御を保てるため推奨。設定手順は
`docs/sandbox-allowlist-recipe.md` と `harness-setup` の導入動線を参照。

## Role scope

cursor バックエンドを使うのは **実装 (worker) ロールのみ**。
review / advisor ロールは Opus に固定する (cursor バックエンドに切り替えない)。

## Topology (非 claude backend では Worker 介在なし)

backend が `cursor` (または `codex`) のとき、Lead は Worker agent (`claude-code-harness:worker`) を spawn しない。**Lead が直接 `cursor-companion.sh task --write --workspace <isolated-wt>` を呼ぶ**。Worker 層介在は backend=`claude` のときだけ。

理由: 非 claude backend では `worker-report.v1` も `self_review` 配列も生成されないため、Worker を間に挟むと agent 契約 (self_review 5 件) のゲートが空回りする。Lead が直接 companion を呼んで diff レビュー → cherry-pick が正しい配線。

詳細: `skills/harness-work/SKILL.md` の「非 `claude` バックエンドのトポロジー」節を参照。

## 関連ルール

- `.claude/rules/codex-cli-only.md` — Codex バックエンド (companion 経由統一の姉妹ルール)
- `.claude/rules/self-audit.md` — settings.json deny エントリの減少検知 (deny 改ざん防止)
