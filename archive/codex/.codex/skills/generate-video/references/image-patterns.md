# Image Patterns Reference

画像生成の4つのパターン（comparison, concept, flow, highlight）の使用ガイド。

---

## 概要

動画シーンに最適化された画像パターンを定義。各パターンは特定の目的に最適化されており、AI画像生成プロンプトテンプレートと連携します。

### パターン一覧

| パターン | 用途 | 最適シーン | プロンプトテンプレート |
|---------|------|-----------|---------------------|
| **comparison** | Before/After、良い例/悪い例の対比 | 問題提起、改善効果の提示 | `templates/image-prompts/comparison.txt` |
| **concept** | 抽象概念、階層構造、関係性の視覚化 | アーキテクチャ解説、コンセプト説明 | `templates/image-prompts/concept.txt` |
| **flow** | 手順、プロセス、ワークフローの図示 | デモ手順、処理フロー | `templates/image-prompts/flow.txt` |
| **highlight** | 重要ポイント、メッセージの強調 | Hook、CTA、結論 | `templates/image-prompts/highlight.txt` |

---

## 1. Comparison パターン {#comparison}

### 目的

Before/After、良い例/悪い例など、2つの状態や選択肢を視覚的に対比させる。

### 使用場面

| シーン | 例 |
|--------|-----|
| **問題提起** | 既存ツールの煩雑さ vs 本製品のシンプルさ |
| **改善効果** | 導入前（手動、遅い）vs 導入後（自動、速い） |
| **機能比較** | 従来の方法 vs 新機能 |
| **リリースノート** | 旧バージョン vs 新バージョン |

### 視覚構成

```
┌──────────────────────────────────────────┐
│                                          │
│  [悪い例/Before]  🠖  [良い例/After]      │
│                                          │
│  ❌ 問題点1         ✅ 改善点1           │
│  ❌ 問題点2         ✅ 改善点2           │
│  ❌ 問題点3         ✅ 改善点3           │
│                                          │
└──────────────────────────────────────────┘
```

### JSON 例

```json
{
  "type": "comparison",
  "topic": "タスク管理の改善",
  "style": "modern",
  "colorScheme": {
    "primary": "#3B82F6",
    "secondary": "#10B981",
    "background": "#1F2937"
  },
  "comparison": {
    "leftSide": {
      "label": "Before",
      "items": [
        "手動でスプレッドシート管理",
        "更新漏れが頻発",
        "ステータス把握に30分"
      ],
      "icon": "x",
      "sentiment": "negative"
    },
    "rightSide": {
      "label": "After",
      "items": [
        "自動でダッシュボード更新",
        "リアルタイム同期",
        "ステータス把握が一目瞭然"
      ],
      "icon": "check",
      "sentiment": "positive"
    },
    "divider": "arrow"
  }
}
```

### プロンプト生成のポイント

- **左側（Before/悪い例）**: 赤系、警告アイコン、散らかった印象
- **右側（After/良い例）**: 緑系、チェックアイコン、整理された印象
- **区切り**: 明確な矢印または "VS" で視覚的分離
- **テキスト**: 短く具体的（各項目20文字以内推奨）

### 避けるべきパターン

| ❌ 避ける | ✅ 推奨 |
|----------|---------|
| 長文の羅列 | 短いキーワード |
| 抽象的な説明 | 具体的な数値・結果 |
| 中間的な評価 | 明確な対比 |
| 両側に同じアイコン | 異なる感情のアイコン |

---

## 2. Concept パターン {#concept}

### 目的

抽象的な概念、階層構造、要素間の関係性を視覚的に表現する。

### 使用場面

| シーン | 例 |
|--------|-----|
| **アーキテクチャ解説** | システム構成図、レイヤー構造 |
| **コンセプト説明** | 哲学、設計思想、価値提供の図示 |
| **関係性** | コンポーネント間の依存関係 |
| **プロセス全体像** | エコシステム、ワークフロー全体 |

### 視覚構成（階層例）

