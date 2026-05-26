# Video Generator - 並列シーン生成エンジン

シナリオに基づいて、マルチエージェントで並列にシーンを生成します。

---

## 概要

`/generate-video` の Step 3 で実行される生成エンジンです。
planner.md のシナリオを受けて、各シーンを並列で生成し、最終的に統合します。

## 入力

planner.md からのシナリオ:
- シーンリスト（id, name, duration, template, content）
- 動画設定（resolution, fps）

## 並列生成アーキテクチャ

```
シナリオ（N シーン）
    │
    ├─[素材生成フェーズ] ← NEW
    │   ├── 各シーンの素材必要判定
    │   ├── Nano Banana Pro で画像生成（2枚: 2回リクエスト）
    │   ├── Claude が品質判定
    │   └── OK → 採用 / NG → 再生成（最大3回）
    │
    ├─[並列数決定]
    │   └─ min(シーン数, 5) を並列数とする
    │
    ├─[並列生成フェーズ]
    │   ├── Agent 1: シーン 1 生成
    │   ├── Agent 2: シーン 2 生成
    │   ├── Agent 3: シーン 3 生成
    │   └── ... (max 5 並列)
    │
    ├─[統合フェーズ]
    │   ├── シーン結合
    │   ├── トランジション追加
    │   └── 音声同期（オプション）
    │
    └─[レンダリングフェーズ]
        └── 最終出力（mp4/webm/gif）
```

---

## 素材生成フェーズ（Nano Banana Pro）

シーン生成前に、必要な素材画像を自動生成します。

### 素材必要判定

| シーンタイプ | 素材必要 | 理由 |
|-------------|---------|------|
| intro | ✅ 必要 | ロゴ、タイトルカード |
| cta | ✅ 必要 | アクションバナー |
| architecture | ✅ 必要 | 概念図、ダイアグラム |
| ui-demo | ❌ 不要 | Playwright キャプチャ使用 |
| changelog | ❌ 不要 | テキストベース |

### 判定ロジック

```javascript
const needsGeneratedAsset = (scene) => {
  // 既存素材がある場合はスキップ
  if (scene.existingAssets?.length > 0) return false;

  // Playwright キャプチャ対象はスキップ
  if (scene.template === 'ui-demo') return false;

  // テキストベースシーンはスキップ
  if (scene.template === 'changelog') return false;

  // それ以外は生成対象
  return ['intro', 'cta', 'architecture', 'feature-highlight'].includes(scene.template);
};
```

### 生成フロー

```
各シーンに対して:
    │
    ├── needsGeneratedAsset(scene) = false
    │   └─ スキップ → 次のシーンへ
    │
    └── needsGeneratedAsset(scene) = true
        │
        ├── [Step 1] プロンプト生成
        │   └─ シーン情報 + ブランド情報からプロンプト構築
        │
        ├── [Step 2] 画像生成（2枚: 2回リクエスト）
        │   └─ Nano Banana Pro API 呼び出し（generateContent × 2）
        │   └─ → image-generator.md 参照
        │
        ├── [Step 3] 品質判定
        │   └─ Claude が2枚を評価・選択
        │   └─ → image-quality-check.md 参照
        │
        └── [Step 4] 結果処理
            ├── 成功 → out/assets/generated/{scene_name}.png
            └── 失敗 → 再生成（最大3回）or フォールバック
```

### 生成画像の保存先

```
out/
└── assets/
    └── generated/
        ├── intro.png
        ├── cta.png
        ├── architecture.png
        └── feature-highlight.png
```

### シーンへの組み込み

生成した画像は、シーン生成エージェントに渡されます:

```
Task:
  subagent_type: "video-scene-generator"
  prompt: |
    シーン情報:
    - 名前: intro
    - テンプレート: intro
    - 生成画像: out/assets/generated/intro.png  ← 追加

    生成画像を背景またはメイン要素として使用してください。
```

### 詳細ドキュメント

- [image-generator.md](./image-generator.md) - API 呼び出し、プロンプト設計
- [image-quality-check.md](./image-quality-check.md) - 品質判定ロジック

---

## 並列数決定ロジック

