---
description: Remotion動画生成環境をセットアップ
---

# /remotion-setup - Remotion セットアップ

Remotionによるプログラマティック動画生成環境をセットアップします。

## VibeCoder Quick Reference

- "**動画を作りたい**" → このコマンド
- "**プロダクト紹介動画**" → まずこのセットアップ
- "**Remotion使いたい**" → このコマンド

## Deliverables

- `remotion/` - Remotionプロジェクトディレクトリ
- Remotion Agent Skills（Claude Code連携）
- Harness用テンプレート（オプション）

---

## Prerequisites

- Node.js 18+
- pnpm / npm / yarn
- 十分なディスク容量（約500MB）

---

## Usage

```bash
/remotion-setup                    # 基本セットアップ
/remotion-setup --with-templates   # Harnessテンプレート付き
/remotion-setup --brownfield       # 既存プロジェクトに追加
/remotion-setup --with-narration   # ナレーション機能付き
/remotion-setup --with-image-gen   # AI画像生成機能付き
```

---

## Execution Flow

### Step 1: 環境確認

```bash
# Node.js バージョン確認
node --version  # 18.0.0 以上必須

# パッケージマネージャー確認
which pnpm || which npm
```

### Step 2: セットアップ方式の確認

> 🎬 **Remotion セットアップ**
>
> セットアップ方式を選択してください：
>
> 1. **新規プロジェクト** - `remotion/` ディレクトリを作成
> 2. **既存プロジェクトに追加** - 現在のプロジェクトに統合
>
> どちらを選択しますか？

**AskUserQuestion で確認**

### Step 3a: 新規プロジェクト作成

```bash
# Remotionプロジェクト作成
npx create-video@latest remotion

# 推奨設定:
# - Template: Empty
# - TailwindCSS: Yes
# - Skills: Yes
```

### Step 3b: 既存プロジェクトに追加（Brownfield）

```bash
# 必要なパッケージをインストール
npm install remotion @remotion/cli @remotion/player

# オプション: レンダリング用
npm install @remotion/renderer

# オプション: Lambda用
npm install @remotion/lambda
```

**フォルダ構成を作成**:

```
remotion/
├── Composition.tsx    # メインコンポジション
├── Root.tsx           # Remotionルート
└── index.ts           # エントリーポイント
```

### Step 4: Agent Skills インストール

```bash
# Remotion Skills をインストール
npx skills add remotion-dev/skills
```

**確認**:
```bash
# スキルが追加されたか確認
ls .claude/skills/remotion/ 2>/dev/null || echo "Skills installed in global location"
```

### Step 5: Harnessテンプレート追加（オプション）

> 🎨 **Harnessテンプレートを追加しますか？**
>
> 以下のテンプレートが利用可能です：
> - 共有コンポーネント（FadeIn, SlideUp, TextReveal）
> - ブランドアセット（COLORS, FONTS）
> - プリセット（1080p, vertical, square）
>
> 追加しますか？ (y/n)

**「y」の場合**:

```bash
# プラグインからテンプレートをコピー
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname $0))}"
cp -r "$PLUGIN_DIR/templates/remotion/"* remotion/
```

### Step 6: ナレーション機能追加（オプション）

