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

## Task Tool による並列起動

### シーン生成エージェント起動

```
各シーンに対して Task tool を起動:

Task:
  subagent_type: "video-scene-generator"
  run_in_background: true
  prompt: |
    以下のシーンを Remotion コンポジションとして生成してください。

    シーン情報:
    - ID: {scene.id}
    - 名前: {scene.name}
    - 時間: {scene.duration}秒
    - テンプレート: {scene.template}
    - 内容: {scene.content}

    出力先: remotion/scenes/{scene.name}.tsx

    完了したら以下を報告:
    - ファイルパス
    - 実際の duration (フレーム数)
    - 使用したコンポーネント
```

### 進捗モニタリング

```
🎬 並列生成中... (3/5 完了)

├── [Agent 1] intro ✅ (3秒)
├── [Agent 2] auth-demo ✅ (12秒)
├── [Agent 3] dashboard ⏳ 生成中...
├── [Agent 4] features 🔜 待機中
└── [Agent 5] cta 🔜 待機中
```

### 結果収集

```
TaskOutput で各エージェントの結果を収集:

結果:
  - scene_id: 1
    file: "remotion/scenes/intro.tsx"
    duration_frames: 150
    status: "success"

  - scene_id: 2
    file: "remotion/scenes/auth-demo.tsx"
    duration_frames: 450
    status: "success"
    notes: "Playwright capture included"
```

---

## シーン生成テンプレート

### intro テンプレート

```tsx
// remotion/scenes/intro.tsx
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
// remotion/scenes/ui-demo.tsx
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
// remotion/scenes/cta.tsx
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
// remotion/FullVideo.tsx
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