| シーン数 | 並列数 | 理由 |
|---------|--------|------|
| 1-2 | 1-2 | オーバーヘッドが利益を上回る |
| 3-4 | 3 | 最適なバランス |
| 5+ | 5 | これ以上はリソース競合 |

**実装**:
```javascript
const parallelCount = Math.min(scenes.length, 5);
```

---

## Task Tool による並列JSON生成

### 新しい生成フロー（JSON-schema駆動）

```
シナリオ（scenario.json）
    ↓
┌─────────────────────────────────────────────┐
│     Task並列起動（各シーン → JSON出力）      │
├─────────────────────────────────────────────┤
│ Agent 1 → scenes/intro.json                 │
│ Agent 2 → scenes/auth-demo.json             │
│ Agent 3 → scenes/dashboard.json             │
│ Agent 4 → scenes/features.json              │
│ Agent 5 → scenes/cta.json                   │
└─────────────────────────────────────────────┘
    ↓
┌─────────────────────────────────────────────┐
│         scenes/*.json → マージ               │
├─────────────────────────────────────────────┤
│ - section_id + order でソート               │
│ - 競合検出（同一scene_id = Critical error） │
│ - 欠落検出（セクションにシーンなし）         │
└─────────────────────────────────────────────┘
    ↓
video-script.json（全シーン統合）
    ↓
Remotion rendering
```

### シーン生成エージェント起動（JSON出力）

```
各シーンに対して Task tool を起動:

Task:
  subagent_type: "video-scene-generator"
  run_in_background: true
  prompt: |
    以下のシーンのJSONを scene.schema.json に従って生成してください。

    シーン情報:
    - scene_id: {scene.id}
    - section_id: {section.id}
    - order: {scene.order} （セクション内の順序）
    - type: {scene.type}
    - duration_ms: {scene.duration_ms}
    - content: {scene.content}

    出力先: out/video-{date}-{id}/scenes/{scene_id}.json

    必須項目:
    - scene_id, section_id, order, type, content
    - content.duration_ms（音声長 + 余白を考慮）
    - direction（transition, emphasis, background, timing）
    - assets（使用する画像・音声ファイル）

    バリデーション:
    ```bash
    node scripts/validate-scene.js out/video-{date}-{id}/scenes/{scene_id}.json
    ```

    完了報告:
    - ファイルパス
    - バリデーション結果（PASS/FAIL）
    - 警告があれば報告
```

### 進捗モニタリング

```
🎬 並列JSON生成中... (3/5 完了)

├── [Agent 1] intro.json ✅ PASS
├── [Agent 2] auth-demo.json ✅ PASS
├── [Agent 3] dashboard.json ⏳ 生成中...
├── [Agent 4] features.json 🔜 待機中
└── [Agent 5] cta.json 🔜 待機中
```

### 結果収集（JSON）

```
TaskOutput で各エージェントの結果を収集:

結果:
  - scene_id: "intro"
    file: "out/video-20260202-001/scenes/intro.json"
    validation: "PASS"
    status: "success"

  - scene_id: "auth-demo"
    file: "out/video-20260202-001/scenes/auth-demo.json"
    validation: "PASS"
    status: "success"
    warnings: ["duration_ms が音声長より短い可能性"]
```

### JSON出力仕様

**出力ファイル**: `out/video-{date}-{id}/scenes/{scene_id}.json`

**スキーマ**: `schemas/scene.schema.json`

**必須フィールド**:
```json
{
  "scene_id": "intro",
  "section_id": "opening",
  "order": 0,
  "type": "intro",
  "content": {
    "title": "MyApp",
    "subtitle": "タスク管理を簡単に",
    "duration_ms": 5000
  },
  "direction": {
    "transition": {
      "in": "fade",
      "out": "fade",
      "duration_ms": 500
    },
    "emphasis": {
      "level": "high"
    },
    "background": {
      "type": "gradient",
      "value": "linear-gradient(135deg, #667eea 0%, #764ba2 100%)"
    }
  },
  "assets": [
    {
      "type": "image",
      "source": "assets/generated/intro.png",
      "generated": true
    }
  ]
}
```

### マージフェーズ

全エージェントの完了後、`scripts/merge-scenes.js` を実行:

