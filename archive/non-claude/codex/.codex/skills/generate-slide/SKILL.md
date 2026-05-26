---
name: generate-slide
description: "Generate project intro slides with Nano Banana Pro. Internal/manual workflow only; use from an explicit /generate-slide command or a parent media workflow."
description-ja: "Nano Banana Proでプロジェクト紹介スライドを自動生成。明示的な /generate-slide または親メディアワークフローからのみ使う。通常発話からの自動起動はしない。"
description-en: "Generate project intro slides with Nano Banana Pro. Internal/manual workflow only; use from an explicit /generate-slide command or a parent media workflow."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Glob", "Grep", "AskUserQuestion"]
disable-model-invocation: true
user-invocable: false
argument-hint: "[project-path|description]"
---

# Generate Slide Skill

プロジェクトの内容を紹介・説明する1枚スライド画像を、Nano Banana Pro（Gemini 3 Pro Image Preview）API で自動生成します。

## 起動契約

このスキルは `user-invocable: false` かつ `disable-model-invocation: true` です。
通常のユーザー発話（例: 「スライド作って」）から Claude が自動選択する前提ではありません。

- 明示的な `/generate-slide` コマンド、または親メディアワークフローから内部的に起動される時だけ使います。
- `allowed-tools` は Claude Code 用です。Claude ではユーザー確認に `AskUserQuestion` を使えます。
- Codex mirror では同等の確認は `request_user_input` 相当の計画モード入力に読み替えます。通常実行でそのツールがない場合は、既定値を提示して停止せず進め、重要な未確定事項だけユーザーへ確認します。
- `disable-model-invocation: true` は「説明文だけを見てモデルが勝手に起動しない」という意味です。slash や親 workflow から明示起動された場合は本文手順に従います。

---

## 概要

3パターン x 各2枚候補 = 計6枚生成 → パターンごとに品質チェック → NG ならリトライ → 各パターンの最良1枚、計3枚を出力。

## 前提条件

- `GOOGLE_AI_API_KEY` 環境変数が設定済み
- Google AI Studio で Nano Banana Pro（Gemini 3 Pro Image Preview）が有効化済み

## 機能詳細

| 機能 | 詳細 |
|------|------|
| **スライド画像生成** | See [references/slide-generator.md](${CLAUDE_SKILL_DIR}/references/slide-generator.md) |
| **品質判定** | See [references/slide-quality-check.md](${CLAUDE_SKILL_DIR}/references/slide-quality-check.md) |

---

## 実行フロー

```
/generate-slide
    |
    +--[Step 1] 情報収集
    |   +-- ユーザー指定テキスト or コードベース自動分析（README, package.json 等）
    |   +-- プロジェクト名・概要・主要機能・技術スタックを抽出
    |
    +--[Step 2] 仕様確認（AskUserQuestion）
    |   +-- サイズ・アスペクト比（デフォルト: 16:9 / 2K）
    |   +-- トーン（テック、カジュアル、コーポレート等）
    |   +-- 強調したいポイント（曖昧な場合のみ質問）
    |
    +--[Step 3] 3パターン x 2枚生成（Nano Banana Pro API x 6回）
    |   +-- Pattern A: Minimalist（2枚）
    |   +-- Pattern B: Infographic（2枚）
    |   +-- Pattern C: Hero Visual（2枚）
    |
    +--[Step 4] パターンごとに品質チェック
    |   +-- 各パターンの2枚を Claude が Read で読み込み
    |   +-- 5段階スコアリング → 高い方を採用候補
    |   +-- 両方スコア2以下 → プロンプト改善してリトライ（最大3回）
    |   +-- リトライ上限到達 → ユーザーに報告、続行 or スキップを選択
    |
    +--[Step 5] 最良3枚を出力
        +-- 各パターンのベスト1枚を selected/ にコピー
        +-- 結果一覧（パス + スコア + 評価コメント）をユーザーに提示
```

---

## デザインパターン

| パターン | コンセプト | 特徴 |
|---------|-----------|------|
| **Minimalist** | 余白とタイポグラフィ主体 | clean, whitespace, typography-driven, elegant |
| **Infographic** | データ/フロー可視化 | data visualization, metrics, flow diagram, structured |
| **Hero Visual** | 大ビジュアル + キャッチコピー | bold visual, impactful, hero image, catchy headline |

---

## 出力先

