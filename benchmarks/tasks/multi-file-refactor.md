# タスク: multi-file-refactor

## 概要
複数ファイルにまたがるリファクタリング。
並列処理の効果が顕著に出るタスク。

## テスト対象機能
- `/work` コマンド
- 並列ファイル編集
- コード分析と変換

## 前提条件
複数のレガシーファイルが存在すること

## プロンプト

```
以下のレガシーコードを全てモダンなTypeScriptにリファクタリングしてください。
可能であれば並列で処理してください。

対象:
1. src/legacy/user-service.js → src/services/user.service.ts
   - ES6+ 構文に変換
   - async/await パターンに変換
   - 型定義を追加

2. 新規作成: src/types/user.types.ts
   - User, CreateUserDTO, UpdateUserDTO インターフェース

3. 新規作成: src/errors/user.errors.ts
   - UserNotFoundError, ValidationError クラス

4. 新規作成: src/services/__tests__/user.service.test.ts
   - 主要メソッドのユニットテスト

全ファイル間で整合性を保ってください。
```

## 期待される出力
- 4つのファイルが作成/更新される
- 型定義が適切に分離されている
- カスタムエラークラスが定義されている
- テストファイルが作成されている

## 成功基準
| 基準 | 条件 |
|------|------|
| ファイル数 | 4ファイル以上 |
| 型定義 | interfaceが定義 |
| エラークラス | Errorを継承 |
| テスト | describe/itが存在 |

## 測定ポイント
- リファクタリング完了時間
- 並列処理の有無
- 生成されたコード行数