> 🎙️ **ナレーション機能を追加しますか？**
>
> Aivis Cloud API を使用して、動画にAI音声ナレーションを追加できます。
>
> **必要なもの**:
> - Aivis Cloud API キー（[ダッシュボード](https://hub.aivis-project.com/cloud-api/dashboard)で取得）
> - 商用利用可能なモデル（ACML 1.0ライセンス）
>
> 追加しますか？ (y/n)

**「y」の場合**:

```bash
# 環境変数を設定
export AIVIS_API_KEY=aivis_xxxxxx

# 必要なファイルを作成
mkdir -p remotion/src/utils remotion/src/hooks remotion/src/components remotion/public/audio
```

**作成するファイル**:

| ファイル | 用途 |
|---------|------|
| `src/utils/aivis-client.ts` | Aivis Cloud API クライアント |
| `src/utils/narration-generator.ts` | ナレーション生成ロジック |
| `src/hooks/useNarration.ts` | ナレーション状態管理 |
| `src/components/NarratedScene.tsx` | 音声付きシーンラッパー |

> 詳細: [aivis-narration.md](.claude/skills/video/references/aivis-narration.md)

### Step 6.5: AI画像生成機能追加（オプション）

> 🎨 **AI画像生成機能を追加しますか？**
>
> Nano Banana Pro（Google DeepMind）を使用して、動画シーン用の高品質画像を自動生成できます。
>
> **必要なもの**:
> - Google AI Studio API キー（[AI Studio](https://ai.google.dev/aistudio)で取得）
> - Gemini API の課金設定
>
> **機能**:
> - イントロ、CTA、概念図などの画像を自動生成
> - 2枚生成 → Claude が品質判定 → 最適なものを採用
> - 品質が低い場合は自動で再生成（最大3回）
>
> 追加しますか？ (y/n)

**「y」の場合**:

```bash
# 環境変数を設定
export GOOGLE_AI_API_KEY="your-api-key"

# または .env.local に追加
echo 'GOOGLE_AI_API_KEY=your-api-key' >> .env.local

# 出力ディレクトリを作成
mkdir -p out/assets/generated
```

**確認**:
```bash
# API キーが設定されているか確認
echo $GOOGLE_AI_API_KEY | head -c 10
# AIzaSy... のように表示されれば OK
```

> 詳細: [image-generator.md](skills/video/references/image-generator.md)

### Step 7: package.json スクリプト追加

```json
{
  "scripts": {
    "remotion": "remotion studio remotion/index.ts",
    "render": "remotion render remotion/index.ts Main out/video.mp4",
    "render:gif": "remotion render remotion/index.ts Main out/video.gif",
    "generate-narration": "npx ts-node src/utils/narration-generator.ts"
  }
}
```

### Step 8: 完了メッセージ

> ✅ **Remotion セットアップ完了**
>
> 📁 **作成されたファイル**:
> - `remotion/` - Remotionプロジェクト
> - `.claude/skills/remotion/` - Agent Skills
> - `src/utils/aivis-client.ts` - ナレーション用（オプション）
>
> **使い方**:
> ```bash
> # Studio を起動（プレビュー）
> npm run remotion
>
> # 動画をレンダリング
> npm run render
>
> # ナレーション生成（オプション）
> AIVIS_API_KEY=your_key npm run generate-narration
>
> # Claude Code で動画を作成
> claude
> > "イントロ動画を作って"
> ```
>
> **次のステップ**:
> - `/generate-video` で自動動画生成
> - Studio で手動編集: http://localhost:3000
>
> **ドキュメント**: https://www.remotion.dev/docs

---

## Troubleshooting

### "Cannot find module 'remotion'"

```bash
# 依存関係を再インストール
rm -rf node_modules && npm install
```

### "Skills not found"

```bash
# グローバルにインストールされている可能性
npx skills list
```

### レンダリングが遅い

```bash
# 並列レンダリングを有効化
npx remotion render --concurrency 4
```

---

## License Notice

> ⚠️ **Remotion ライセンス**
>
> Remotionは企業利用時に有料ライセンスが必要な場合があります。
> 詳細: https://www.remotion.dev/license
>
> 個人・OSS利用は無料です。

> ⚠️ **Aivis Cloud API ライセンス（ナレーション機能使用時）**
>
> 商用利用には ACML 1.0 ライセンスのモデルを使用してください。
> - コハク、まい、にせ、fumifumi 等
> - 詳細: [AivisHub](https://hub.aivis-project.com/search)
>
> 料金: 従量課金（440円/10,000文字）または月額サブスク（1,980円/月）

---

## Related Commands

- `/generate-video` - 動画自動生成
- `/mcp-setup` - MCP サーバーセットアップ

---

## Technical References

- [Remotion公式: Claude Code連携](https://www.remotion.dev/docs/ai/claude-code)
- [Remotion Agent Skills](https://www.remotion.dev/docs/ai/skills)
- [Brownfield Integration](https://www.remotion.dev/docs/brownfield)
- [Launchpad テンプレート参考](https://github.com/trycua/launchpad)
