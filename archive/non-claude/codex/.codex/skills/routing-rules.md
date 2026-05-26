# Skill Routing Rules (Reference)

スキル間のルーティングルールのリファレンスドキュメント。

> **SSOT の場所**: 各スキルの `description` フィールドがルーティングの SSOT です。
> このファイルは詳細な説明と例を提供するリファレンスであり、実際のルーティングは各スキルの description に依存します。
>
> **重要**: 各スキルの description と本文の「Do NOT Load For」テーブルは完全一致している必要があります。

## Codex 関連ルーティング

### harness-review (Codex レビュー機能を包含)

**目的**: Codex CLI (`codex exec`) でセカンドオピニオンレビューを提供（v3 で `codex-review` から統合）

**トリガーキーワード**（description から引用）:
- "review", "code review", "plan review"
- "scope analysis", "security", "performance"
- "quality checks", "PRs", "diffs"
- "/harness-review"

**除外キーワード**（description から引用）:
- "implementation", "new features", "bug fixes"
- "setup", "release"

### harness-work --codex (Codex 実装機能を包含)

**目的**: Codex を実装エンジンとして使用（v3 で統合）

**トリガーキーワード**:
- "implement", "execute", "/work"
- "breezing", "team run"
- "--codex", "--parallel"

**除外キーワード**（description から引用）:
- "planning", "code review", "release"
- "setup", "initialization"

**対応**: `/harness-work --codex` で実行

## ルーティング判定フロー（参考）

> このセクションは Claude Code の内部動作の説明であり、追加のキーワード定義ではありません。
> 実際のルーティングは各スキルの description に記載されたキーワードのみで判定されます。

```
ユーザー入力
    │
    ├── description のトリガーキーワードにマッチ → 該当スキルをロード
    ├── description の除外キーワードにマッチ → 該当スキルを除外
    └── どちらでもない → 通常のスキルマッチング
```

## 優先順位ルール（参考）

キーワードが複数のスキルにマッチする場合の優先順位:

1. **除外が最優先**: 除外キーワードにマッチしたスキルは絶対にロードしない
2. **具体的なキーワードが優先**: 完全一致 > 部分一致

> **注**: 「文脈判定」は曖昧さを生むため使用しない。description のキーワードで決定的に判定される。

## 更新ルール

1. **description = SSOT**: 各スキルの `description` フィールドがルーティングの正式な定義
2. **本文との一致**: 各スキルの「Do NOT Load For」テーブルは description と完全一致が必須
3. **このファイルの役割**: 詳細な説明と判定フローのリファレンス（SSOT ではない）
4. **完全リスト維持**: 汎用表現（"〜全般"）を使わず、具体的なキーワードを列挙する
