# Video Planner - シナリオプランナー

分析結果からシーン構成を自動提案し、ユーザーと確認・調整を行います。

---

## 概要

`/generate-video` の Step 2 で実行されるシナリオプランナーです。
analyzer.md の出力を受けて、最適なシーン構成を提案します。

> **重要**: シーン構成は [best-practices.md](best-practices.md) のファネル別ガイドラインに従って設計すること

## 入力

analyzer.md からの分析結果:
- プロジェクト情報（名前、description）
- 検出された機能リスト
- 推奨動画タイプ
- 最近の変更点

---

## ファネル別テンプレート選択

### Step 0: 目的の確認（必須）

動画の目的を確認し、適切なテンプレートを選択する。

| 目的（ファネル） | 動画タイプ | 長さ目安 | 構成の芯 |
|------------------|------------|----------|----------|
| 認知〜興味 | LP/広告ティザー | 30-90秒 | 痛み→結果→CTA |
| 興味→検討 | Introデモ | 2-3分 | 1ユースケース完走 |
| 検討→確信 | Demo/リリースノート | 2-5分 | 反論を先に潰す |
| 確信→決裁 | ウォークスルー | 5-30分 | 実運用+証拠 |
| 継続・活用 | オンボーディング | 30秒-数分 | Aha体験への最短パス |

### 90秒ティザーテンプレート

**用途**: LP/広告、認知〜興味ファネル

```
0:00-0:05 (150f)  → HookScene: 痛み or 望む結果
0:05-0:15 (300f)  → ProblemPromise: 対象ユーザーと約束
0:15-0:55 (1200f) → WorkflowDemo: 象徴ワークフロー
0:55-1:10 (450f)  → Differentiator: 差別化の根拠
1:10-1:30 (600f)  → CTA: 次の一手
```

### 3分Introデモテンプレート

**用途**: 検討向け、興味→検討ファネル

```
0:00-0:10 (300f)  → Hook: 結論+痛み
0:10-0:30 (600f)  → UseCase: ユースケース宣言
0:30-2:20 (3300f) → Demo: 実画面で完走
2:20-2:50 (900f)  → Objection: よくある不安1つ潰す
2:50-3:00 (300f)  → CTA: 行動喚起
```

### 20分ウォークスルーテンプレート

**用途**: 決裁向け、確信→決裁ファネル

```
0:00-1:00   → Intro: 対象と課題
1:00-8:00   → BasicFlow: 基本フロー
8:00-12:00  → Objections: 反論トップ2
12:00-15:00 → Security: 管理/セキュリティ
15:00-20:00 → CaseStudy+CTA: 成功事例＋CTA
```

## シーンテンプレート

### 共通シーン

| シーン | 推奨時間 | 内容 | 必須 |
|--------|----------|------|------|
| **イントロ** | 3-5秒 | ロゴ + タグライン + フェードイン | ✅ |
| **CTA** | 3-5秒 | URL + 連絡先 + フェードアウト | ✅ |

### プロダクトデモ用シーン

| シーン | 推奨時間 | 内容 |
|--------|----------|------|
| **機能紹介** | 5-10秒 | 機能名 + 1行説明 |
| **UIデモ** | 10-30秒 | Playwrightキャプチャ |
| **ハイライト** | 5-10秒 | 主要な特徴を強調 |

### アーキテクチャ解説用シーン

| シーン | 推奨時間 | 内容 |
|--------|----------|------|
| **概要図** | 5-10秒 | 全体構成のMermaid図 |
| **詳細解説** | 10-20秒 | 各コンポーネントにズーム |
| **データフロー** | 10-15秒 | シーケンス図アニメーション |

### リリースノート用シーン

| シーン | 推奨時間 | 内容 |
|--------|----------|------|
| **バージョン表示** | 3-5秒 | vX.Y.Z + リリース日 |
| **変更点リスト** | 5-15秒 | Added/Changed/Fixed のアニメーション |
| **Before/After** | 10-20秒 | UI変更のサイドバイサイド比較 |
| **新機能デモ** | 10-30秒 | 追加機能のUIデモ |

---

## シナリオ生成ロジック

### Step 1: 動画タイプ別テンプレート選択

