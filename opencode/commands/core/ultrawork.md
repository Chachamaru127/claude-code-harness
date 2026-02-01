---
description: Plans.mdの指定範囲を完了まで自律的に反復実行する（/workの長期版）
---

# /ultrawork - Autonomous Task Completion Loop

Plans.md の指定範囲を**完了まで自動的に反復実行**する。
`/work` の長期版として、Ralph Loop + Ultrawork のコンセプトを採用。

## Philosophy

> **「人間介入は失敗シグナル」**
>
> システムが正しく設計されていれば、ユーザーが介入する必要はない。
> 反復 > 完璧性。失敗はデータ。粘り強さが勝つ。

---

## ⚠️ Security Notice

### ワークログのセキュリティ

`.claude/state/ultrawork.log.jsonl` にはエラーメッセージや実行ログが記録されます。

**重要な注意事項**:

1. **`.claude/state/` は `.gitignore` に追加すること**
   ```gitignore
   # Claude Code Harness state files
   .claude/state/
   ```

2. **機密情報の漏洩防止**
   - API キー、トークン、パスワードがエラーメッセージに含まれる可能性があります
   - ワークログをリポジトリにコミットしないでください
   - ログを共有する前に機密情報をマスキングしてください

3. **ログの定期削除**
   - 30日以上前のログは `archive/` に移動されます
   - 不要になったログは手動で削除してください

### 実行前の必須条件

> **ultrawork 開始前に、未コミット変更をクリーンにしてください**

```bash
# 状態確認
git status

# 未コミット変更がある場合
git add . && git commit -m "WIP: before ultrawork"
# または
git stash
```

**理由**:
- 問題発生時に `git checkout .` で復旧可能
- 変更の追跡と差分確認が容易
- `.gitignore` 対象ファイル（node_modules, .env.local 等）は無視してOK

### 危険コマンドとガードバイパス（EXPERIMENTAL）

> ⚠️ **この機能は実験的です。安全性は保証されません。**

通常、ハーネスのフック機構は `rm -rf` や `git push` でユーザー確認を要求します。
ultrawork の自律実行中は、**特定条件下でのみ**これらの確認をスキップします。

**技術的制限（重要）**:

| 制限 | 説明 |
|------|------|
| **展開前の文字列のみ** | シェル展開後の実パスは取得不可 |
| **グロブ・変数未対応** | `$DIR/*` や `${HOME}` は正しく評価できない |
| **rm 以外は対象外** | `find -delete`, `git clean`, `shutil.rmtree` 等は検出不可 |
| **シンボリックリンク** | リンク先のパスは完全には検証できない |

**バイパス条件（全て満たす場合のみ自動承認）**:

1. `ultrawork-active.json` が存在し有効期限内（24時間）
2. `allowed_rm_paths` にターゲット名が含まれている
3. 危険なシェル構文（`* ? $ ( ) { } ; | &`）を含まない
4. `sudo`, `xargs`, `find` を含まない
5. **単一ターゲット**のみ（複数指定は拒否）
6. **相対パス**のみ（`/` や `~` で始まらない）
7. **親参照なし**（`..` を含まない）
8. **末尾スラッシュなし**（シンボリックリンク対策）
9. **basename のみ**（パス区切り `/` を含まない）
10. 保護パスに該当しない

**常にブロック（バイパス不可）**:

| 対象 | 例 |
|------|-----|
| 特権昇格 | `sudo rm ...` |
| 複合コマンド | `xargs rm`, `find -delete` |
| シェル構文 | `rm -rf $DIR/*`, `rm -rf $(...)` |
| ルートパス | `rm -rf /`, `rm -rf /*` |
| ホームパス | `rm -rf ~`, `rm -rf ~/` |
| 親参照 | `rm -rf ..`, `rm -rf ../` |
| Git | `.git`, `.gitmodules` |
| 環境変数 | `.env`, `.env.*` |
| シークレット | `secrets/`, `.npmrc`, `.aws` |
| 鍵ファイル | `.pem`, `.key`, `id_rsa`, `id_ed25519`, `.ssh` |

