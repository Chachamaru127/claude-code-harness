# タスク: skill-routing

## 概要
スキル評価フローのテスト。
適切なスキルが自動的に選択・起動されるかを測定。

## テスト対象機能
- スキル評価フロー（CLAUDE.mdに記載）
- impl/review/verify スキルのルーティング
- 親スキル → 子スキルへの適切な振り分け

## プロンプト

```
以下の3つのタスクを順番に実行してください。

1. 実装タスク:
   src/utils/date-helpers.ts を作成し、以下の関数を実装:
   - formatDate(date: Date, format: string): string
   - parseDate(str: string): Date
   - isValidDate(date: any): boolean

2. テスト作成タスク:
   上記の関数に対するテストを src/utils/__tests__/date-helpers.test.ts に作成

3. レビュータスク:
   作成したコードの品質をレビューし、改善点を指摘

各タスクで適切なスキルを活用してください。
```

## 期待される出力
- date-helpers.ts が作成される
- テストファイルが作成される
- レビュー結果が出力される

## 成功基準
| 基準 | 条件 |
|------|------|
| 実装 | 3関数が定義 |
| テスト | 各関数にテスト |
| レビュー | 改善点の指摘 |
| スキル起動 | impl, verify, reviewスキルが起動 |

## 測定ポイント
- 各フェーズの所要時間
- スキル起動の有無（ログで確認）
- タスク間の連携品質
