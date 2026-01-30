---
name: ultrawork
description: "Autonomous task completion loop with self-learning. Use when user wants to complete multiple tasks autonomously until done. Supports natural language range specification."
allowed-tools: ["Read", "Write", "Edit", "Task", "Bash", "Grep", "Glob"]
user-invocable: true
---

# Ultrawork Skill

Plans.md の指定範囲を完了まで自律的に反復実行するスキル。
自己学習メカニズムにより、同じ失敗を繰り返さない。

---

## トリガーフレーズ

このスキルは以下のフレーズで自動起動します：

- 「全部やって」「完了まで」「終わるまで」
- 「〜から〜まで完了して」
- 「放置で」「自動で全部」
- "complete all", "until done", "autonomous"

---

## 関連コマンド

- `/ultrawork` - 自律的タスク完了ループ

---

## 概要

`/work` の長期版として、指定範囲のタスクを完了まで自動的に反復実行する。
Ralph Loop + Ultrawork のコンセプトを採用。

### Philosophy

> **「人間介入は失敗シグナル」**
>
> システムが正しく設計されていれば、ユーザーが介入する必要はない。
> 反復 > 完璧性。失敗はデータ。粘り強さが勝つ。

---

## 実行フロー

### Phase 0: 範囲確認（必須）

1. 自然言語を解析 → Plans.md のタスクにマッピング
2. 対象タスク一覧を表示
3. 「これで合っていますか？」と確認
4. **ユーザーが承認するまで実行しない**

### Phase 1: 初期化

1. 依存関係グラフ構築
2. 完了条件の設定
3. ワークログ初期化

### Iteration Loop

1. 現状評価（未完了タスク特定、失敗履歴から学習）
2. 並列実装（task-worker × N）
3. 統合検証（ビルド、テスト）
4. 判定（全完了 → 完了処理 / 未完了 → 次iteration）

### 完了処理

1. 最終コミット
2. ワークログ保存
3. 完了レポート生成
4. 2-Agent モードなら handoff 実行

---

## 自己学習メカニズム

### 学習戦略パターン

| 失敗パターン | 次イテレーションの戦略 |
|-------------|----------------------|
| 型エラー | 関連する型定義を先に確認 |
| import エラー | パス構造を再確認 |
| テスト失敗 | テストケースを読んで期待値を理解 |
| ビルドエラー | 依存関係を確認、順序変更 |
| 3回連続同じエラー | 別アプローチを試行 |

### 学習の実装

各イテレーション開始時に：

```
1. ワークログから前回の失敗を読み込み
2. 失敗パターンを分析
3. 回避戦略を選択
4. 戦略を適用してタスク実行
5. 結果をワークログに記録
```

---

## ワークログ管理

### ファイル形式

`.claude/state/ultrawork.log.jsonl`:

```jsonl
{"ts":"...","event":"start","range":"認証機能〜ユーザー管理","tasks":[3,4,5,6]}
{"ts":"...","event":"iteration_start","iteration":1}
{"ts":"...","event":"task_complete","task":"ログイン機能","status":"success"}
{"ts":"...","event":"task_failed","task":"認証ミドルウェア","error":"...","strategy":"..."}
{"ts":"...","event":"iteration_end","iteration":1,"completed":1,"failed":1}
{"ts":"...","event":"learned","pattern":"import error","strategy":"check paths first"}
{"ts":"...","event":"complete","iterations":3,"tasks_completed":4}
```

### ワークログ操作

#### 初期化

```typescript
// イテレーション開始時
const worklog = {
  path: ".claude/state/ultrawork.log.jsonl",
  append: (event) => {
    // JSONL形式で追記
    fs.appendFileSync(path, JSON.stringify({
      ts: new Date().toISOString(),
      ...event
    }) + "\n");
  }
};

worklog.append({ event: "start", range: userRange, tasks: taskIds });
```

#### 学習データ読み込み

```typescript
// 次イテレーション開始時
const failures = worklog.entries
  .filter(e => e.event === "task_failed")
  .map(e => ({ task: e.task, error: e.error, strategy: e.strategy }));

// 失敗パターンから学習
const strategies = deriveStrategies(failures);
```

#### 再開時

```typescript
// /ultrawork 続きやって
const lastState = worklog.entries
  .filter(e => e.event === "iteration_end")
  .pop();

const completedTasks = worklog.entries
  .filter(e => e.event === "task_complete")
  .map(e => e.task);

// 未完了タスクから再開
const remainingTasks = allTasks.filter(t => !completedTasks.includes(t));
```

---

## 範囲解釈

### 自然言語 → タスクマッピング

```typescript
function interpretRange(userInput: string, plans: Task[]): Task[] {
  // パターン1: 「〜から〜まで」
  const rangeMatch = userInput.match(/(.+?)から(.+?)まで/);
  if (rangeMatch) {
    const [_, start, end] = rangeMatch;
    const startIdx = plans.findIndex(t => t.title.includes(start));
    const endIdx = plans.findIndex(t => t.title.includes(end));
    return plans.slice(startIdx, endIdx + 1);
  }

  // パターン2: キーワード列挙
  const keywords = userInput.split(/[,、]/).map(k => k.trim());
  if (keywords.length > 1) {
    return plans.filter(t => keywords.some(k => t.title.includes(k)));
  }

  // パターン3: 「全部」「残り全部」
  if (userInput.includes("全部")) {
    return plans.filter(t => t.status === "cc:TODO");
  }

  // パターン4: 単一キーワード
  return plans.filter(t => t.title.includes(userInput));
}
```

---

## 完了条件

### デフォルト完了条件

1. ✅ 指定範囲の全タスクが `cc:done`
2. ✅ 全体ビルド成功
3. ✅ 全テスト通過（またはテストなし）
4. ✅ harness-review で Critical/High なし

### カスタム完了条件

自然言語で完了条件を指定可能：

- 「テストが全部通るまで」
- 「動作確認できるまで」
- 「Postman で叩けるまで」

---

## エラーハンドリング

### 同じエラーが3回連続

```
戦略を変更:
1. 別アプローチを検索（コードベースから類似パターン）
2. 依存関係を再確認
3. タスクを分割して再試行
```

### max-iterations 到達

```
ユーザーに選択肢を提示:
1. 「もっと粘って」→ 反復回数を増やして継続
2. 「ここは飛ばして次へ」→ ブロックされたタスクをスキップ
3. 「一旦止めて」→ ワークログ保存して中断
```

---

## VibeCoder 向けまとめ

| やりたいこと | 言い方 |
|-------------|--------|
| 全部終わらせて | `/ultrawork 全部やって` |
| この機能だけ | `/ultrawork ログイン機能を完了して` |
| ここからここまで | `/ultrawork 認証からユーザー管理まで` |
| 前回の続き | `/ultrawork 続きやって` |
| もっと粘って | 「もっと粘って」「諦めないで」 |
| 1つずつ確実に | 「1つずつやって」 |
| 進捗確認 | 「進捗どう？」 |