```
        ┌───────────┐
        │  最上位   │
        └─────┬─────┘
              │
     ┌────────┴────────┐
     │                 │
┌────▼────┐       ┌────▼────┐
│ レベル1 │       │ レベル1 │
└─────────┘       └────┬────┘
                       │
                  ┌────▼────┐
                  │ レベル2 │
                  └─────────┘
```

### JSON 例

```json
{
  "type": "concept",
  "topic": "マイクロサービスアーキテクチャ",
  "style": "technical",
  "colorScheme": {
    "primary": "#6366F1",
    "secondary": "#8B5CF6",
    "background": "#0F172A"
  },
  "concept": {
    "elements": [
      {
        "id": "api-gateway",
        "label": "API Gateway",
        "description": "全リクエストの入り口",
        "level": 0,
        "icon": "cloud",
        "emphasis": "high"
      },
      {
        "id": "auth-service",
        "label": "認証サービス",
        "level": 1,
        "parentId": "api-gateway",
        "icon": "server",
        "emphasis": "medium"
      },
      {
        "id": "data-service",
        "label": "データサービス",
        "level": 1,
        "parentId": "api-gateway",
        "icon": "database",
        "emphasis": "medium"
      }
    ],
    "relationships": [
      {
        "from": "api-gateway",
        "to": "auth-service",
        "label": "認証確認",
        "type": "flow"
      },
      {
        "from": "api-gateway",
        "to": "data-service",
        "label": "データ取得",
        "type": "flow"
      }
    ],
    "layout": "hierarchy"
  }
}
```

### レイアウトタイプ

| レイアウト | 用途 | 視覚イメージ |
|-----------|------|------------|
| **hierarchy** | 階層構造（組織図、依存関係） | 上から下へのツリー |
| **radial** | 中心から放射（エコシステム） | 中央に主要要素、周囲に関連要素 |
| **grid** | 並列配置（カテゴリ分類） | マトリックス配置 |
| **flow** | 処理フロー（パイプライン） | 左から右への流れ |
| **circular** | 循環プロセス（ライフサイクル） | 円環状 |

### プロンプト生成のポイント

- **要素数**: 2-10個（多すぎると見づらい）
- **階層**: 最大3-4レベルまで
- **アイコン**: 要素の性質を直感的に表現
- **関係性**: 矢印の太さや色で重要度を表現

### 避けるべきパターン

| ❌ 避ける | ✅ 推奨 |
|----------|---------|
| 10個以上の要素 | 7個以内に絞る |
| 複雑な関係線 | 主要な関係のみ |
| 長い説明文 | 短いラベル + アイコン |
| 同じ見た目の要素 | 強調度で差別化 |

---

## 3. Flow パターン {#flow}

### 目的

手順、プロセス、ワークフローを時系列またはステップ順で視覚化する。

### 使用場面

| シーン | 例 |
|--------|-----|
| **デモ手順** | セットアップから実行までのステップ |
| **ユーザーフロー** | ログイン → 操作 → 完了の流れ |
| **処理フロー** | データパイプライン、CI/CDフロー |
| **オンボーディング** | 初回利用の導線 |

### 視覚構成（水平例）

```
[1. 開始] ──▶ [2. 入力] ──▶ [3. 処理] ──▶ [4. 完了]
   ⏱2分         ⏱1分         ⏱3秒         即座
```

### JSON 例