```bash
node scripts/merge-scenes.js out/video-20260202-001/
```

**処理内容**:
1. `scenes/*.json` を読み込み
2. `section_id` + `order` でソート
3. 競合検出（同一 `scene_id` → Critical error）
4. 欠落検出（セクションにシーンなし → Critical error）
5. `video-script.json` を生成

**出力**: `out/video-20260202-001/video-script.json`

**フォーマット**:
```json
{
  "scenes": [
    { "scene_id": "intro", "section_id": "opening", "order": 0, ... },
    { "scene_id": "hook", "section_id": "opening", "order": 1, ... },
    { "scene_id": "demo", "section_id": "main", "order": 0, ... }
  ],
  "metadata": {
    "total_duration_ms": 180000,
    "scene_count": 12,
    "generated_at": "2026-02-02T12:34:56Z"
  }
}
```

---

## シーン生成テンプレート

### intro テンプレート

```tsx
// remotion/src/scenes/intro.tsx
import { AbsoluteFill, useCurrentFrame, interpolate } from "remotion";
import { FadeIn } from "../components/FadeIn";

export const IntroScene: React.FC<{
  title: string;
  tagline: string;
}> = ({ title, tagline }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 30], [0, 1]);

  return (
    <AbsoluteFill style={{ backgroundColor: "#000", opacity }}>
      <FadeIn durationInFrames={30}>
        <h1>{title}</h1>
        <p>{tagline}</p>
      </FadeIn>
    </AbsoluteFill>
  );
};

export const DURATION = 150; // 5秒 @ 30fps
```

### ui-demo テンプレート（Playwright連携）

```tsx
// remotion/src/scenes/ui-demo.tsx
import { AbsoluteFill, Img, Sequence } from "remotion";

export const UIDemoScene: React.FC<{
  screenshots: string[];
  duration: number;
}> = ({ screenshots, duration }) => {
  const framePerScreenshot = Math.floor(duration / screenshots.length);

  return (
    <AbsoluteFill>
      {screenshots.map((src, i) => (
        <Sequence from={i * framePerScreenshot} durationInFrames={framePerScreenshot}>
          <Img src={src} style={{ width: "100%", height: "100%" }} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
```

### cta テンプレート

```tsx
// remotion/src/scenes/cta.tsx
import { AbsoluteFill, useCurrentFrame, interpolate } from "remotion";

export const CTAScene: React.FC<{
  url: string;
  text: string;
}> = ({ url, text }) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, 15], [0.8, 1], {
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill style={{ backgroundColor: "#1a1a1a" }}>
      <div style={{ transform: `scale(${scale})` }}>
        <h2>{text}</h2>
        <p>{url}</p>
      </div>
    </AbsoluteFill>
  );
};

export const DURATION = 150; // 5秒 @ 30fps
```

---

## 音声同期ルール（重要）

ナレーション付き動画を生成する際は、以下のルールを厳守すること。

### 1. 音声ファイル長さの事前確認

```bash
# 各音声ファイルの長さを確認
for f in public/audio/*.wav; do
  name=$(basename "$f" .wav)
  dur=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$f")
  frames=$(echo "$dur * 30" | bc | cut -d. -f1)
  echo "$name: ${dur}秒 = ${frames}フレーム"
done
```

### 2. シーン長さの計算式

```
シーン長さ = 1秒待機(30f) + 音声長さ + トランジション前余白(20f以上)
```

| 要素 | フレーム数 | 説明 |
|------|-----------|------|
| 1秒待機 | 30f | シーン開始後、視覚的に落ち着いてから音声開始 |
| 音声長さ | 可変 | ffprobe で事前確認 |
| 余白 | 20f以上 | トランジション開始前に音声終了 |

### 3. 音声開始タイミング

```
音声開始 = シーン開始フレーム + 30フレーム（1秒待機）
```

### 4. シーン開始フレームの計算（TransitionSeries使用時）

```
シーン開始フレーム = 前シーン開始 + 前シーン長さ - トランジション長さ
```

**例（トランジション15フレームの場合）**:
```
hook:       0
problem:    175 - 15 = 160
solution:   160 + 415 - 15 = 560
workPlan:   560 + 340 - 15 = 885
...
```

