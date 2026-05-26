# 演出ガイド - Direction Guide

generate-videoスキルの視覚演出システムの使い分けとベストプラクティスを定義します。

---

## 概要

演出システムは以下の4要素で構成されます：

| 要素 | 役割 | 制御内容 |
|------|------|---------|
| **transition** | シーン切り替え | フェード、スライド、ズーム、カット |
| **emphasis** | 要素強調 | 3段階強調 + 効果音 |
| **background** | 背景デザイン | 5種類の背景スタイル |
| **timing** | タイミング調整 | 待機時間、音声オフセット |

---

## Transition（トランジション）

### 4種類のトランジション

| Type | 用途 | 視覚効果 | 推奨 duration |
|------|------|---------|--------------|
| **fade** | 汎用的な切り替え | 滑らかなフェードイン/アウト | 500ms (15f) |
| **slideIn** | 次の話題への移行 | 方向指定スライド（left/right/top/bottom） | 400ms (12f) |
| **zoom** | 詳細への注目誘導 | ズームイン/アウト | 600ms (18f) |
| **cut** | 即座の切り替え | カット（瞬時） | 0ms |

### 使い分けガイドライン

#### fade（フェード）
- **推奨シーン**: 汎用、セクション開始、落ち着いた切り替え
- **効果**: 視覚的に優しい、注意を引きすぎない
- **例**:
  - イントロ → メイン説明
  - 機能説明 → 次の機能説明
  - CTA前の落ち着き

```json
{
  "transition": {
    "type": "fade",
    "duration_ms": 500,
    "easing": "easeInOut"
  }
}
```

#### slideIn（スライドイン）
- **推奨シーン**: 話題転換、比較表示、ステップ進行
- **効果**: 動的、次の内容への期待感
- **direction**:
  - `right`: 前進感（次のステップ）
  - `left`: 過去参照（Before/After の Before）
  - `top`: 重要な情報の登場
  - `bottom`: 補足情報の追加

```json
{
  "transition": {
    "type": "slideIn",
    "duration_ms": 400,
    "direction": "right",
    "easing": "easeOut"
  }
}
```

#### zoom（ズーム）
- **推奨シーン**: 詳細表示、強調、衝撃的な情報
- **効果**: 注目誘導、インパクト
- **例**:
  - 重要な数値の表示
  - 問題の核心提示
  - 差別化ポイントの強調

```json
{
  "transition": {
    "type": "zoom",
    "duration_ms": 600,
    "easing": "easeInOut"
  }
}
```

#### cut（カット）
- **推奨シーン**: デモ操作、高速展開、緊張感
- **効果**: 瞬間的、テンポアップ
- **例**:
  - UI操作のステップ間
  - 高速デモンストレーション
  - リズミカルな機能紹介

```json
{
  "transition": {
    "type": "cut",
    "duration_ms": 0
  }
}
```

### ファネル別推奨トランジション

| ファネル段階 | 推奨トランジション | 理由 |
|-------------|-------------------|------|
| 認知（LP/広告） | fade, zoom | 落ち着き、衝撃 |
| 興味（Intro） | slideIn, fade | 動的、期待感 |
| 検討（機能デモ） | cut, slideIn | テンポ、効率 |
| 確信（アーキテクチャ） | fade, zoom | 詳細、信頼 |
| 継続（オンボーディング） | slideIn, cut | ステップ進行 |

---

## Emphasis（強調）

### 3段階の強調レベル

| Level | 用途 | 視覚効果 | 推奨効果音 |
|-------|------|---------|-----------|
| **high** | 最重要メッセージ | 大きなアニメーション、明るいカラー | whoosh, chime |
| **medium** | 重要ポイント | 中程度のアニメーション、アクセントカラー | pop |
| **low** | 補足情報 | 控えめな強調、淡いカラー | none, ding |

### 使い分けガイドライン

#### high（高強調）
- **推奨シーン**:
  - Hook（最初の衝撃）
  - CTA（行動喚起）
  - 差別化ポイント（Differentiator）
  - 驚くべき結果・数値

- **視覚効果**:
  - テキストサイズ: 特大
  - カラー: 鮮やか（デフォルト: `#00F5FF` シアン）
  - アニメーション: scale 1.2, bounce
  - 効果音: `whoosh` または `chime`

