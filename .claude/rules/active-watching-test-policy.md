# Active Watching Test Policy

Session Monitor などで **外部プロセス / ファイル / daemon を能動監視する機能**を新規追加するときに守るテスト規約。
D40 (tri-state health) と P29 (dual hooks sync) を運用ルール化し、v4.3.3 のような
「未インストールユーザーへの誤警告 regression」を初期フェーズで潰すための SSOT。

## なぜこのルールが必要か

v4.3.1 で Session Monitor に `harness-mem` 能動監視を追加した直後、
v4.3.3 hotfix で「`~/.claude-mem/` 不在 = harness-mem を opt-in していないユーザー」に対して
`⚠️ harness-mem unhealthy: not-initialized` が毎セッション表示される regression を修正する必要があった。

根因は inclusion-based testing のみ行い、**依存先が存在しない状態**のテストを書いていなかったこと。
active watching は opt-in な外部資源に依存することが多く、「未インストール / 未起動 / 破損」の
**3 状態をすべて最初からカバーする**のが唯一の再発防止策。

## 適用範囲

以下のいずれかに該当するコードを新規追加するとき、本規約に従うこと。

- `go/internal/session/monitor.go` に新しい health check を追加する
- `scripts/hook-handlers/` 等から外部 daemon / HTTP endpoint を probe する
- `~/.claude-*/` や `$HOME/` 配下の optional ディレクトリを読み取る
- MCP server の起動状態を監視する
- Codex daemon / external CLI の可用性をセッション毎にチェックする
- `UserPromptSubmit` や `SessionStart` hook で外部資源の可用性を additionalContext に載せる

逆に、以下は適用対象外:

- 必須依存（Go 標準ライブラリ, `bin/harness` 自体）の sanity check
- CI 環境でのみ走るテスト（CI では依存が必ずある前提で良い）

## 3 状態の定義

active watching の対象依存が取り得る状態と、それぞれで求める挙動:

| 状態 | 識別子 (reason) | `healthy` | Exit | Monitor 警告 | 典型例 |
|------|----------------|-----------|------|------------|--------|
| 未インストール / opt-in 未使用 | `not-configured` | **true** | 0 | **出さない** | `~/.claude-mem/` 不在 |
| 起動していない / 不達 | `daemon-unreachable`, `timeout`, `unreachable` | false | 1 | 出す | TCP connect 失敗 |
| 設定破損 / ファイル欠損 | `corrupted`, `invalid-config` | false | 1 | 出す | settings.json 不在 |
| 正常 | `""` | true | 0 | 出さない | 全構成要素 OK |

重要原則:

- **「使っていない」は「壊れている」ではない**。opt-in 機能が未使用なだけの状態では警告を出さない
- 判定ロジックは **health check subcommand 側**に集約し、Monitor / 他呼び出し元で挙動を一致させる（D40）
- `healthy=true + reason="not-configured"` は Monitor 実装が warning 抑止契約として必ず扱う

## テスト命名規約

3 状態それぞれに対して最低 1 件ずつテストを書く。命名は以下で固定する。

| 状態 | テスト関数名パターン | 検証内容 |
|------|-------------------|---------|
| `not-configured` | `TestXxx_NotConfigured` | `exit=0`, `healthy=true`, `reason="not-configured"`, Monitor が warning を出さない |
| `unreachable` | `TestXxx_DaemonUnreachable` または `TestXxx_Unreachable` | `exit=1`, `healthy=false`, 具体的な reason 文字列, Monitor が warning を出す |
| `corrupted` | `TestXxx_Corrupted` | `exit=1`, `healthy=false`, `reason="corrupted"`, Monitor が warning を出す |
| 正常 | `TestXxx_Healthy` | `exit=0`, `healthy=true`, `reason=""`, Monitor が静かに通過 |

Monitor 側統合テストも同じ命名規約で用意する（例: `TestMonitorHandler_XxxNotConfigured`）。

## チェックリスト

active watching 機能を PR に含めるときに確認する:

- [ ] health check 側に 4 テスト（正常 + 3 異常）を書いた
- [ ] Monitor 側に `not-configured` で warning が出ないことを assert する統合テストを書いた
- [ ] `reason` 文字列を enum 的に列挙した（free-text にしない。ドキュメントに表で明示）
- [ ] `healthy=true + reason="not-configured"` 契約を Monitor 側が参照している
- [ ] 既存の依存（`harness-mem` など）と命名規約が衝突していない
- [ ] ドキュメント（`go/SPEC.md` 等）に 3 状態を記載した

## 事例付録: v4.3.3 harness-mem hotfix

本規約が生まれた直接のトリガー事例。テスト構造を真似する reference として参照する。

- **背景 commit**: [`23589344`](https://github.com/Chachamaru127/claude-code-harness/commit/23589344) (PR #98 / v4.3.3 hotfix)
- **health check 実装**: `go/cmd/harness/mem.go` の `runMemHealthCheck()` — 早期 return 2 段 (`UserHomeDir` 失敗 / `~/.claude-mem/` 不在) で `not-configured` を返す
- **health check テスト**: `go/cmd/harness/mem_test.go`
  - `TestRunMemHealth_Healthy`
  - `TestRunMemHealth_DaemonUnreachable`
  - `TestRunMemHealth_NotConfigured` ← 3 状態カバレッジの核
  - `TestRunMemHealth_Corrupted`
- **Monitor 統合テスト**: `go/internal/session/monitor_test.go`
  - `TestMonitorHandler_HarnessMemHealthy`
  - `TestMonitorHandler_HarnessMemUnhealthy` (fixture reason = `daemon-unreachable`)
  - `TestMonitorHandler_HarnessMemNotConfigured` ← 警告非出力を明示的に assert

この事例で確認されたのは、3 状態のうち **1 つでも欠けると regression が出る**こと。
`not-configured` テストを最初から書いていれば v4.3.1 時点で問題を捕捉できた。

## 関連ルール

- [D40](../memory/decisions.md) — tri-state health の設計判断（本規約の理論的根拠）
- [P29](../memory/patterns.md) — dual hooks.json sync + CI gate（wiring 側の再発防止）
- [migration-policy.md](./migration-policy.md) — exclusion-based verification の姉妹規約（削除残骸 vs 依存不在）
- [test-quality.md](./test-quality.md) — テスト品質一般（形骸化テスト禁止）
- [implementation-quality.md](./implementation-quality.md) — 実装品質一般