### 5. 実装テンプレート

```tsx
const SCENE_DURATIONS = {
  hook: 175,      // 30 + 121(音声) + 24(余白)
  problem: 415,   // 30 + 360(音声) + 25(余白)
  solution: 340,  // 30 + 286(音声) + 24(余白)
  // ...
};
const TRANSITION = 15;

// シーン開始フレーム（累積計算）
// hook:0, problem:160, solution:560, ...

const audioTimings = {
  hook: 30,       // シーン0 + 30
  problem: 190,   // シーン160 + 30
  solution: 590,  // シーン560 + 30
  // ...
};
```

### 6. よくある問題と対策

| 問題 | 原因 | 対策 |
|------|------|------|
| 音声が被る | 前の音声終了前に次の音声開始 | 音声長さを確認し、シーン長さを調整 |
| スライド変更と音声がずれる | TransitionSeriesのオーバーラップ未考慮 | シーン開始 = 前シーン開始 + 前シーン長 - トランジション長 |
| 音声が途中で切れる | シーン長さ < 音声長さ | シーン長さを音声長さ + 余白に調整 |
| 無音時間が長い | 音声開始が遅すぎる | シーン開始 + 30f で統一 |

---

## 統合フェーズ

### シーン結合

```tsx
// remotion/src/FullVideo.tsx
import { Composition, Series } from "remotion";
import { IntroScene } from "./scenes/intro";
import { UIDemoScene } from "./scenes/ui-demo";
import { CTAScene } from "./scenes/cta";

export const FullVideo: React.FC = () => {
  return (
    <Series>
      <Series.Sequence durationInFrames={150}>
        <IntroScene title="MyApp" tagline="タスク管理を簡単に" />
      </Series.Sequence>
      <Series.Sequence durationInFrames={450}>
        <UIDemoScene screenshots={[...]} duration={450} />
      </Series.Sequence>
      <Series.Sequence durationInFrames={150}>
        <CTAScene url="https://myapp.com" text="今すぐ試す" />
      </Series.Sequence>
    </Series>
  );
};
```

### トランジション追加

```tsx
// トランジションコンポーネント
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";

<TransitionSeries>
  <TransitionSeries.Sequence durationInFrames={150}>
    <IntroScene {...} />
  </TransitionSeries.Sequence>
  <TransitionSeries.Transition
    presentation={fade()}
    timing={linearTiming({ durationInFrames: 15 })}
  />
  <TransitionSeries.Sequence durationInFrames={450}>
    <UIDemoScene {...} />
  </TransitionSeries.Sequence>
</TransitionSeries>
```

---

## レンダリングフェーズ

### コマンド実行

```bash
# MP4 レンダリング
npx remotion render remotion/index.ts FullVideo out/video.mp4

# GIF レンダリング（短い動画向け）
npx remotion render remotion/index.ts FullVideo out/video.gif

# WebM レンダリング（Web向け）
npx remotion render remotion/index.ts FullVideo out/video.webm --codec=vp8
```

### 出力オプション

| フォーマット | 推奨用途 | オプション |
|-------------|---------|-----------|
| MP4 | 汎用、SNS | `--codec=h264` |
| WebM | Web埋め込み | `--codec=vp8` |
| GIF | 短いループ | 15秒以下推奨 |

---

## 完了報告

```markdown
✅ **動画生成完了**

📁 **出力ファイル**:
- `out/video.mp4` (45秒, 1080p, 12.3MB)

📊 **生成統計**:
| 項目 | 値 |
|------|-----|
| シーン数 | 4 |
| 並列エージェント数 | 3 |
| 生成時間 | 45秒 |
| レンダリング時間 | 30秒 |

🎬 **プレビュー**:
- Studio: `npm run remotion` → http://localhost:3000
- ファイル: `open out/video.mp4`
```

---

## エラーハンドリング

### シーン生成失敗

```
⚠️ シーン生成エラー

シーン「auth-demo」の生成に失敗しました。
原因: Playwright キャプチャ失敗 - アプリが起動していません

対処:
1. アプリを起動してください: `npm run dev`
2. 再生成: 「auth-demo を再生成」
3. スキップ: 「このシーンをスキップ」
```

