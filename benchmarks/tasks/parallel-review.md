# タスク: parallel-review

## 概要
複数観点での並列レビューを実行。
v2.4.0 の並列サブエージェント機能の効果を測定。

## テスト対象機能
- `/harness-review` コマンド
- 並列サブエージェント（code-reviewer エージェント）
- セキュリティ + 品質 + パフォーマンス同時レビュー

## 前提条件
- `src/api/auth-handler.ts` が存在（セキュリティ問題含む）
- `src/api/session.ts` が存在（セキュリティ/品質問題含む）
- `src/api/profile.ts` が存在（品質問題含む）
- `src/components/Dashboard.tsx` が存在（品質問題含む）
- `src/utils/sanitize.ts` が存在（XSSレビュー用）

## プロンプト

```
まず可能であれば `/harness-review` を実行してください（プラグインコマンド）。
もしコマンド実行ができない/使えない場合は、Task tool を使って `code-reviewer` サブエージェントを観点別に**並列起動**してレビューしてください。

対象ファイル:
1. src/api/auth-handler.ts
2. src/api/session.ts
3. src/api/profile.ts
4. src/components/Dashboard.tsx
5. src/utils/sanitize.ts

レビュー観点:
- セキュリティ（SQLインジェクション、XSS、認証問題）
- 品質（可読性、保守性、ベストプラクティス）
- パフォーマンス（不要な再レンダリング、最適化）

各観点で問題を特定し、重大度と修正案を提示してください。
```

## 期待される出力
- 3つの観点からのレビュー結果
- 各問題に重大度（Critical/High/Medium/Low）
- 具体的な修正案

## 成功基準
| 基準 | 条件 |
|------|------|
| 観点数 | 3観点のレビュー |
| 問題検出 | 合計10個以上 |
| 並列実行 | サブエージェントが並列起動 |
| 修正案 | 重大な問題に修正案 |

## 測定ポイント
- レビュー完了までの時間
- 並列 vs 逐次の時間差
- 検出された問題の総数