```
out/slides/
+-- minimalist_1.png       # Pattern A 候補1
+-- minimalist_2.png       # Pattern A 候補2
+-- infographic_1.png      # Pattern B 候補1
+-- infographic_2.png      # Pattern B 候補2
+-- hero_1.png             # Pattern C 候補1
+-- hero_2.png             # Pattern C 候補2
+-- selected/
|   +-- minimalist.png     # Pattern A 最良
|   +-- infographic.png    # Pattern B 最良
|   +-- hero.png           # Pattern C 最良
+-- quality-report.md      # 品質チェック結果レポート
```

---

## 実行手順

### Step 1: 情報収集

プロジェクト情報を以下の優先順位で収集:

1. **ユーザー指定テキスト**: 引数でプロジェクト説明が渡された場合はそれを使用
2. **コードベース自動分析**: 引数がない場合、以下を自動分析
   - `README.md` — プロジェクト概要
   - `package.json` / `Cargo.toml` / `pyproject.toml` — プロジェクト名・説明・依存関係
   - `CLAUDE.md` — プロジェクト構成・目的
   - `Plans.md` — 進行中のタスク（存在する場合）

抽出する情報:

| 項目 | 例 |
|------|-----|
| プロジェクト名 | Claude Code Harness |
| 概要（1-2文） | Claude Code を Plan-Work-Review で自律運用するプラグイン |
| 主要機能（3-5個） | スキル管理、品質チェック、並列実行 |
| 技術スタック | TypeScript, Node.js, Claude Code Plugin |
| カラー（あれば） | ブランドカラー or 推測 |

### Step 2: 仕様確認

AskUserQuestion で以下を確認（デフォルト値があるため、曖昧な場合のみ質問）:

```
質問1: スライドのサイズ・アスペクト比は？
  - 16:9 / 2K（推奨）
  - 4:3 / 2K
  - 1:1 / 2K
  - カスタム

質問2: トーンは？
  - テック（ダークテーマ、コード感）
  - カジュアル（明るい、フレンドリー）
  - コーポレート（フォーマル、信頼感）
  - クリエイティブ（大胆、アート寄り）
```

### Step 3: 画像生成

`slide-generator.md` の手順に従い、3パターン x 2枚 = 6枚を生成。

各パターンの生成は独立しているため、可能な限り並列で curl を実行:

```bash
# 並列実行例（3パターン x 2枚）
for pattern in minimalist infographic hero; do
  for i in 1 2; do
    # slide-generator.md の curl パターンを実行
    # → out/slides/${pattern}_${i}.png に保存
  done
done
```

### Step 4: 品質チェック

`slide-quality-check.md` の基準に従い、各パターンの2枚を評価:

1. 各画像を Read で読み込み
2. 5段階スコアリング（情報伝達力、レイアウト、テキスト可読性、プロフェッショナル感、ブランド整合性）
3. パターン内でスコアが高い方を採用候補
4. 両方スコア2以下 → プロンプト改善して再生成（最大3回）

### Step 5: 結果出力

```bash
# 最良画像を selected/ にコピー
mkdir -p out/slides/selected
cp out/slides/minimalist_best.png out/slides/selected/minimalist.png
cp out/slides/infographic_best.png out/slides/selected/infographic.png
cp out/slides/hero_best.png out/slides/selected/hero.png
```

品質レポート（`out/slides/quality-report.md`）を生成:

```markdown
# Slide Quality Report

## 生成情報
- プロジェクト: {project_name}
- 生成日時: {datetime}
- アスペクト比: {aspect_ratio}
- トーン: {tone}

## 結果サマリー

| パターン | 候補1 | 候補2 | 採用 | スコア |
|---------|-------|-------|------|--------|
| Minimalist | 3/5 | 4/5 | 候補2 | 4/5 |
| Infographic | 4/5 | 3/5 | 候補1 | 4/5 |
| Hero Visual | 5/5 | 4/5 | 候補1 | 5/5 |

## 詳細評価
...
```

---

## エラーハンドリング

### GOOGLE_AI_API_KEY 未設定

```
GOOGLE_AI_API_KEY が設定されていません。

設定方法:
1. Google AI Studio でAPIキーを取得: https://ai.google.dev/aistudio
2. export GOOGLE_AI_API_KEY="your-api-key"
```

### 全パターンでリトライ上限到達

AskUserQuestion で選択肢を提示:

```
パターン {pattern} の画像が3回のリトライでも基準を満たしませんでした。

選択肢:
1. 最も高スコアの画像を採用して続行
2. このパターンをスキップ
3. プロンプトを手動で指定して再生成
```

---

## 関連スキル

- `generate-video` — プロダクトデモ動画生成（画像生成エンジンを共有）
- `notebookLM` — ドキュメント・スライド生成（別アプローチ）