**この機能が主張しないこと**:

- ❌ 「安全」「保護」「完全に防ぐ」
- ❌ 「展開後のパスを検証している」
- ❌ 「すべての削除コマンドを検出できる」

**ultrawork-active.json フォーマット**:

```json
{
  "active": true,
  "started_at": "2025-01-31T10:00:00Z",
  "bypass_guards": ["rm_rf", "git_push"],
  "allowed_rm_paths": [
    "node_modules",
    "dist",
    ".next",
    ".cache",
    "coverage",
    "build"
  ],
  "review_status": "pending"
}
```

**review_status フィールド（必須）**:

| 値 | 意味 | 遷移条件 |
|----|------|---------|
| `pending` | レビュー未実行 / 変更後 | 初期状態 / Write/Edit 実行後 |
| `passed` | レビュー通過 | harness-review で APPROVE |
| `failed` | レビュー NG | harness-review で Critical/High 指摘 |

> ⚠️ **重要**: `review_status !== "passed"` の場合、ultrawork の完了処理は実行不可。
> 必ず `/harness-review` で APPROVE を得てから完了すること。

**ホワイトリストの例**:

| ターゲット | 許可される |
|-----------|-----------|
| `node_modules` | ✅（リストに含まれる） |
| `dist` | ✅（リストに含まれる） |
| `./dist` | ❌（パス区切りを含む） |
| `/tmp/dist` | ❌（絶対パス） |
| `dist/` | ❌（末尾スラッシュ） |
| `node_modules dist` | ❌（複数ターゲット） |

**依存関係**: `jq` コマンドが必要です（未導入時はバイパス無効）

---

## Quick Reference

```bash
# 自然言語で範囲を指定
/ultrawork 認証機能からユーザー管理まで完了して
/ultrawork ログイン機能を終わらせて
/ultrawork 残りのコンポーネント全部やって
/ultrawork Header, Footer, Sidebar を作って

# キーワードで範囲指定
/ultrawork 認証系全部
/ultrawork フロントエンド完成させて
/ultrawork テストが通るまで

# シンプルに全部
/ultrawork 全部やって
/ultrawork Plans.md 完了まで
```

---

## /work との違い

| 特徴 | /work | /ultrawork |
|------|-------|------------|
| 実行範囲 | cc:TODO / pm:requested | **指定範囲の全タスク** |
| 反復 | 1回（手動で再実行） | **完了まで自動反復** |
| 完了条件 | タスク実装完了 | **全タスク完了 + ビルド成功 + テスト通過** |
| 自己学習 | なし | **前回の失敗から学習して回避** |
| ワークログ | session.events.jsonl | **.claude/state/ultrawork.log.jsonl** |
| 用途 | 1-2タスクの実装 | **大規模な実装を放置実行** |

---

## 範囲指定の解釈

自然言語で指定された範囲を Plans.md のタスクにマッピングする。

### 解釈ルール

| 指定パターン | 解釈 |
|-------------|------|
| `認証機能からユーザー管理まで` | 「認証」を含むタスク 〜 「ユーザー管理」を含むタスク |
| `ログイン機能を終わらせて` | 「ログイン」を含む全タスク |
| `Header, Footer, Sidebar` | 列挙されたキーワードを含むタスク |
| `認証系全部` | 「認証」に関連する全タスク |
| `残りのコンポーネント全部` | `cc:TODO` のコンポーネント系タスク |
| `全部やって` | Plans.md の全未完了タスク |
| `テストが通るまで` | 全テスト通過を完了条件に設定 |

### 範囲確認プロンプト（必須）

**実行前に必ずユーザーに確認する。承認されるまで実行しない。**

