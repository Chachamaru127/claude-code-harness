# 投稿テンプレート

X (Twitter) 5本スレッドのテンプレート定義。

## スレッド構成

| Post | 役割 | 文字数目安 | 必須要素 |
|------|------|----------|---------|
| 1/5 | 告知 | ~200字 | バージョン、ハイライト3点、🧵 |
| 2/5 | 機能詳細 A | ~250字 | 問題→解決策の構造 |
| 3/5 | 機能詳細 B | ~250字 | 問題→解決策の構造 |
| 4/5 | 機能詳細 C | ~250字 | 箇条書き or カード形式 |
| 5/5 | まとめ + CTA | ~200字 | チェックリスト、GitHub URL |

## テンプレート

### Post 1: 告知

```
🧡 Claude Harness v{VERSION} リリース

{CHANGELOG_THEME}

主なハイライト:
⚙️ {HIGHLIGHT_1}
🔄 {HIGHLIGHT_2}
⚡ {HIGHLIGHT_3}

以下スレッドで詳しく紹介します 🧵👇
```

### Post 2-4: 機能詳細

```
{EMOJI} {FEATURE_TITLE}

{PROBLEM_DESCRIPTION}

{SOLUTION_PREFIX}:
・{SOLUTION_POINT_1}
・{SOLUTION_POINT_2}

{OPTIONAL_TECHNICAL_NOTE}
```

### Post 5: まとめ + CTA

```
🧡 Claude Harness v{VERSION} まとめ

{THEME_ONELINER}:
✅ {FEATURE_1} → {BENEFIT_1}
✅ {FEATURE_2} → {BENEFIT_2}
✅ {FEATURE_3} → {BENEFIT_3}
✅ {FEATURE_4} → {BENEFIT_4}
...

GitHub で公開中です 👇
https://github.com/tachibanashuuta/claude-code-harness
```

## CHANGELOG 分析ルール

### CC統合パターンの場合

CHANGELOG に `CC のアプデ` / `Harness での活用` 形式がある場合:

1. 各 `##### N-X.` セクションから機能名を抽出
2. `CC のアプデ` → 問題/背景の説明に使用
3. `Harness での活用` → 解決策の説明に使用
4. ハイライト3点は影響度が高い順に選択

### 通常リリースの場合

CHANGELOG に `今まで` / `今後` 形式がある場合:

1. 各 `#### N.` セクションから機能名を抽出
2. `今まで` → 問題の説明に使用
3. `今後` → 解決策の説明に使用

## トーンガイドライン

- カジュアルすぎず、堅すぎない技術者向けトーン
- 絵文字は各投稿の冒頭と箇条書きに使用（過剰に使わない）
- 技術用語はそのまま使用（MCP、Worktree、Breezing 等）
- 「〜しました」形式ではなく「〜できるようになった」「〜が解消」等の体験ベース表現
- X の文字数制限（280字 / 日本語は140字換算）を意識。1投稿あたり最大280字
