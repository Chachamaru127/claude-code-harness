---
description: コーディング規約（コードファイル編集時のみ適用）
paths: "**/*.{ts,tsx,js,jsx,py,rb,go,rs,java,kt,swift,c,cpp,h,hpp,cs,php}"
_harness_template: "rules/coding-standards.md.template"
_harness_version: "2.5.27"
---

# Coding Standards

## コミットメッセージ規約

| Prefix | 用途 | 例 |
|--------|------|-----|
| `feat:` | 新機能 | `feat: ユーザー認証を追加` |
| `fix:` | バグ修正 | `fix: ログインエラーを修正` |
| `docs:` | ドキュメント | `docs: README を更新` |
| `refactor:` | リファクタリング | `refactor: 認証ロジックを整理` |
| `test:` | テスト | `test: 認証テストを追加` |
| `chore:` | その他 | `chore: 依存関係を更新` |

## コードスタイル

- ✅ 既存のコードスタイルに従う
- ✅ 変更に必要な最小限の修正のみ
- ❌ 変更していないコードへの「改善」
- ❌ 依頼されていないリファクタリング
- ❌ 過剰なコメント追加

## Pull Request

- タイトル: 変更内容を簡潔に（50文字以内）
- 説明: 「何を」「なぜ」を明記
- テスト方法を必ず記載
- 破壊的変更がある場合は明示

## エラーハンドリング

- 境界（ユーザー入力、外部API）でのみバリデーション
- 内部コードは信頼する
- 起こりえないシナリオのエラーハンドリングは不要
