# Slide Quality Check - スライド画像品質判定

Nano Banana Pro で生成したスライド画像を Claude が目視判定し、品質を保証します。

---

## 概要

`/generate-slide` の Step 4 で実行される品質判定ロジックです。
各パターン（Minimalist, Infographic, Hero Visual）の2枚を評価し、ベスト1枚を選出します。

---

## 判定フロー

```
パターンごとに2枚の画像を受け取り
    |
    +--[Step 1] 各画像を個別評価
    |   +-- スライド固有の5基準でスコアリング
    |   +-- 各基準を1-5点で評価
    |   +-- 総合スコアを算出（重み付き平均）
    |
    +--[Step 2] パターン内比較
    |   +-- 両方スコア3以上 → 高い方を採用
    |   +-- 1枚のみスコア3以上 → その1枚を採用
    |   +-- 両方スコア2以下 → 再生成へ
    |
    +--[Step 3] 再生成判定
        +-- 両方 NG → プロンプト改善して再生成（最大3回）
        +-- リトライ上限 → ユーザーに報告
```

---

## スライド固有の判定基準

### 5基準と重み

| 基準 | 重み | 説明 | 評価ポイント |
|------|------|------|-------------|
| **情報伝達力** | 高（x3） | プロジェクトの特徴が1枚で伝わるか | 何のプロジェクトか一目で理解できる、価値提案が明確 |
| **レイアウトバランス** | 高（x3） | 視覚的な完成度、余白の使い方 | 要素配置が整理されている、視線誘導が自然 |
| **テキスト可読性** | 中（x2） | AI生成テキストが読めるか | 文字化けなし、フォントサイズが適切、コントラスト十分 |
| **プロフェッショナル感** | 中（x2） | ビジネス用途に耐えるクオリティか | チープさがない、色使いが洗練、統一感がある |
| **ブランド整合性** | 低（x1） | 指定された色・トーンとの一致 | 指定トーンに沿っている、カラーが大きく外れていない |

### 総合スコア算出

```
総合スコア = (情報伝達力 x 3 + レイアウト x 3 + テキスト可読性 x 2 + プロフェッショナル感 x 2 + ブランド整合性 x 1) / 11
```

### スコア定義

| スコア | 判定 | 説明 |
|--------|------|------|
| 5 | Excellent | 完璧、即採用 |
| 4 | Good | 良好、採用可 |
| 3 | Acceptable | 許容範囲、他がなければ採用 |
| 2 | Poor | 問題あり、再生成推奨 |
| 1 | Unacceptable | 使用不可、必ず再生成 |

### 採用閾値

```
採用閾値 = 3（Acceptable 以上）
```

---

## パターン別の追加チェック

### Minimalist

| チェック項目 | 合格基準 |
|-------------|---------|
| 余白の活用 | 十分な余白があり、窮屈でない |
| タイポグラフィ | フォントが読みやすく、階層が明確 |
| シンプルさ | 要素が最小限に絞られている |

### Infographic

| チェック項目 | 合格基準 |
|-------------|---------|
| 情報の構造化 | 視覚的にセクション分けされている |
| アイコン/図の活用 | テキストだけでなく視覚要素がある |
| データの可視化 | 数値や特徴が図示されている |

### Hero Visual

| チェック項目 | 合格基準 |
|-------------|---------|
| ビジュアルインパクト | 目を引く大胆なビジュアル |
| キャッチコピー | メッセージが明確で読みやすい |
| 感情的訴求 | プロジェクトの価値を感覚的に伝えている |

---

## Claude による判定プロンプト

### 画像評価プロンプト

````text
以下のスライド画像を評価してください。

## 評価対象
- パターン: {pattern_name}（Minimalist / Infographic / Hero Visual）
- プロジェクト: {project_name}
- 概要: {project_description}
- 期待トーン: {tone}

## 評価基準（各1-5点）
1. 情報伝達力（重み: 高）— プロジェクトの特徴が1枚で伝わるか
2. レイアウトバランス（重み: 高）— 視覚的な完成度、余白の使い方
3. テキスト可読性（重み: 中）— 文字が読めるか、文字化けがないか
4. プロフェッショナル感（重み: 中）— ビジネス用途に耐えるクオリティか
5. ブランド整合性（重み: 低）— 指定された色・トーンとの一致

## 出力形式
```json
{
  "scores": {
    "information_delivery": 1-5,
    "layout_balance": 1-5,
    "text_readability": 1-5,
    "professionalism": 1-5,
    "brand_consistency": 1-5
  },
  "total_score": 1-5,
  "verdict": "OK" | "NG",
  "strengths": ["良い点1", "良い点2"],
  "issues": ["問題点1", "問題点2"],
  "improvement_suggestions": ["改善案1", "改善案2"]
}
```
````