### レンダリング失敗

```
⚠️ レンダリングエラー

原因: メモリ不足

対処:
1. 並列数を減らす: `--concurrency 2`
2. 解像度を下げる: 720p で再試行
3. シーンを分割: 長いシーンを短く分割
```

---

## BGM サポート

### 実装方法

コンポジションに `bgmPath` と `bgmVolume` プロパティを追加:

```tsx
export const VideoComposition: React.FC<{
  enableAudio?: boolean;
  volume?: number;
  bgmPath?: string;      // BGMファイルパス（staticFile相対）
  bgmVolume?: number;    // BGM音量（0.0-1.0）
}> = ({ enableAudio = true, volume = 1, bgmPath, bgmVolume = 0.25 }) => {
  return (
    <AbsoluteFill>
      {/* シーン内容 */}

      {/* BGM（ナレーションより控えめに） */}
      {enableAudio && bgmPath && (
        <Audio src={staticFile(bgmPath)} volume={bgmVolume} />
      )}
    </AbsoluteFill>
  );
};
```

### BGM 音量ガイドライン

| ナレーション有無 | 推奨 bgmVolume |
|-----------------|----------------|
| あり | 0.20 - 0.30 |
| なし | 0.50 - 0.80 |

### 著作権フリー BGM 入手先

