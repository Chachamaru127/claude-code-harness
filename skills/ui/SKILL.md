---
name: ui
description: "Generates UI components and feedback forms. Use when user mentions components, UI, hero sections, forms, feedback, or contact requests. Do NOT load for: authentication features, backend implementation, database operations, or business logic."
allowed-tools: ["Read", "Write", "Edit", "Bash"]
---

# UI Skills

UIコンポーネントとフォームの生成を担当するスキル群です。

## 制約の優先順位と適用条件

1. 基本は `references/ui-skills.md` の制約を最優先で適用する。
2. `references/frontend-design.md` は「尖った/独自/表現強め/ブランド強化」などが**明示**された場合のみ適用する。
3. UI Skills の MUST/NEVER は原則維持。ただし**ユーザーが明示的に要求した場合のみ**以下の例外を許可する:
   - グラデーション、発光、強い装飾
   - アニメーション（追加・拡張）
   - カスタム easing

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **制約セット** | See [references/ui-skills.md](references/ui-skills.md) / [references/frontend-design.md](references/frontend-design.md) |
| **コンポーネント生成** | See [references/component-generation.md](references/component-generation.md) |
| **フィードバックフォーム** | See [references/feedback-forms.md](references/feedback-forms.md) |

## 実行手順

1. **制約セットを適用**（優先順位に従う）
2. **品質判定ゲート**（Step 0）
3. ユーザーのリクエストを分類
4. 上記の「機能詳細」から適切な参照ファイルを読む
5. その内容に従って生成

### Step 0: 品質判定ゲート（a11y チェックリスト）

UI コンポーネント生成時は、アクセシビリティを確保:

```markdown
♿ アクセシビリティチェックリスト

生成する UI は以下を満たすことを推奨：

### 必須項目
- [ ] 画像に alt 属性を設定
- [ ] フォーム要素に label を関連付け
- [ ] キーボード操作可能（Tab でフォーカス移動）
- [ ] フォーカス状態が視覚的に分かる

### 推奨項目
- [ ] 色だけに依存しない情報伝達
- [ ] コントラスト比 4.5:1 以上（テキスト）
- [ ] aria-label / aria-describedby の適切な使用
- [ ] 見出し構造（h1 → h2 → h3）が論理的

### インタラクティブ要素
- [ ] ボタンに適切なラベル（「詳細」ではなく「製品詳細を見る」）
- [ ] モーダル/ダイアログのフォーカストラップ
- [ ] エラーメッセージがスクリーンリーダーで読まれる
```

### VibeCoder 向け

```markdown
♿ 誰でも使えるデザインにするために

1. **画像には説明をつける**
   - 「商品画像」ではなく「赤いスニーカー、正面から」

2. **クリックできる場所はキーボードでも操作可能に**
   - Tab キーで移動、Enter で決定

3. **色だけで判断させない**
   - 赤=エラー だけでなく、アイコン+テキストも
```
