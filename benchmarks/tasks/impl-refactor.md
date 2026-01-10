# タスク: impl-refactor

## 概要
既存のコードをリファクタリングする。

## テスト対象機能
- `/work` コマンド
- コード分析能力
- 安全なリファクタリング

## 前提条件
`src/legacy/user-service.js` が存在すること

## プロンプト

```
src/legacy/user-service.js を TypeScript に変換し、リファクタリングしてください。

要件:
1. JavaScript → TypeScript 変換
2. 適切な型定義の追加
3. エラーハンドリングの改善
4. 関数の分割（1関数1責務）

出力先: src/services/user-service.ts
```

## 期待される出力
- `src/services/user-service.ts` が作成される
- 型定義が追加されている
- try-catch が適切に配置されている
- 関数が適切に分割されている

## 成功基準
| 基準 | 条件 |
|------|------|
| ファイル作成 | TypeScript ファイルが存在 |
| 型定義 | interface/type が定義されている |
| エラー処理 | try-catch が存在 |
| 関数分割 | 元より関数数が増加 |

## 測定ポイント
- リファクタリング完了までの時間
- 編集操作の回数
- 生成されたコード行数