```json
{
  "type": "flow",
  "topic": "動画生成フロー",
  "style": "modern",
  "colorScheme": {
    "primary": "#F59E0B",
    "secondary": "#EF4444",
    "background": "#111827"
  },
  "flow": {
    "steps": [
      {
        "id": "analyze",
        "label": "コードベース分析",
        "description": "プロジェクト構造を自動検出",
        "order": 1,
        "type": "start",
        "icon": "circle",
        "duration": "10秒"
      },
      {
        "id": "plan",
        "label": "シナリオ生成",
        "description": "最適な動画構成を提案",
        "order": 2,
        "type": "process",
        "icon": "square",
        "duration": "20秒"
      },
      {
        "id": "generate",
        "label": "並列生成",
        "description": "各シーンを同時作成",
        "order": 3,
        "type": "parallel",
        "icon": "rounded",
        "duration": "2分"
      },
      {
        "id": "render",
        "label": "レンダリング",
        "description": "最終動画を出力",
        "order": 4,
        "type": "end",
        "icon": "hexagon",
        "duration": "30秒"
      }
    ],
    "direction": "horizontal",
    "arrowStyle": "solid",
    "showNumbers": true
  }
}
```

### ステップタイプ

| タイプ | 用途 | 視覚表現 |
|--------|------|---------|
| **start** | フローの開始点 | 丸アイコン、緑色 |
| **process** | 通常の処理ステップ | 四角、青色 |
| **decision** | 条件分岐 | ひし形、黄色 |
| **parallel** | 並列処理 | 複数アイコン、紫色 |
| **subprocess** | サブフロー | 角丸四角 |
| **end** | フローの終了点 | 二重丸、赤色 |

### プロンプト生成のポイント

- **方向**: 横（horizontal）が読みやすい（英語圏向け）
- **ステップ数**: 2-10ステップ（多すぎると複雑）
- **所要時間**: 各ステップに時間を表示すると実用的
- **番号**: 順序を明示（showNumbers: true）

### 避けるべきパターン

| ❌ 避ける | ✅ 推奨 |
|----------|---------|
| 10ステップ以上 | 7ステップ以内に統合 |
| 複雑な分岐 | 線形フローに単純化 |
| 長いステップ名 | 動詞 + 名詞で簡潔に |
| 不明確な順序 | order フィールドで明示 |

---

## 4. Highlight パターン {#highlight}

### 目的

単一のメッセージ、キーワード、数値を強調表示する。

### 使用場面

| シーン | 例 |
|--------|-----|
| **Hook（冒頭）** | "もう手動で消耗していませんか？" |
| **CTA（行動喚起）** | "今すぐ試す" |
| **結論** | "3倍速く、10倍簡単" |
| **重要メトリクス** | "95%の時間削減" |

### 視覚構成

```
┌────────────────────────────────────────┐
│                                        │
│                                        │
│          ⚡ 3倍速く、10倍簡単 ⚡         │
│                                        │
│         自動化で変わる開発体験          │
│                                        │
└────────────────────────────────────────┘
```

### JSON 例

```json
{
  "type": "highlight",
  "topic": "製品価値の強調",
  "style": "gradient",
  "colorScheme": {
    "primary": "#EC4899",
    "accent": "#8B5CF6",
    "background": "#18181B"
  },
  "highlight": {
    "mainText": "95%の時間削減",
    "subText": "手動作業から解放される開発チーム",
    "icon": "rocket",
    "position": "center",
    "effect": "glow",
    "fontSize": "xlarge",
    "emphasis": "high"
  }
}
```

### エフェクトタイプ

| エフェクト | 用途 | 視覚表現 |
|-----------|------|---------|
| **glow** | 神々しい強調（CTA、結論） | 発光エフェクト |
| **shadow** | 落ち着いた強調（Hook） | ドロップシャドウ |
| **gradient** | モダンな印象 | グラデーション背景 |
| **outline** | シャープな印象 | アウトラインのみ |
| **none** | ミニマル | 装飾なし |

### アイコンと感情

| アイコン | 感情・意味 | 使用場面 |
|---------|-----------|---------|
| **star** | 優秀、品質 | 機能紹介、評価 |
| **check** | 完了、成功 | 導入効果、結果 |
| **alert** | 注意喚起 | 問題提起、警告 |
| **trophy** | 達成、勝利 | 成果、実績 |
| **rocket** | 高速、革新 | パフォーマンス、新機能 |
| **fire** | 人気、話題 | トレンド、注目 |
| **bolt** | 即座、パワー | 速度、効率 |

