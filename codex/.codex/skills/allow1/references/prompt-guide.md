# プロンプトガイド — 高品質 SVG を生成するためのベストプラクティス

---

## prompt vs instructions の使い分け

| フィールド | 役割 | 例 |
|-----------|------|-----|
| `prompt` | **何を**生成するか（主題・内容） | "A mountain logo for a hiking app" |
| `instructions` | **どのように**生成するか（スタイル・制約） | "Flat design, monochrome, 24x24 viewBox" |

**コツ**: prompt は具体的な描写に集中し、instructions でスタイルや技術的制約を分離する。

---

## プロンプト構造テンプレート

### ロゴ

```
A [style] logo for [brand/product name], a [industry/description].
The logo should convey [values/feelings].
[Optional: Include/exclude specific elements]
```

**例**:
```
A modern geometric logo for Nexus, a cloud computing platform.
The logo should convey innovation and reliability.
Include an abstract representation of connected nodes.
```

### アイコン

```
A [style] icon of [subject] for [context/usage].
[Size/format constraints]
```

**例**:
```
A line-art icon of a shopping cart for an e-commerce mobile app.
Simple enough to be clear at 16x16 pixels.
```

### イラスト

```
An illustration of [scene/subject] for [purpose].
[Mood/atmosphere description]
```

**例**:
```
An illustration of a team collaborating remotely for a SaaS landing page.
Warm, friendly atmosphere with soft colors.
```

---

## instructions のパターン集

### スタイル指定

| カテゴリ | instructions 例 |
|---------|----------------|
| **フラットデザイン** | `"Flat design, solid colors, no gradients, no shadows"` |
| **線画** | `"Line art style, uniform stroke width, no fills"` |
| **ミニマル** | `"Minimalist, maximum 3 shapes, limited color palette"` |
| **グラデーション** | `"Use subtle gradients, modern glassmorphism style"` |
| **モノクロ** | `"Monochrome, single color with varying opacity"` |
| **アイソメトリック** | `"Isometric 3D perspective, flat shading"` |

### 技術的制約

| 制約 | instructions 例 |
|------|----------------|
| **viewBox 指定** | `"24x24 viewBox"` or `"viewBox 0 0 100 100"` |
| **ストローク制御** | `"Stroke-based, 2px stroke width, round line caps and joins"` |
| **カラー制御** | `"Use currentColor for all fills and strokes"` |
| **サイズ制限** | `"Must be recognizable at 16x16 pixels"` |
| **色数制限** | `"Maximum 3 colors: #1a1a2e, #16213e, #e94560"` |
| **アクセシビリティ** | `"High contrast, WCAG AA compliant color combinations"` |

### ブランドガイドライン準拠

```
"Follow brand guidelines: primary color #2563EB, secondary #64748B,
rounded corners (4px radius), geometric shapes only,
no organic curves, professional corporate style"
```

---

## 品質向上テクニック

### 1. 段階的に精度を上げる

```
Step 1: 高 temperature (0.9) + 多数 (n=16) → 方向性を探索
Step 2: 気に入った方向の prompt を洗練 + 中 temperature (0.5) + n=8
Step 3: 最終調整 + 低 temperature (0.3) + n=4
```

### 2. リファレンス画像を活用

```json
{
  "prompt": "A modern version of this vintage logo",
  "references": [
    { "url": "https://example.com/vintage-logo.png" },
    { "url": "https://example.com/modern-style-reference.png" }
  ]
}
```

- 最大 **4 枚**のリファレンス画像
- 「このスタイルで」「この配色で」「このレイアウトを参考に」等の指示と組み合わせる

### 3. ネガティブ指示

prompt や instructions に「避けるべきもの」を明記:

```
"Do NOT include text or typography.
Avoid gradients and shadows.
No realistic/photographic elements."
```

### 4. 色パレットの直接指定

```json
{
  "instructions": "Use exactly these colors: #FF6B6B (coral), #4ECDC4 (teal), #2C3E50 (dark blue). No other colors."
}
```

---

## アンチパターン（避けるべきこと）

| NG パターン | 理由 | 改善案 |
|------------|------|--------|
| `"Make a good logo"` | 曖昧すぎる | 業種、スタイル、用途を具体的に |
| `"Logo with text 'ABC Corp'"` | テキスト生成は SVG の強みではない | テキストなしのシンボルマークに集中 |
| 1 回で完璧を求める | SVG 生成は探索的プロセス | n=8〜16 で探索 → 絞り込み |
| instructions なしで生成 | スタイルが不安定 | 最低限のスタイル指示を含める |
| temperature=0 | 出力が単調 | 最低 0.2 以上を推奨 |

---

## 用途別チートシート

### Web アプリ用アイコンセット

```json
{
  "prompt": "[icon description]",
  "instructions": "24x24 viewBox, stroke-based, 1.5px stroke width, round line caps, currentColor, consistent style across set",
  "temperature": 0.3,
  "n": 4
}
```

### SNS / ブランディング用ロゴ

```json
{
  "prompt": "[brand description and values]",
  "instructions": "Clean vector, max 3 colors, works on both light and dark backgrounds, scalable from favicon to billboard",
  "temperature": 0.7,
  "n": 8
}
```

### ランディングページ用イラスト

```json
{
  "prompt": "[scene description for hero section]",
  "instructions": "Flat illustration, warm palette, no text, 16:9 aspect ratio suitable for hero banner",
  "temperature": 0.9,
  "n": 4,
  "max_output_tokens": 16384
}
```

### テクニカルダイアグラム

```json
{
  "prompt": "[diagram description: architecture, flow, etc.]",
  "instructions": "Clean technical diagram style, labeled components, arrows for flow, monochrome with accent color",
  "temperature": 0.2,
  "n": 2
}
```
