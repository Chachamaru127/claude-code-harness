# タスク: impl-utility

## 概要
ユーティリティ関数を実装する。

## テスト対象機能
- `/work` コマンド
- コード生成能力
- ファイル作成/編集

## プロンプト

```
src/utils/string-helpers.ts に以下のユーティリティ関数を実装してください。

1. truncate(str: string, maxLength: number): string
   - 文字列を指定長で切り詰め、末尾に "..." を付ける
   - maxLength より短い場合はそのまま返す

2. slugify(str: string): string
   - 文字列をURL用スラッグに変換
   - 小文字化、スペースをハイフンに、特殊文字を除去

3. capitalize(str: string): string
   - 最初の文字を大文字にする

TypeScript で型安全に実装してください。
```

## 期待される出力
- `src/utils/string-helpers.ts` が作成される
- 3つの関数が実装される
- 適切な型定義がある

## 成功基準
| 基準 | 条件 |
|------|------|
| ファイル作成 | string-helpers.ts が存在 |
| 関数数 | 3つの関数が定義 |
| 型定義 | TypeScript の型が適切 |
| エラーなし | tsc でエラーが出ない |

## 測定ポイント
- 実装完了までの時間
- ツール呼び出し回数（Write, Edit）
- コード行数