### プロンプト生成のポイント

- **短さが命**: メインテキストは10文字以内が理想
- **数値**: 具体的な数値は説得力が高い（"95%", "3倍"）
- **対比**: "速く、簡単" のように2つの価値を並べる
- **感情**: アイコン + エフェクトで感情を増幅

### 避けるべきパターン

| ❌ 避ける | ✅ 推奨 |
|----------|---------|
| 長文（20文字以上） | 短いキャッチコピー |
| 複数の主張 | 1つに絞る |
| 地味なデザイン | エフェクトで目立たせる |
| 小さいフォント | xlarge 推奨 |

---

## パターン選択ガイド

### シーンタイプ別の推奨パターン

| シーンタイプ | 第1推奨 | 第2推奨 | 用途 |
|------------|---------|---------|------|
| **Hook** | highlight | comparison | 強烈な第一印象 |
| **Problem** | comparison | concept | 現状の課題を明示 |
| **Solution** | concept | flow | 解決策の仕組み |
| **Demo** | flow | comparison | 手順の可視化 |
| **Differentiator** | comparison | concept | 差別化ポイント |
| **CTA** | highlight | - | 行動喚起 |

### ファネル別の使用頻度

| パターン | 認知・興味 | 検討 | 確信 | 継続 |
|---------|-----------|------|------|------|
| **comparison** | ★★★ | ★★★ | ★★☆ | ★☆☆ |
| **concept** | ★☆☆ | ★★★ | ★★★ | ★★☆ |
| **flow** | ★★☆ | ★★★ | ★★☆ | ★★★ |
| **highlight** | ★★★ | ★★☆ | ★★★ | ★☆☆ |

### 複数パターンの組み合わせ

**90秒ティザー（LP/広告向け）の例**:

| 秒数 | シーン | パターン | 内容 |
|------|--------|---------|------|
| 0-5秒 | Hook | **highlight** | "もう手動で消耗していませんか？" |
| 5-15秒 | Problem | **comparison** | Before（手動）vs After（自動） |
| 15-55秒 | Solution | **flow** | セットアップ → 実行 → 完了の3ステップ |
| 55-70秒 | Proof | **concept** | アーキテクチャの堅牢性 |
| 70-90秒 | CTA | **highlight** | "今すぐ無料で始める" |

---

## 実装時の注意事項

### 1. JSON Schema バリデーション

- **必須**: `type`, `topic` フィールドは必須
- **oneOf**: パターンに応じた専用フィールドが必須（例: type="comparison" なら comparison フィールド必須）
- **バリデーション**: `scripts/validate-visual-pattern.js` で検証

### 2. プロンプトテンプレートとの連携

- **テンプレート**: `templates/image-prompts/{type}.txt` を使用
- **プレースホルダー**: `{{topic}}`, `{{items}}`, `{{style}}` 等を JSON 値で置換
- **生成**: `references/image-generator.md` が実際の生成を担当

### 3. 画像品質チェック

- **自動判定**: `references/image-quality-check.md` で品質評価
- **再試行**: 不合格の場合、最大3回まで再生成
- **決定性**: seed 値を保存し、再現性を確保

### 4. アセット管理

- **出力先**: `out/video-{id}/assets/generated/`
- **マニフェスト**: `assets.manifest.schema.json` に記録
- **ハッシュ**: SHA-256 で改ざん検出

---

## 関連ドキュメント

- [visual-patterns.schema.json](../schemas/visual-patterns.schema.json) - JSON Schema 定義
- [image-generator.md](./image-generator.md) - AI画像生成実装
- [image-quality-check.md](./image-quality-check.md) - 品質判定ロジック
- [templates/image-prompts/](../templates/image-prompts/) - プロンプトテンプレート
- [best-practices.md](./best-practices.md) - 動画全体のベストプラクティス

---

**作成日**: 2026-02-02
**対象Phase**: Phase 6 - 画像生成パターン
**メンテナンス**: スキーマ変更時に更新