- **例**:
  - "3倍速くなる" → high emphasis
  - "今すぐ無料で試す" → high emphasis

```json
{
  "emphasis": {
    "level": "high",
    "text": ["3倍速くなる"],
    "sound": "whoosh",
    "color": "#00F5FF",
    "position": "center"
  }
}
```

#### medium（中強調）
- **推奨シーン**:
  - 機能説明の要点
  - ワークフローのステップ
  - 問題提示（Problem）
  - 解決策（Solution）

- **視覚効果**:
  - テキストサイズ: 大
  - カラー: アクセント（デフォルト: `#FFC700` ゴールド）
  - アニメーション: scale 1.1, fade-in
  - 効果音: `pop`

- **例**:
  - "ステップ1: 設定" → medium emphasis
  - "こんな問題ありませんか？" → medium emphasis

```json
{
  "emphasis": {
    "level": "medium",
    "text": ["ステップ1: 設定"],
    "sound": "pop",
    "color": "#FFC700",
    "position": "top"
  }
}
```

#### low（低強調）
- **推奨シーン**:
  - 補足情報
  - 追加機能の軽い紹介
  - 注釈
  - 詳細情報へのリンク

- **視覚効果**:
  - テキストサイズ: 通常
  - カラー: 淡い（デフォルト: `#A8DADC` ライトブルー）
  - アニメーション: fade-in のみ
  - 効果音: `none` または `ding`

- **例**:
  - "※詳細はドキュメント参照" → low emphasis
  - "その他多数の機能" → low emphasis

```json
{
  "emphasis": {
    "level": "low",
    "text": ["※詳細はドキュメント参照"],
    "sound": "none",
    "color": "#A8DADC",
    "position": "bottom"
  }
}
```

### 効果音の選び方

| Sound | 音の特徴 | 推奨用途 |
|-------|---------|---------|
| **whoosh** | 風切り音、ダイナミック | high emphasis、画面遷移 |
| **chime** | チャイム、美しい響き | CTA、成功表示 |
| **pop** | ポップ、軽快 | medium emphasis、ボタン表示 |
| **ding** | 小さな鈴の音 | low emphasis、軽い通知 |
| **none** | 無音 | 静かな情報、連続表示 |

### ファネル別推奨強調レベル

| ファネル段階 | 主要強調 | 補助強調 |
|-------------|---------|---------|
| 認知（LP/広告） | high 多用 | medium 適度 |
| 興味（Intro） | high 1-2回 | medium 多用 |
| 検討（機能デモ） | medium 主体 | low 補足 |
| 確信（アーキテクチャ） | medium 適度 | low 多用 |
| 継続（オンボーディング） | high 目標 | medium ステップ |

---

## Background（背景）

### 5種類の背景スタイル

| Type | 視覚特徴 | 用途 | カラー例 |
|------|---------|------|---------|
| **cyberpunk** | ネオン、グリッド、未来感 | Tech系、先進性アピール | `#0a0e27` + `#00f5ff` |
| **corporate** | 洗練、信頼感、プロフェッショナル | BtoB、エンタープライズ | `#1a1a2e` + `#16213e` |
| **minimal** | シンプル、クリーン、集中 | 説明重視、ドキュメント | `#ffffff` + `#f0f0f0` |
| **gradient** | カラフル、動的、親しみ | BtoC、カジュアル | `#667eea` → `#764ba2` |
| **particles** | 動的パーティクル、エネルギッシュ | Hook、CTA、衝撃 | `#000000` + particles |

### 使い分けガイドライン

#### cyberpunk（サイバーパンク）
- **推奨シーン**:
  - テクノロジーの先進性を訴求
  - 開発者向けツール
  - AI/ML機能の紹介
  - アーキテクチャ図

- **特徴**:
  - ネオングリッド
  - グリッチエフェクト
  - 青・シアン系カラー

```json
{
  "background": {
    "type": "cyberpunk",
    "primaryColor": "#0a0e27",
    "secondaryColor": "#00f5ff",
    "opacity": 0.9
  }
}
```

#### corporate（コーポレート）
- **推奨シーン**:
  - BtoBプロダクト
  - エンタープライズ機能
  - セキュリティ・信頼性訴求
  - 実績・事例紹介

- **特徴**:
  - ダークブルー系
  - クリーンなグラデーション
  - 落ち着いた雰囲気