- [DOVA-SYNDROME](https://dova-s.jp/) - 日本語、無料
- [甘茶の音楽工房](https://amachamusic.chagasi.com/) - 日本語、無料
- [Pixabay Music](https://pixabay.com/music/) - 英語、無料

---

## 字幕サポート

### 実装方法

```tsx
// フォント埋め込み（Base64推奨）
const FontStyle: React.FC = () => (
  <style>
    {`
      @font-face {
        font-family: 'CustomFont';
        src: url('${FONT_DATA_URL}') format('opentype');
        font-weight: normal;
        font-style: normal;
      }
    `}
  </style>
);

// 字幕コンポーネント
const Subtitle: React.FC<{ text: string }> = ({ text }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 10], [0, 1], {
    extrapolateRight: "clamp",
  });

  return (
    <>
      <FontStyle />
      <div
        style={{
          position: "absolute",
          bottom: 80,
          left: 0,
          right: 0,
          display: "flex",
          justifyContent: "center",
          padding: "0 60px",
        }}
      >
        <div
          style={{
            fontFamily: "'CustomFont', sans-serif",
            fontSize: 32,
            color: "#FFFFFF",
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: "14px 28px",
            borderRadius: 8,
            textAlign: "center",
            maxWidth: 1000,
            lineHeight: 1.5,
            opacity,
          }}
        >
          {text}
        </div>
      </div>
    </>
  );
};
```

### 字幕タイミングルール

| 項目 | 値 |
|------|-----|
| 字幕開始 | 音声開始と同じタイミング |
| 字幕duration | 音声長 + 10f（余白） |

### フォント埋め込み（Base64）

カスタムフォントを確実に読み込むには Base64 埋め込みを使用:

```typescript
// src/utils/custom-font.ts
import fs from "fs";
import path from "path";

// ビルド時にBase64エンコード
const fontPath = path.join(__dirname, "../../public/font/MyFont.otf");
const fontBuffer = fs.readFileSync(fontPath);
export const FONT_DATA_URL = `data:font/otf;base64,${fontBuffer.toString("base64")}`;
```

### 字幕データ構造

```tsx
const SUBTITLES = [
  { id: "hook", text: "字幕テキスト", start: 30, duration: 120 },
  { id: "problem", text: "次の字幕", start: 175, duration: 178 },
  // ...
];

// 使用
{SUBTITLES.map((sub) => (
  <Sequence key={sub.id} from={sub.start} durationInFrames={sub.duration}>
    <Subtitle text={sub.text} />
  </Sequence>
))}
```

---

## Notes

- 並列生成は独立したシーンに対してのみ有効
- Playwright キャプチャは事前にアプリが起動している必要がある
- 大きな動画（3分以上）は分割レンダリングを推奨
- BGMはナレーションが聞こえるよう控えめに設定
- カスタムフォントはBase64埋め込みで確実に読み込む

---

## Phase 10: 将来拡張（キャラクター対話動画）

### 概要

現在の動画生成は**単一ナレーション**形式ですが、将来的に以下のような**キャラクター対話動画**に拡張可能な設計にします：

| 現在 | Phase 10 拡張後 |
|------|----------------|
| 単一ナレーター | 複数キャラクターの対話 |
| 静的スライド + 音声 | キャラクター表示 + 対話演出 |
| TTS: 1音声のみ | TTS: キャラクター別音声 |

### ユースケース例

```
[導入動画の例]

Narrator:  「今日は新機能を紹介します」
User:      「これは何ができるの？」
AI Guide:  「簡単に説明しましょう」
```

```
[技術解説動画の例]

Interviewer: 「このアーキテクチャの特徴は？」
Expert:      「スケーラビリティを重視しています」
Reviewer:    「具体的な数値を見てみましょう」
```

### 拡張ポイント（設計のみ）

#### 1. Character 定義（`schemas/character.schema.json`）

**既に実装済み**のスキーマで、以下を定義：

```json
{
  "character_id": "narrator",
  "name": "ナレーター",
  "role": "narrator",
  "voice": {
    "provider": "google-cloud-tts",
    "voice_id": "ja-JP-Neural2-B",
    "language": "ja",
    "speed": 1.1,
    "style": "professional"
  },
  "appearance": {
    "type": "avatar",
    "position": "left"
  }
}
```

**拡張項目**:
- `voice`: TTS設定（プロバイダー、音声ID、スピード、スタイル）
- `appearance`: ビジュアル設定（アバター、アイコン、位置）
- `dialogue_style`: 対話演出（吹き出しスタイル、アニメーション）
- `personality`: 性格特性（将来のAI対話生成用）

#### 2. Dialogue シーン定義（将来仕様）

**dialogue.json** の構造（実装は Phase 10 以降）:

```json
{
  "scene_id": "intro-dialogue",
  "type": "dialogue",
  "content": {
    "duration_ms": 15000,
    "exchanges": [
      {
        "character_id": "user",
        "text": "この機能は何ができますか？",
        "timing_ms": 0,
        "duration_ms": 3000,
        "emotion": "curious"
      },
      {
        "character_id": "guide",
        "text": "簡単に説明します。まず...",
        "timing_ms": 3500,
        "duration_ms": 5000,
        "emotion": "friendly"
      },
      {
        "character_id": "narrator",
        "text": "実際の画面を見てみましょう",
        "timing_ms": 9000,
        "duration_ms": 3000,
        "emotion": "neutral"
      }
    ]
  },
  "characters": [
    {
      "$ref": "characters/user.json"
    },
    {
      "$ref": "characters/guide.json"
    },
    {
      "$ref": "characters/narrator.json"
    }
  ],
  "direction": {
    "layout": "split-screen",
    "transition_between_speakers": "highlight"
  }
}
```

#### 3. TTS 連携の拡張方法

**現在（単一音声）**:
```javascript
// 1つの音声ファイルを再生
<Audio src={staticFile('narration.wav')} />
```

**Phase 10 拡張後（キャラクター別音声）**:
```javascript
// キャラクター別にTTS呼び出し
async function generateDialogue(exchanges, characters) {
  const audioFiles = await Promise.all(
    exchanges.map(async (exchange) => {
      const character = characters.find(c => c.character_id === exchange.character_id);

      // TTS APIを呼び出し（プロバイダーに応じて分岐）
      const audioBuffer = await ttsProvider.synthesize({
        text: exchange.text,
        voiceId: character.voice.voice_id,
        speed: character.voice.speed,
        emotion: exchange.emotion,
      });

      return {
        character_id: exchange.character_id,
        audio: audioBuffer,
        timing_ms: exchange.timing_ms,
        duration_ms: exchange.duration_ms,
      };
    })
  );

  return audioFiles;
}
```

**TTS プロバイダー連携**:

| プロバイダー | API 呼び出し例 |
|-------------|---------------|
| Google Cloud TTS | `textToSpeech.synthesizeSpeech({ voice, input })` |
| ElevenLabs | `elevenlabs.textToSpeech({ voiceId, text })` |
| OpenAI TTS | `openai.audio.speech.create({ voice, input })` |
| AWS Polly | `polly.synthesizeSpeech({ VoiceId, Text })` |

#### 4. ビジュアル演出の拡張

**キャラクター表示（Remotion コンポーネント例）**:

```tsx
// 将来実装: DialogueScene.tsx
const DialogueScene: React.FC<{
  exchanges: Exchange[];
  characters: Character[];
}> = ({ exchanges, characters }) => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill>
      {/* 背景 */}
      <Background />

      {/* キャラクター表示 */}
      <CharacterDisplay
        characters={characters}
        activeCharacterId={getCurrentSpeaker(frame, exchanges)}
      />

      {/* 対話テキスト（吹き出し） */}
      <DialogueBubble
        exchange={getCurrentExchange(frame, exchanges)}
      />

      {/* 音声再生 */}
      {exchanges.map((ex, i) => (
        <Sequence from={ex.timing_ms / 33.33} durationInFrames={ex.duration_ms / 33.33}>
          <Audio src={staticFile(`dialogue/${ex.character_id}_${i}.wav`)} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
```

**アニメーション例**:
- 話している キャラクターをハイライト
- 話していないキャラクターは半透明
- 吹き出しがフェードイン/アウト
- キャラクターアバターが口パク（オプション）

#### 5. 実装ロードマップ（Phase 10 以降）

| Phase | 実装内容 | 優先度 |
|-------|---------|--------|
| **Phase 10.1** | `character.schema.json` 実装 | ✅ 完了 |
| **Phase 10.2** | TTS プロバイダー連携（Google Cloud TTS） | High |
| **Phase 10.3** | `DialogueScene` Remotion コンポーネント | High |
| **Phase 10.4** | `dialogue.json` スキーマ定義 | Medium |
| **Phase 10.5** | キャラクター表示 UI（アバター/アイコン） | Medium |
| **Phase 10.6** | 吹き出しアニメーション | Low |
| **Phase 10.7** | 複数 TTS プロバイダー対応（ElevenLabs, OpenAI） | Low |
| **Phase 10.8** | AI 対話生成（personality に基づく自動生成） | Future |

#### 6. 互換性の維持

拡張は**後方互換性を保つ**設計：

```
既存の video-script.json（単一ナレーション）
    ↓ そのまま動作
新しい dialogue.json（対話形式）
    ↓ 新しいシーンタイプとして追加
両方が共存可能
```

**scene.schema.json への追加**:
```json
{
  "type": {
    "enum": [
      "intro",
      "ui-demo",
      "dialogue",  // ← Phase 10 で追加
      "..."
    ]
  }
}
```

#### 7. 参考実装

既存プロジェクトの例:
- **Manim Community**: キャラクターアニメーション
- **Remotion Templates**: 対話形式テンプレート
- **Google Cloud TTS**: 多言語・多音声対応

---

### Phase 10 実装時のチェックリスト

将来実装する際は以下を確認：

- [ ] `character.schema.json` が有効（既に Phase 10.1 で完了）
- [ ] TTS API キーが設定済み（Google Cloud TTS 推奨）
- [ ] `dialogue.json` スキーマを定義
- [ ] `DialogueScene.tsx` Remotion コンポーネント実装
- [ ] キャラクター音声ファイルの命名規則統一
- [ ] 吹き出しスタイルのブランド一貫性
- [ ] 既存シーン（intro, ui-demo 等）との共存テスト
- [ ] パフォーマンス: 複数音声の同時レンダリング最適化

---

### まとめ（Phase 10）

**現状**: 単一ナレーション動画に対応
**Phase 10 設計**: キャラクター対話動画への拡張ポイントを明確化
**実装済み**: `character.schema.json`（キャラクター定義）
**未実装**: TTS連携、対話シーン、ビジュアル演出（将来実装）

この設計により、将来的に以下が可能になります：
- 複数キャラクターの対話形式動画
- キャラクター別の音声スタイル
- 視覚的なキャラクター表示と対話演出
- AI による対話生成（personality 設定に基づく）