### 2枚比較プロンプト

````text
以下の2枚のスライド画像を比較し、より適切な方を選択してください。

## 評価対象
- パターン: {pattern_name}
- プロジェクト: {project_name}

## 画像1 の評価
{image_1_evaluation}

## 画像2 の評価
{image_2_evaluation}

## 選択基準の優先順位
1. 情報伝達力（最優先）
2. プロフェッショナル感
3. レイアウトバランス

## 出力形式
```json
{
  "selected": "1" | "2",
  "reason": "選択理由",
  "comparison_notes": "比較の詳細"
}
```
````

---

## パターン内選出ロジック

### 基本ルール

```
1. 両方スコア3以上:
   → スコアが高い方を採用
   → 同スコア → 優先基準で判定:
      1. 情報伝達力が高い方
      2. プロフェッショナル感が高い方
      3. 候補1をデフォルト採用

2. 1枚のみスコア3以上:
   → スコア3以上の方を採用

3. 両方スコア2以下:
   → 再生成（プロンプト改善）
   → リトライ上限（3回）に達したら:
      → スコアが高い方を「仮採用」としてユーザーに報告
      → ユーザーが続行 or スキップを選択
```

### リトライ制御

```
max_retries = 3（パターンごと）
```

| リトライ | 改善戦略 |
|---------|---------|
| 1回目 | 初期プロンプトで生成 |
| 2回目 | 品質指摘を反映。具体的な修飾語を追加 |
| 3回目 | スタイルを大幅変更。構図指示をより具体的に |

---

## 判定結果の構造

### 個別評価結果

```json
{
  "image_id": "minimalist_1",
  "pattern": "minimalist",
  "scores": {
    "information_delivery": 4,
    "layout_balance": 5,
    "text_readability": 3,
    "professionalism": 4,
    "brand_consistency": 4
  },
  "total_score": 4.1,
  "verdict": "OK",
  "strengths": [
    "余白の使い方が優れている",
    "プロジェクト名が一目で読める"
  ],
  "issues": [
    "機能リストのテキストがやや小さい"
  ],
  "improvement_suggestions": [
    "テキストサイズを大きく、または機能数を絞る"
  ]
}
```

### パターン選出結果

```json
{
  "pattern": "minimalist",
  "candidates": [
    {"id": "minimalist_1", "total_score": 4.1, "verdict": "OK"},
    {"id": "minimalist_2", "total_score": 3.5, "verdict": "OK"}
  ],
  "selected": "minimalist_1",
  "reason": "レイアウトバランスと情報伝達力が優れている",
  "output_path": "out/slides/selected/minimalist.png"
}
```

---

## 品質レポート生成

Step 5 で `out/slides/quality-report.md` を生成:

```markdown
# Slide Quality Report

## 生成情報
- プロジェクト: {project_name}
- 生成日時: {datetime}
- アスペクト比: {aspect_ratio}
- トーン: {tone}

## 結果サマリー

| パターン | 候補1 | 候補2 | 採用 | スコア | リトライ |
|---------|-------|-------|------|--------|---------|
| Minimalist | {score}/5 | {score}/5 | 候補{n} | {score}/5 | 0回 |
| Infographic | {score}/5 | {score}/5 | 候補{n} | {score}/5 | 0回 |
| Hero Visual | {score}/5 | {score}/5 | 候補{n} | {score}/5 | 0回 |

## 詳細評価

### Minimalist

#### 候補1 (minimalist_1.png)
- 情報伝達力: {score}/5
- レイアウトバランス: {score}/5
- テキスト可読性: {score}/5
- プロフェッショナル感: {score}/5
- ブランド整合性: {score}/5
- **総合: {score}/5 — {verdict}**
- 強み: {strengths}
- 課題: {issues}

#### 候補2 (minimalist_2.png)
...

### Infographic
...

### Hero Visual
...

## 出力ファイル

| ファイル | 説明 |
|---------|------|
| `out/slides/selected/minimalist.png` | Minimalist パターン最良 |
| `out/slides/selected/infographic.png` | Infographic パターン最良 |
| `out/slides/selected/hero.png` | Hero Visual パターン最良 |
```

---

## 閾値調整

### ユーザーリクエスト対応

```
「もっと厳しく」→ 採用閾値を 4 に引き上げ
「とりあえずで」→ 採用閾値を 2 に引き下げ
「この画像でいい」→ 品質判定をスキップして採用
```

---

## 関連ドキュメント

- [slide-generator.md](./slide-generator.md) — 画像生成ロジック
- [generate-video/references/image-quality-check.md](../../generate-video/references/image-quality-check.md) — 動画用品質判定（構造の参考元）