```json
{
  "background": {
    "type": "corporate",
    "primaryColor": "#1a1a2e",
    "secondaryColor": "#16213e",
    "opacity": 1
  }
}
```

#### minimal（ミニマル）
- **推奨シーン**:
  - コンテンツに集中させたい
  - 複雑な図表・コードの表示
  - オンボーディング
  - ドキュメント的な説明

- **特徴**:
  - 白・グレー系
  - シンプル
  - 視認性重視

```json
{
  "background": {
    "type": "minimal",
    "primaryColor": "#ffffff",
    "secondaryColor": "#f0f0f0",
    "opacity": 1
  }
}
```

#### gradient（グラデーション）
- **推奨シーン**:
  - BtoCプロダクト
  - 親しみやすさ訴求
  - イントロ・CTA
  - カジュアルなトーン

- **特徴**:
  - カラフルなグラデーション
  - 柔らかい印象
  - 視覚的に楽しい

```json
{
  "background": {
    "type": "gradient",
    "primaryColor": "#667eea",
    "secondaryColor": "#764ba2",
    "opacity": 0.95
  }
}
```

#### particles（パーティクル）
- **推奨シーン**:
  - Hook（開始時の衝撃）
  - CTA（行動喚起）
  - 重要な転換点
  - エネルギッシュな印象

- **特徴**:
  - 動的なパーティクル
  - エネルギー感
  - 注目誘導

```json
{
  "background": {
    "type": "particles",
    "primaryColor": "#000000",
    "secondaryColor": "#00f5ff",
    "opacity": 0.8
  }
}
```

### ファネル別推奨背景

| ファネル段階 | 推奨背景 | 理由 |
|-------------|---------|------|
| 認知（LP/広告） | particles, gradient | 視覚的インパクト |
| 興味（Intro） | gradient, cyberpunk | 親しみやすさ、先進性 |
| 検討（機能デモ） | minimal, corporate | 集中、信頼感 |
| 確信（アーキテクチャ） | corporate, cyberpunk | プロフェッショナル |
| 継続（オンボーディング） | minimal, gradient | シンプル、親切 |

---

## Timing（タイミング）

### タイミングパラメータ

| Parameter | 用途 | 推奨値 |
|-----------|------|--------|
| **delay_before** | シーン開始前の待機 | 0-15f（0-500ms） |
| **delay_after** | シーン終了後の待機 | 0-30f（0-1000ms） |
| **audio_start_offset** | 音声開始オフセット | 30f（1000ms、標準） |

### 使い分けガイドライン

#### delay_before（開始前待機）
- **用途**:
  - トランジション後の視覚的な落ち着き
  - 前シーンの余韻
  - 注意を引く間

- **推奨値**:
  - `0f`: トランジションで十分な場合
  - `5-10f`: 軽い間
  - `15f`: しっかりした間

```json
{
  "timing": {
    "delay_before": 10
  }
}
```

#### delay_after（終了後待機）
- **用途**:
  - 音声終了後の余韻
  - CTA表示時間の確保
  - 読む時間の確保

- **推奨値**:
  - `0f`: 即座に次へ
  - `15-20f`: 標準的な余韻
  - `30f`: しっかり読ませる

```json
{
  "timing": {
    "delay_after": 20
  }
}
```

#### audio_start_offset（音声開始オフセット）
- **用途**:
  - シーン表示後、音声開始までの待機
  - 視覚的に落ち着いてから音声

- **推奨値**:
  - `30f`（1000ms）: 標準（推奨）
  - `15f`（500ms）: 高速展開
  - `45f`（1500ms）: ゆったり

```json
{
  "timing": {
    "audio_start_offset": 30
  }
}
```

### 音声同期の重要ルール

> **重要**: ナレーション付き動画では以下を厳守

1. **シーン長さの計算式**:
   ```
   duration_ms = audio_start_offset + 音声長さ + delay_after
   ```

2. **音声長さの事前確認**:
   ```bash
   ffprobe -v error -show_entries format=duration \
     -of default=noprint_wrappers=1:nokey=1 audio/scene.wav
   ```

3. **トランジションとの調整**:
   ```
   シーン開始 = 前シーン開始 + 前シーン長 - トランジション長
   音声開始 = シーン開始 + audio_start_offset
   ```

4. **余白の確保**:
   - トランジション開始前に音声が終了すること
   - 最低でも `delay_after: 20f` を確保