```text
📋 範囲を確認させてください

指定: 「認証機能からユーザー管理まで」

対象タスク:
├── 3. ログイン機能の実装 (cc:TODO)
├── 4. 認証ミドルウェアの作成 (cc:TODO)
├── 5. セッション管理 (cc:TODO)
└── 6. ユーザー管理画面 (cc:TODO)

計 4 タスクを完了まで実行します。

これで合っていますか？
```

**ユーザーの応答パターン**:

| 応答 | アクション |
|------|-----------|
| 「OK」「いいよ」「それで」 | 実行開始 |
| 「3と4だけ」 | 範囲を修正して再確認 |
| 「6は入れないで」 | タスク6を除外して再確認 |
| 「やっぱやめる」 | キャンセル |

---

## 内部オプション

| Option | Description | Default |
|--------|-------------|---------|
| max-iterations | 全体の最大反復回数 | 10 |
| parallel | 並列ワーカー数 | auto |
| checkpoint | 中間チェックポイント保存 | true |

> これらは自然言語で調整可能:
> - 「もっと粘って」→ max-iterations を増加
> - 「1つずつやって」→ parallel = 1
> - 「途中でコミットしないで」→ checkpoint = false

---

## Deliverables

- 指定範囲の**全タスクを完了まで自律的に実行**
- 失敗時は自己学習して再試行（同じ失敗を繰り返さない）
- 完了条件達成で自動終了
- ワークログで全ての試行を記録（再開可能）

---

## Execution Flow

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
│     - 「OK」「いいよ」→ Phase 1 へ                         │
│     - 修正指示 → 範囲を修正して再確認                       │
│     - 「やめる」→ キャンセル                                │
└─────────────────────────────────────────────────────────────┘
    ↓ ユーザー承認後
