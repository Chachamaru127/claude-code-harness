# Execution Flow

```text
/ultrawork 認証機能からユーザー管理まで完了して
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Phase 0: 範囲確認（ユーザー承認必須）                        │
├─────────────────────────────────────────────────────────────┤
│  1. 自然言語を解析 → Plans.md のタスクにマッピング          │
│  2. 対象タスク一覧を表示                                     │
│  3. 「これで合っていますか？」と確認                         │
│  4. ★ ユーザーが承認するまで待機 ★                          │
└─────────────────────────────────────────────────────────────┘
    ↓ ユーザー承認後
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: 初期化                                              │
├─────────────────────────────────────────────────────────────┤
│  1. 依存関係グラフ構築                                      │
│  2. 完了条件の設定                                          │
│  3. ワークログ初期化 → .claude/state/ultrawork.log.jsonl    │
│  4. ガードバイパス有効化 → ultrawork-active.json            │
│  5. session.json に active_skill: "ultrawork" を設定        │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Iteration 1〜N: 自律実行ループ                              │
├─────────────────────────────────────────────────────────────┤
│  Step 1: 現状評価                                           │
│    - 未完了タスク特定                                       │
│    - 失敗履歴から学習                                       │
│    - 優先順位再計算                                         │
│                                                             │
│  Step 2: 並列実装（task-worker × N）                        │
│    - 独立タスクを並列実行                                   │
│    - 各ワーカーが自己完結（実装→ビルド→テスト）            │
│                                                             │
│  Step 3: 統合検証                                           │
│    - 全体ビルド実行                                         │
│    - テストスイート実行                                     │
│                                                             │
│  Step 3.5: /harness-review + 自己修正ループ                 │
│    - 全タスク完了時のみ                                     │
│    - APPROVE まで自動修正を繰り返す                         │
│    - REJECT/STOP は即停止                                   │
│                                                             │
│  Step 4: 判定                                               │
│    - APPROVE → 完了処理へ                                   │
│    - REQUEST CHANGES → 自己修正ループ                       │
│    - REJECT/STOP → 即停止 + 手動介入                        │
│    - 未完了あり → 次 iteration へ                           │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ 完了処理                                                     │
├─────────────────────────────────────────────────────────────┤
│  0. review_status 確認（必須: "passed" のみ完了可）          │
│  1. ultrawork-active.json 削除                              │
│  2. session.json から active_skill を削除                   │
│  3. 最終コミット                                            │
│  4. 完了レポート生成                                        │
│  5. 2-Agent モードなら handoff 実行                         │
└─────────────────────────────────────────────────────────────┘
```

### Step 3.5: /harness-review + 自己修正ループ（自動実行・必須）

全タスク完了時に `/harness-review` を実行し、**APPROVE になるまで自動修正を繰り返す**。

**重要**: このループは**自動実行**。ユーザー確認（Y/N）は求めない。

```
/harness-review 実行
    ↓
判定結果
    ├── APPROVE → 完了処理へ
    ├── REQUEST CHANGES → 自己修正ループ
    ├── REJECT → 即停止 + 手動介入指示
    └── STOP → 検証失敗 + 手動修正指示
```

#### リトライ状態管理

**ファイル**: `.claude/state/ultrawork-retry.json`

**スキーマ**:
```json
{
  "task_id": "phase44-auth-to-usermgmt",
  "base_sha": "abc1234",
  "status": "request_changes",
  "retry_count": 1,
  "last_findings": [...],
  "last_review_at": "2025-01-15T10:30:00Z",
  "task_range": "...",
  "started_at": "2025-01-15T09:00:00Z",
  "expires_at": "2025-01-15T18:00:00Z"
}
```

### 検証実行規則（全て実行、失敗で即停止）

| 順位 | 対象 | コマンド |
|------|------|---------|
| 1 | `./tests/validate-plugin.sh` | `bash ./tests/validate-plugin.sh` |
| 2 | `./scripts/ci/check-consistency.sh` | `bash ./scripts/ci/check-consistency.sh` |
| 3 | `package.json` の `test` script | `{pkg_mgr} test` |
| 4 | `package.json` の `lint` script | `{pkg_mgr} run lint` |
| 5 | `pytest.ini` / `pyproject.toml` | `pytest` |
| 6 | `Cargo.toml` | `cargo test` |
| 7 | `go.mod` | `go test ./...` |

> **注**: 該当ファイルが存在する場合は必ず実行し、**失敗した時点で即停止**する。

### STOP / REJECT テンプレート

#### REJECT

```markdown
### Manual Intervention Required

**Decision**: REJECT
**Grade**: F
**Reason**: Critical issues require manual review and fix
**Critical issues**: ...
```

#### STOP

```markdown
### Verification Failed

**Decision**: STOP
**Grade**: N/A (blocked)
**Failure Type**: [lint_failure | test_failure | environment_error]
**Failed command**: ...
**Required fixes**: ...
```

## 範囲指定の解釈

| 指定パターン | 解釈 |
|-------------|------|
| `認証機能からユーザー管理まで` | 「認証」〜「ユーザー管理」を含むタスク |
| `ログイン機能を終わらせて` | 「ログイン」を含む全タスク |
| `Header, Footer, Sidebar` | 列挙されたキーワードを含むタスク |
| `全部やって` | Plans.md の全未完了タスク |
| `テストが通るまで` | 全テスト通過を完了条件に設定 |

## 範囲確認プロンプト（必須）

```text
📋 範囲を確認させてください

指定: 「認証機能からユーザー管理まで」

対象タスク:
├── 3. ログイン機能の実装 (cc:TODO)
├── 4. 認証ミドルウェアの作成 (cc:TODO)
└── 5. セッション管理 (cc:TODO)

計 3 タスクを完了まで実行します。

これで合っていますか？
```
