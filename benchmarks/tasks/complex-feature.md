# タスク: complex-feature

## 概要
複数ファイルにまたがる機能を計画から実装まで一貫して行う。
Plan → Work → Review の完全なワークフローをテスト。

## テスト対象機能
- `/plan-with-agent` → `/work` → `/harness-review` の連携
- 複数ファイル生成
- スキル評価フロー

## プロンプト

```
以下の機能を計画・実装・レビューまで完了させてください。

機能: ユーザー管理API
- src/models/user.ts - Userモデル（id, name, email, role, createdAt）
- src/repositories/user-repository.ts - CRUD操作（メモリストア）
- src/services/user-service.ts - ビジネスロジック（バリデーション含む）
- src/api/user-controller.ts - RESTエンドポイント（GET/POST/PUT/DELETE）
- src/utils/validators.ts - 入力バリデーション関数

各ファイルは適切な型定義を含み、エラーハンドリングを実装してください。
最後にコード品質をレビューしてください。
```

## 期待される出力
- 5つのファイルが作成される
- 各ファイル間で適切にimport/exportされている
- エラーハンドリングが実装されている
- レビュー結果が出力される

## 成功基準
| 基準 | 条件 |
|------|------|
| ファイル数 | 5つ以上 |
| 型定義 | 全ファイルにTypeScript型 |
| エラー処理 | try-catch が存在 |
| レビュー | 問題点/改善案が出力 |

## 測定ポイント
- 全体の所要時間
- Plan → Work → Review の各フェーズ時間
- 並列実行の有無