```
推奨動画タイプに基づいてベーステンプレートを選択:
    │
    ├─ LP/広告ティザー（30-90秒）
    │   └─ Hook → ProblemPromise → WorkflowDemo → Differentiator → CTA
    │
    ├─ Introデモ（2-3分）
    │   └─ Hook → UseCase宣言 → 実画面Demo → Objection → CTA
    │
    ├─ リリースノート（1-3分）
    │   └─ Hook → バージョン → Before/After → 新機能Demo → CTA
    │
    ├─ アーキテクチャ解説（5-30分）
    │   └─ Intro → 概要図 → 詳細解説×N → データフロー → 管理/セキュリティ → CTA
    │
    └─ オンボーディング（30秒-数分）
        └─ Welcome → クイックウィン → 次のステップ
```

**重要な原則**:
- 冒頭でロゴや会社紹介を長く出さない（離脱防止）
- CTAは最後だけでなく途中にも配置
- 機能羅列ではなく「痛み→解決」のストーリー

### Step 2: 検出機能からシーンを生成

```python
# 擬似コード
for feature in detected_features:
    if feature.type == "auth":
        add_scene("認証フローデモ", duration=15, source="playwright")
    elif feature.type == "dashboard":
        add_scene("ダッシュボード紹介", duration=20, source="playwright")
    elif feature.type == "api":
        add_scene("API概要", duration=10, source="mermaid")
```

### Step 3: 時間配分の最適化

| 動画長 | 推奨用途 | シーン数目安 |
|--------|----------|-------------|
| 15秒 | SNS広告 | 3-4 |
| 30秒 | ショート動画 | 5-6 |
| 60秒 | 標準デモ | 8-10 |
| 2-3分 | 詳細解説 | 15-20 |

---

## ユーザー確認フロー

### 提案表示

```markdown
🎬 シナリオプラン

**動画タイプ**: プロダクトデモ
**合計時間**: 45秒

| # | シーン | 時間 | 内容 | ソース |
|---|--------|------|------|--------|
| 1 | イントロ | 5秒 | MyApp - タスク管理を簡単に | テンプレート |
| 2 | 認証フロー | 15秒 | ログイン画面のデモ | Playwright |
| 3 | ダッシュボード | 20秒 | メイン機能の紹介 | Playwright |
| 4 | CTA | 5秒 | myapp.com | テンプレート |

この構成でよろしいですか？
1. OK、生成開始
2. 編集したい
3. キャンセル
```

### AskUserQuestion 実装

```
AskUserQuestion:
  question: "このシナリオで動画を生成しますか？"
  header: "シナリオ確認"
  options:
    - label: "OK、生成開始"
      description: "このシーン構成で動画を生成します"
    - label: "編集したい"
      description: "シーンの追加/削除/変更を行います"
    - label: "キャンセル"
      description: "動画生成を中止します"
```

### 編集モード

ユーザーが「編集したい」を選択した場合:

```markdown
📝 シナリオ編集

以下のコマンドで編集できます：

- **追加**: 「機能Xのデモを追加」
- **削除**: 「シーン2を削除」
- **変更**: 「イントロを3秒に短縮」
- **入替**: 「シーン2と3を入れ替え」
- **完了**: 「これでOK」

何を編集しますか？
```

---

## 出力フォーマット

planner.md の出力（generator.md への入力）:

```yaml
video:
  type: "product-demo"
  total_duration: 45
  resolution: "1080p"
  fps: 30

scenes:
  - id: 1
    name: "intro"
    duration: 5
    template: "intro"
    content:
      title: "MyApp"
      tagline: "タスク管理を簡単に"
      logo: "public/logo.svg"

  - id: 2
    name: "auth-demo"
    duration: 15
    template: "ui-demo"
    source: "playwright"
    content:
      url: "http://localhost:3000/login"
      actions:
        - click: "[data-testid=email-input]"
        - type: "user@example.com"
        - click: "[data-testid=login-button]"

  - id: 3
    name: "dashboard"
    duration: 20
    template: "ui-demo"
    source: "playwright"
    content:
      url: "http://localhost:3000/dashboard"
      actions:
        - wait: 1000
        - scroll: "down"

  - id: 4
    name: "cta"
    duration: 5
    template: "cta"
    content:
      url: "https://myapp.com"
      text: "今すぐ試す"
```

---

## Notes

- シーン数が多すぎる場合は自動的に優先度の低いものを提案から除外
- ユーザーが手動でシーンを追加することも可能
- Playwrightソースのシーンはアプリが起動している必要がある