---

## ベストプラクティス

### 1. ファネル別演出の組み合わせ

#### 90秒LP/広告ティザー（認知〜興味）
```json
{
  "hook": {
    "transition": { "type": "zoom", "duration_ms": 600 },
    "emphasis": { "level": "high", "sound": "whoosh" },
    "background": { "type": "particles" },
    "timing": { "delay_before": 10, "delay_after": 20 }
  },
  "problem": {
    "transition": { "type": "slideIn", "direction": "right", "duration_ms": 400 },
    "emphasis": { "level": "medium", "sound": "pop" },
    "background": { "type": "gradient" },
    "timing": { "delay_before": 0, "delay_after": 15 }
  },
  "cta": {
    "transition": { "type": "zoom", "duration_ms": 600 },
    "emphasis": { "level": "high", "sound": "chime" },
    "background": { "type": "particles" },
    "timing": { "delay_before": 15, "delay_after": 30 }
  }
}
```

#### 3分Introデモ（興味→検討）
```json
{
  "intro": {
    "transition": { "type": "fade", "duration_ms": 500 },
    "emphasis": { "level": "high", "sound": "whoosh" },
    "background": { "type": "gradient" },
    "timing": { "delay_before": 0, "delay_after": 20 }
  },
  "demo": {
    "transition": { "type": "cut", "duration_ms": 0 },
    "emphasis": { "level": "medium", "sound": "pop" },
    "background": { "type": "minimal" },
    "timing": { "delay_before": 0, "delay_after": 10 }
  },
  "cta": {
    "transition": { "type": "fade", "duration_ms": 500 },
    "emphasis": { "level": "high", "sound": "chime" },
    "background": { "type": "gradient" },
    "timing": { "delay_before": 10, "delay_after": 30 }
  }
}
```

### 2. 効果音の適切な使用

**ルール**:
- 1動画内で効果音は **最大5-7回** まで
- 連続シーンでは効果音を控える（慣れによる効果減少）
- high emphasis には必ず効果音を付ける
- medium emphasis は選択的に
- low emphasis は基本的に無音

### 3. 背景の統一感

**ルール**:
- 1動画内で背景タイプは **2-3種類** まで
- セクション単位で統一（section内は同じ背景）
- Hook/CTAのみ特別な背景（particles）を許容

### 4. トランジションのリズム

**ルール**:
- 同じトランジションを3回以上連続させない
- 高速展開（cut）と緩急（fade/zoom）を組み合わせる
- セクション開始は fade または zoom を推奨

### 5. 強調レベルの配分

**ルール（90秒動画の場合）**:
- high: 2-3回（Hook, Differentiator, CTA）
- medium: 5-8回（主要メッセージ）
- low: 適宜（補足情報）

---

## 設計チェックリスト

シーンの演出設計時に以下を確認：

### トランジション
- [ ] シーンの目的に合ったトランジションを選択
- [ ] 同じトランジションの連続使用を避けている
- [ ] duration_ms は適切か（fade: 500ms, slideIn: 400ms, zoom: 600ms）

### 強調
- [ ] 強調レベルは適切か（high: 最重要のみ）
- [ ] 効果音の使用回数は適切か（全体で5-7回以内）
- [ ] text配列に強調すべきキーワードを指定

### 背景
- [ ] ファネル段階に合った背景タイプを選択
- [ ] セクション内で背景を統一
- [ ] primaryColor, secondaryColor は指定したか

### タイミング
- [ ] audio_start_offset は 30f（標準）か
- [ ] シーン長 = audio_start + 音声長 + delay_after
- [ ] トランジション開始前に音声が終了する

### 全体バランス
- [ ] 効果音の使用は5-7回以内
- [ ] 背景タイプは2-3種類以内
- [ ] high emphasis は2-3回以内

---

## 関連ドキュメント

- [generator.md](./generator.md) - 並列生成フロー
- [visual-effects.md](./visual-effects.md) - 視覚エフェクトライブラリ
- [schemas/direction.schema.json](../schemas/direction.schema.json) - 演出スキーマ定義
- [schemas/emphasis.schema.json](../schemas/emphasis.schema.json) - 強調スキーマ定義
- [schemas/animation.schema.json](../schemas/animation.schema.json) - アニメーションスキーマ定義