┌─────────────────────────────────────────────────────────────┐
│ Phase 1: 初期化                                              │
├─────────────────────────────────────────────────────────────┤
│  1. 依存関係グラフ構築                                      │
│  2. 完了条件の設定                                          │
│  3. ワークログ初期化                                        │
│     → .claude/state/ultrawork.log.jsonl                    │
│  4. ガードバイパス有効化                                    │
│     → .claude/state/ultrawork-active.json                  │
│  5. セッション状態に active_skill を記録 ★ NEW              │
│     → session.json に active_skill: "ultrawork" を設定     │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Iteration 1〜N: 自律実行ループ                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Step 1: 現状評価                                    │   │
│  │  - 未完了タスク特定                                 │   │
│  │  - 失敗履歴から学習（前回の失敗を避ける戦略選択）   │   │
│  │  - 優先順位再計算                                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                    ↓                                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Step 2: 並列実装（task-worker × N）                 │   │
│  │  - 独立タスクを並列実行                             │   │
│  │  - 各ワーカーが自己完結（実装→ビルド→テスト）      │   │
│  │  - エスカレーションはログに記録して次へ             │   │
│  └─────────────────────────────────────────────────────┘   │
│                    ↓                                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Step 3: 統合検証                                    │   │
│  │  - 全体ビルド実行                                   │   │
│  │  - テストスイート実行                               │   │
│  │  - 結果をワークログに記録                           │   │
│  └─────────────────────────────────────────────────────┘   │
│                    ↓                                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Step 3.5: /harness-review 実行                      │   │
│  │  - 全タスク完了時のみ実行                           │   │
│  │  - Critical/High 指摘 → 次 iteration で修正        │   │
│  │  - APPROVE → 完了処理へ                            │   │
│  └─────────────────────────────────────────────────────┘   │
│                    ↓                                       │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ Step 4: 判定                                        │   │
│  │  - 全完了 + APPROVE → 完了処理へ                   │   │
│  │  - 未完了あり → 次 iteration へ                    │   │
│  │  - max-iterations 到達 → 完了処理へ（部分完了）    │   │
│  │  - checkpoint → 中間コミット                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ※ 各 iteration 終了時にワークログ保存（再開可能）         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ 完了処理 ★ review_status チェック必須 ★                    │
├─────────────────────────────────────────────────────────────┤
│  0. ★ review_status 確認（必須）                           │
│     → ultrawork-active.json の review_status を確認        │
│     → "passed" でない場合 → 完了処理を中断、警告を表示     │
│     → 「harness-review で APPROVE を得てください」         │
│                                                             │
│  1. ガードバイパス解除                                      │
│     → ultrawork-active.json 削除                           │
│  2. セッション状態の active_skill をクリア ★ NEW           │
│     → session.json から active_skill を削除                │
│  3. 最終コミット（「コミットしないで」でスキップ）          │
│  4. ワークログ保存（完了ステータス）                        │
│  5. 完了レポート生成                                        │
│  6. 2-Agent モードなら handoff 実行                         │
└─────────────────────────────────────────────────────────────┘
```

---

## Self-Learning Mechanism

各イテレーションで前回の失敗から学習し、同じ失敗を繰り返さない。

```text
┌─────────────────────────────────────────────────────────────┐
│ Iteration 1                                                 │
│   タスク A: 型エラー "User型が見つからない"                  │
│   → 失敗をワークログに記録                                  │
└─────────────────────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────────────────────┐
│ Iteration 2                                                 │
│   ワークログを読み込み:                                     │
│   「前回 User 型が見つからなかった」                        │
│   → 戦略: "User 型の定義を先に確認してから実装"            │
│   → タスク A: 成功                                          │
└─────────────────────────────────────────────────────────────┘
```

### 学習戦略パターン

| 失敗パターン | 次イテレーションの戦略 |
|-------------|----------------------|
| 型エラー | 関連する型定義を先に確認 |
| import エラー | パス構造を再確認 |
| テスト失敗 | テストケースを読んで期待値を理解 |
| ビルドエラー | 依存関係を確認、順序変更 |
| 3回連続同じエラー | 別アプローチを試行 |

---

## Worklog Format

`.claude/state/ultrawork.log.jsonl`:

```jsonl
{"ts":"2025-01-30T10:00:00Z","event":"start","range":"1-5","max_iterations":10}
{"ts":"2025-01-30T10:00:05Z","event":"iteration_start","iteration":1}
{"ts":"2025-01-30T10:00:30Z","event":"task_complete","task":"Create Header","status":"success","duration_s":25}
{"ts":"2025-01-30T10:00:55Z","event":"task_failed","task":"Create Footer","error":"Import not found","attempted_fix":"Check path"}
{"ts":"2025-01-30T10:01:20Z","event":"verify","build":"pass","test":"fail","test_log":"1 test failed"}
{"ts":"2025-01-30T10:01:25Z","event":"iteration_end","iteration":1,"completed":1,"failed":1,"remaining":3}
{"ts":"2025-01-30T10:01:30Z","event":"iteration_start","iteration":2}
{"ts":"2025-01-30T10:02:00Z","event":"task_complete","task":"Create Footer","status":"success","duration_s":30,"learned_from":"iter 1: Import not found → Check path first"}
{"ts":"2025-01-30T10:05:00Z","event":"complete","iterations":3,"tasks_completed":5,"tasks_failed":0}
```

### Resume from Worklog

```bash
# 前回の中断から再開
/ultrawork 続きやって

