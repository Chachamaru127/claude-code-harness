# Self-Learning Mechanism

各イテレーションで前回の失敗から学習し、同じ失敗を繰り返さない。

## 学習フロー

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

## 学習戦略パターン

| 失敗パターン | 次イテレーションの戦略 |
|-------------|----------------------|
| 型エラー | 関連する型定義を先に確認 |
| import エラー | パス構造を再確認 |
| テスト失敗 | テストケースを読んで期待値を理解 |
| ビルドエラー | 依存関係を確認、順序変更 |
| 3回連続同じエラー | 別アプローチを試行 |

## Worklog Format

`.claude/state/ultrawork.log.jsonl`:

```jsonl
{"ts":"2025-01-30T10:00:00Z","event":"start","range":"1-5","max_iterations":10}
{"ts":"2025-01-30T10:00:05Z","event":"iteration_start","iteration":1}
{"ts":"2025-01-30T10:00:30Z","event":"task_complete","task":"Create Header","status":"success"}
{"ts":"2025-01-30T10:00:55Z","event":"task_failed","task":"Create Footer","error":"Import not found"}
{"ts":"2025-01-30T10:01:25Z","event":"iteration_end","iteration":1,"completed":1,"failed":1}
{"ts":"2025-01-30T10:02:00Z","event":"task_complete","task":"Create Footer","learned_from":"iter 1"}
{"ts":"2025-01-30T10:05:00Z","event":"complete","iterations":3,"tasks_completed":5}
```

## Resume from Worklog

```bash
# 前回の中断から再開
/ultrawork 続きやって

# 内部動作:
# 1. .claude/state/ultrawork.log.jsonl を読み込み
# 2. 最後の iteration_end を特定
# 3. 完了タスクをスキップして未完了から再開
# 4. 失敗履歴を学習データとして引き継ぎ
```