# 内部動作:
# 1. .claude/state/ultrawork.log.jsonl を読み込み
# 2. 最後の iteration_end を特定
# 3. 完了タスクをスキップして未完了から再開
# 4. 失敗履歴を学習データとして引き継ぎ
```

---

## Completion Conditions

> ⚠️ **WARNING: Review なしで完了扱い不可**
>
> ultrawork の完了処理は `review_status === "passed"` の場合のみ実行可能です。
> セッションが継続（compact）しても、この条件は `ultrawork-active.json` で永続化されます。
>
> **必ず `/harness-review` で APPROVE を得てから完了してください。**

### デフォルト完了条件

以下の**全て**を満たしたとき完了:

1. ✅ 指定範囲の全タスクが `cc:done`
2. ✅ 全体ビルド成功
3. ✅ 全テスト通過（またはテストなし）
4. ✅ harness-review で Critical/High なし
5. ✅ **`review_status === "passed"`**（ultrawork-active.json で確認）

### カスタム完了条件

自然言語で完了条件を指定可能:

```bash
/ultrawork 認証機能、テストが全部通るまで
/ultrawork ログインページ、動作確認できるまで
/ultrawork API実装、Postmanで叩けるまで
```

指定された条件が真実になるまでループを継続。

---

## Session State Management

ultrawork はセッション継続（compact/resume）後も正しく動作するため、セッション状態を永続化します。

### Phase 1: 初期化時の設定

ultrawork 開始時に以下を実行:

```bash
# 1. ultrawork-active.json を作成
cat > .claude/state/ultrawork-active.json <<EOF
{
  "active": true,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "bypass_guards": ["rm_rf", "git_push"],
  "allowed_rm_paths": ["node_modules", "dist", ".next", ".cache", "coverage", "build"],
  "review_status": "pending"
}
EOF

# 2. session.json に active_skill を記録（★ 必須）
jq '.active_skill = "ultrawork" | .active_skill_started_at = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' \
  .claude/state/session.json > tmp.$$.json && mv tmp.$$.json .claude/state/session.json
```

> ⚠️ **重要**: `active_skill` を設定しないと、セッション継続後にスキル再起動の警告が表示されません。

### 完了処理時のクリア

ultrawork 完了時に以下を実行:

```bash
# 1. ultrawork-active.json を削除
rm -f .claude/state/ultrawork-active.json

# 2. session.json から active_skill を削除（★ 必須）
jq 'del(.active_skill) | del(.active_skill_started_at)' \
  .claude/state/session.json > tmp.$$.json && mv tmp.$$.json .claude/state/session.json
```

### セッション継続時の復元

セッションが継続（compact/resume）した場合、`session-resume.sh` が自動的に:

1. `session.json` の `active_skill` を検出
2. 「`/ultrawork 続きやって` でスキルを再起動してください」と強く促す
3. スキル再起動なしでの実装開始を警告

**これにより、スキル文脈なしでの作業開始を防止します。**

---

## Progress Display

```text
📊 /ultrawork Progress: Iteration 2/10

Range: Tasks 1-5
Completed: 2/5 tasks
Time elapsed: 2m 15s

├── Task 1: Create Header ✅ (iter 1, 25s)
├── Task 2: Create Footer ✅ (iter 2, 30s) [learned from iter 1 failure]
├── Task 3: Create Sidebar ⏳ In progress...
├── Task 4: Create Layout 🔜 Waiting (depends: 1,2,3)
└── Task 5: Create Page 🔜 Waiting (depends: 4)

Last iteration result:
├── Build: ✅ Pass
├── Tests: ⚠️ 14/15 pass (1 flaky)
└── Review: ✅ No Critical/High

Learning from failures:
└── Iteration 1: "Import not found" → Now checking paths first
```

---

## Completion Report

````markdown
## 📊 /ultrawork Complete

**Range**: Tasks 1-5
**Iterations**: 3 / 10 (max)
**Duration**: 5m 30s
**Status**: ✅ All tasks completed

### Task Results

| # | Task | Status | Iteration | Duration |
|---|------|--------|-----------|----------|
| 1 | Create Header | ✅ | 1 | 25s |
| 2 | Create Footer | ✅ | 2 | 30s |
| 3 | Create Sidebar | ✅ | 2 | 28s |
| 4 | Create Layout | ✅ | 2 | 45s |
| 5 | Create Page | ✅ | 3 | 35s |

### Verification

| Check | Result |
|-------|--------|
| Build | ✅ Pass |
| Tests | ✅ 15/15 pass |
| Review | ✅ APPROVE |

### Self-Learning Applied

| Iteration | Failure | Learned Strategy |
|-----------|---------|------------------|
| 1 | "Import not found" | Check paths first |
| 2 | "Type mismatch" | Verify types before impl |

### Changed Files

- `src/components/Header.tsx` (new)
- `src/components/Footer.tsx` (new)
- `src/components/Sidebar.tsx` (new)
- `src/components/Layout.tsx` (new)
- `src/app/page.tsx` (modified)

### Commit

```text
feat: implement Header, Footer, Sidebar, Layout, Page components

Completed via /ultrawork (3 iterations)
```

### Worklog

Saved to: `.claude/state/ultrawork.log.jsonl`
Use `/ultrawork --resume` to continue if interrupted.
````

---

## Partial Completion Report

max-iterations に達しても全タスク完了しなかった場合:

````markdown
## 📊 /ultrawork Partial Complete

**Range**: Tasks 1-5
**Iterations**: 10 / 10 (max reached)
**Duration**: 15m 20s
**Status**: ⚠️ Partial completion (3/5 tasks)

### Task Results

| # | Task | Status | Attempts | Last Error |
|---|------|--------|----------|------------|
| 1 | Create Header | ✅ | 1 | - |
| 2 | Create Footer | ✅ | 2 | - |
| 3 | Create Sidebar | ✅ | 2 | - |
| 4 | Create Layout | ❌ | 5 | Type 'unknown' is not assignable |
| 5 | Create Page | ⏸️ | 0 | Blocked by Task 4 |

### Blocking Issues

**Task 4: Create Layout** - 5 attempts, all failed

```text
Attempted fixes:
1. Type assertion → Failed (unknown is not User)
2. Type guard → Failed (property does not exist)
3. Interface extension → Failed (incompatible)
4. Generic type → Failed (constraint error)
5. Optional chaining → Failed (still unknown)

Suggestion: User型の定義を確認し、Layout.propsの型を修正する必要があります。
```

### Recommended Actions

1. Review `src/types/User.ts` definition
2. Check `Layout.props` interface compatibility
3. 修正後「続きやって」で再開

### Worklog

Saved to: `.claude/state/ultrawork.log.jsonl`
修正後「/ultrawork 続きやって」で再開できます。
````

---

## Error Handling

### 同じエラーが3回連続

```text
⚠️ Same error 3 times in a row

Task: Create Layout
Error: Type 'unknown' is not assignable to 'User'

Tried approaches:
1. Type assertion
2. Type guard
3. Generic constraint

Switching strategy: Will try alternative approach...
→ Checking User type definition first
→ Looking for similar patterns in codebase
```

### max-iterations 到達

```text
⚠️ Max iterations (10) reached

Completed: 3/5 tasks
Remaining: 2 tasks with blocking issues

どうしますか？
1. 「もっと粘って」→ 反復回数を増やして継続
2. 「ここは飛ばして次へ」→ ブロックされたタスクをスキップ
3. 「一旦止めて」→ ワークログ保存して中断
```

---

## VibeCoder Hints

| What You Want | How to Say |
|---------------|------------|
| 全部終わらせて | `/ultrawork 全部やって` |
| この機能だけ | `/ultrawork ログイン機能を完了して` |
| ここからここまで | `/ultrawork 認証からユーザー管理まで` |
| 前回の続きから | `/ultrawork 続きやって` |
| もっと粘って | 「もっと粘って」「諦めないで」 |
| 1つずつ確実に | 「1つずつやって」 |
| 進捗見たい | 「進捗どう？」 |

---

## Related Commands

- `/work` - 1回の実装サイクル（短期タスク向け）
- `/harness-review` - コードレビュー実行
- `/handoff-to-cursor` - PM へのハンドオフ
