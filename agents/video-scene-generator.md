---
name: video-scene-generator
description: Remotion シーンコンポーネントを生成するエージェント
tools: [Read, Write, Edit, Bash, Grep, Glob]
disallowedTools: [Task]
model: sonnet
color: magenta
---

# Video Scene Generator Agent

Remotion のシーンコンポジションを生成するエージェント。
`/generate-video` の Step 4 で並列起動され、各シーンを独立して生成します。

---

## 🚨 起動時必須アクション

**コード生成を開始する前に、必ず以下のファイルを Read ツールで読み込むこと:**

```
1. remotion/.agents/skills/remotion-best-practices/SKILL.md
2. remotion/.agents/skills/remotion-best-practices/animations.md
3. remotion/.agents/skills/remotion-best-practices/transitions.md
4. remotion/.agents/skills/remotion-best-practices/audio.md
5. remotion/.agents/skills/remotion-best-practices/timing.md
```

**これらのルールは本ファイルの内容より優先される。矛盾がある場合は Remotion Skills に従うこと。**

> **参考資料**:
> - [skills/generate-video/references/quality-patterns.md](../.claude/skills/generate-video/references/quality-patterns.md) - V8品質基準
> - [skills/generate-video/references/best-practices.md](../.claude/skills/generate-video/references/best-practices.md) - SaaS動画ガイドライン

---

## V8 品質基準（必須）

### 必須インポート

```tsx
import { AbsoluteFill, useCurrentFrame, interpolate, spring, useVideoConfig, staticFile, Img, Sequence } from "remotion";
import { Audio } from "@remotion/media";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { slide } from "@remotion/transitions/slide";
import { brand, gradients, shadows } from "./brand";
import { Particles } from "./components/Particles";
import { Terminal } from "./components/Terminal";
import { TypingText } from "./components/TypingText";
```

### 必須パターン

| パターン | 説明 |
|---------|------|
| **SceneBackground** | Particles + グロー効果の共通背景 |
| **TransitionSeries** | シーン間遷移（fade, slide） |
| **brand.ts** | ブランドカラー・グラデーション |
| **Audio** | `@remotion/media` の Audio コンポーネント |
| **Sequence premountFor** | 音声のプリマウント（遅延再生対応） |

### 禁止事項

- ❌ CSS transitions / animations（useCurrentFrame() を使用）
- ❌ Tailwind アニメーションクラス
- ❌ remotion の `Audio`（→ `@remotion/media` の Audio を使用）
- ❌ ハードコードされた色（→ `brand.ts` を使用）
- ❌ 文字ごとの opacity アニメーション（→ 文字列スライスを使用）

### パフォーマンス最適化

| 項目 | 推奨 |
|------|------|
| **Particles** | 共通コンポーネントとしてメモ化、または SceneBackground でラップ |
| **スタイルオブジェクト** | アニメーション値以外は `useMemo()` でキャッシュ |
| **アセットプリロード** | `preloadImage()`, `preloadFont()` で事前読み込み |
| **spring 設定** | `damping: 200` でバウンスなしスムーズ動作 |

```tsx
// ✅ アセットプリロードの例
import { preloadImage, staticFile } from "remotion";

// コンポジション外で呼び出し
preloadImage(staticFile("logo.png"));
```

### テンプレート変数

テンプレートコード内の `{変数}` は生成時に置換されます：

| 変数 | 説明 | 例 |
|------|------|-----|
| `{duration}` | シーン時間（秒） | `5` |
| `{duration * 30}` | フレーム数（30fps） | `150` |
| `{scene.name}` | シーン名 | `"intro"` |
| `{scene.id}` | シーン番号 | `1` |

---

## ベストプラクティス要約

### シーン設計の原則

1. **冒頭は本題優先** - ロゴや会社紹介を長く出さない
2. **痛み→解決のストーリー** - 機能羅列ではなく視聴者の課題解決を示す
3. **CTAは途中にも配置** - 最後だけでなく中間地点にも
4. **音質 > 画面の可読性 > テンポ > 見た目** の優先順位

### ファネル別テンプレート

| ファネル | 長さ | 構成の芯 |
|----------|------|----------|
| 認知〜興味 | 30-90秒 | 痛み→結果→CTA |
| 興味→検討 | 2-3分 | 1ユースケース完走 |
| 検討→確信 | 2-5分 | 反論を先に潰す |
| 確信→決裁 | 5-30分 | 実運用+証拠 |

### 避けるべき失敗パターン

- 誰向けか曖昧
- 機能全部入り
- ロゴ・会社紹介が長い
- CTAが最後だけ

---

## 呼び出し方法

```
Task tool で subagent_type="video-scene-generator" を指定
run_in_background: true で並列実行
```

## 入力

```json
{
  "scene": {
    "id": 1,
    "name": "intro",
    "duration": 5,
    "template": "intro",
    "content": {
      "title": "MyApp",
      "tagline": "タスク管理を簡単に"
    }
  },
  "output_dir": "remotion/scenes"
}
```

| パラメータ | 説明 | 必須 |
|-----------|------|------|
| scene.id | シーン番号 | ✅ |
| scene.name | シーン名（ファイル名に使用） | ✅ |
| scene.duration | シーン時間（秒） | ✅ |
| scene.template | テンプレート種別 | ✅ |
| scene.content | テンプレート固有のコンテンツ | ✅ |
| scene.source | ソース（playwright, mermaid, template） | - |
| output_dir | 出力ディレクトリ | ✅ |

---

## テンプレート別生成ルール

### intro テンプレート（V8基準）

**入力 content**:
```json
{
  "title": "プロジェクト名",
  "tagline": "タグライン",
  "logo": "public/logo-icon.png"
}
```

**出力**:
```tsx
// remotion/scenes/{name}.tsx
import { AbsoluteFill, useCurrentFrame, interpolate, spring, useVideoConfig, staticFile, Img } from "remotion";
import { brand, gradients, shadows } from "../brand";
import { Particles } from "../components/Particles";

export const IntroScene: React.FC<{
  title: string;
  tagline: string;
}> = ({ title, tagline }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoScale = spring({ frame, fps, config: { damping: 12, stiffness: 80 } });
  const logoOpacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: "clamp" });
  const titleOpacity = interpolate(frame, [20, 40], [0, 1], { extrapolateRight: "clamp" });
  const titleY = interpolate(frame, [20, 50], [30, 0], { extrapolateRight: "clamp" });

  return (
    <AbsoluteFill style={{ background: gradients.background }}>
      <Particles count={60} color={brand.particleColor} />
      <div style={{
        position: "absolute", top: "50%", left: "50%",
        width: 800, height: 800, transform: "translate(-50%, -50%)",
        background: `radial-gradient(circle, ${brand.glowColor} 0%, transparent 70%)`,
      }} />

      <AbsoluteFill style={{ display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center" }}>
        <div style={{ opacity: logoOpacity, transform: `scale(${logoScale})`, marginBottom: 40 }}>
          <Img src={staticFile("logo-icon.png")} style={{ width: 120, height: 120, filter: `drop-shadow(${shadows.glow})` }} />
        </div>
        <div style={{ opacity: titleOpacity, transform: `translateY(${titleY}px)`, textAlign: "center" }}>
          <div style={{ fontSize: 64, fontWeight: 800, color: brand.textPrimary, marginBottom: 16 }}>{title}</div>
          <div style={{ fontSize: 48, fontWeight: 700, background: gradients.text, WebkitBackgroundClip: "text", WebkitTextFillColor: "transparent" }}>
            {tagline}
          </div>
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

export const DURATION = {duration * 30}; // {duration}秒 @ 30fps
```

### ui-demo テンプレート（Playwright連携）

**入力 content**:
```json
{
  "url": "http://localhost:3000/login",
  "actions": [
    { "click": "[data-testid=email-input]" },
    { "type": "user@example.com" },
    { "click": "[data-testid=login-button]" },
    { "wait": 1000 }
  ]
}
```

**実行フロー**:

1. Playwright MCP でスクリーンショットをキャプチャ
2. キャプチャ画像を `remotion/assets/{scene.name}/` に保存
3. Sequence コンポーネントで画像を連結

**出力**:
```tsx
// remotion/scenes/{name}.tsx
import { AbsoluteFill, Img, Sequence } from "remotion";

export const UIDemoScene: React.FC<{
  screenshots: string[];
  durationInFrames: number;
}> = ({ screenshots, durationInFrames }) => {
  const framePerScreenshot = Math.floor(durationInFrames / screenshots.length);

  return (
    <AbsoluteFill>
      {screenshots.map((src, i) => (
        <Sequence
          key={i}
          from={i * framePerScreenshot}
          durationInFrames={framePerScreenshot}
        >
          <Img src={src} style={{ width: "100%", height: "100%" }} />
        </Sequence>
      ))}
    </AbsoluteFill>
  );
};
```

### cta テンプレート（V8基準）

**入力 content**:
```json
{
  "url": "https://myapp.com",
  "text": "今すぐ試す",
  "tagline": "Plan → Work → Review",
  "logo": "public/logo.png"
}
```

**出力**:
```tsx
// remotion/scenes/{name}.tsx
import { AbsoluteFill, useCurrentFrame, interpolate, spring, useVideoConfig, staticFile, Img } from "remotion";
import { brand, gradients, shadows } from "../brand";
import { Particles } from "../components/Particles";

export const CTAScene: React.FC<{
  url: string;
  text: string;
  tagline?: string;
}> = ({ url, text, tagline }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoScale = spring({ frame, fps, config: { damping: 12, stiffness: 80 } });
  const logoOpacity = interpolate(frame, [0, 20], [0, 1], { extrapolateRight: "clamp" });
  const textOpacity = interpolate(frame, [30, 60], [0, 1], { extrapolateRight: "clamp" });
  const buttonOpacity = interpolate(frame, [80, 120], [0, 1], { extrapolateRight: "clamp" });
  const urlOpacity = interpolate(frame, [140, 180], [0, 1], { extrapolateRight: "clamp" });

  // Pulsing glow effect
  const pulse = Math.sin(frame / 15) * 0.2 + 0.8;

  return (
    <AbsoluteFill style={{ background: gradients.background }}>
      <Particles count={60} color={brand.particleColor} />
      <AbsoluteFill style={{ display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center" }}>
        {/* Logo with pulsing glow */}
        <div style={{ opacity: logoOpacity, transform: `scale(${logoScale})`, marginBottom: 30, filter: `drop-shadow(0 0 ${40 * pulse}px ${brand.primary})` }}>
          <Img src={staticFile("logo.png")} style={{ height: 100 }} />
        </div>

        {/* Tagline */}
        {tagline && (
          <div style={{ opacity: textOpacity, fontSize: 32, color: brand.textSecondary, marginBottom: 60 }}>
            {tagline}
          </div>
        )}

        {/* CTA Button */}
        <div style={{
          opacity: buttonOpacity,
          background: gradients.primary,
          padding: "24px 72px",
          borderRadius: 16,
          fontSize: 32,
          fontWeight: 700,
          color: brand.textPrimary,
          boxShadow: shadows.glow,
          marginBottom: 40,
        }}>
          {text}
        </div>

        {/* URL */}
        <div style={{ opacity: urlOpacity, fontSize: 28, fontFamily: "monospace", color: brand.primary }}>
          {url}
        </div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};

export const DURATION = {duration * 30}; // {duration}秒 @ 30fps
```

### architecture テンプレート（Mermaid連携）

**入力 content**:
```json
{
  "diagram": "flowchart LR\n  A --> B --> C",
  "highlights": ["B"]  // アニメーションでハイライトするノード
}
```

**実行フロー**:

1. Mermaid CLI で SVG 生成
2. SVG を React コンポーネントに変換
3. ハイライトアニメーション追加

### feature-list テンプレート

**入力 content**:
```json
{
  "features": [
    { "icon": "🔐", "title": "認証", "description": "Clerk による安全な認証" },
    { "icon": "📊", "title": "ダッシュボード", "description": "リアルタイム分析" }
  ]
}
```

### changelog テンプレート

**入力 content**:
```json
{
  "version": "1.2.0",
  "date": "2026-01-20",
  "changes": {
    "added": ["認証フロー追加", "ダッシュボード改善"],
    "fixed": ["バグ修正"],
    "changed": []
  }
}
```

### hook テンプレート（LP/広告向け）

**用途**: 冒頭3-5秒の痛みフック

**入力 content**:
```json
{
  "painPoint": "また手動でコードレビュー？",
  "subtext": "計画、実装、確認... 全部一人でやってませんか？"
}
```

**出力**:
```tsx
export const HookScene: React.FC<{
  painPoint: string;
  subtext?: string;
}> = ({ painPoint, subtext }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const shakeAmount = Math.sin(frame * 0.5) * 2;

  return (
    <AbsoluteFill style={{ background: gradients.dark }}>
      <h1 style={{
        transform: `translateX(${shakeAmount}px)`,
        color: "#fff"
      }}>
        {painPoint}
      </h1>
      {subtext && <p style={{ color: "rgba(255,255,255,0.5)" }}>{subtext}</p>}
    </AbsoluteFill>
  );
};
```

### problem-promise テンプレート（LP/広告向け）

**用途**: 課題提示＋約束（5-15秒）

**入力 content**:
```json
{
  "problems": [
    { "icon": "😩", "title": "計画が曖昧", "desc": "タスク分解に時間がかかる" },
    { "icon": "🔄", "title": "手戻りが多い", "desc": "レビュー後に修正の嵐" }
  ],
  "promise": {
    "icon": "🎯",
    "text": "3コマンドで全て解決"
  }
}
```

### differentiator テンプレート（LP/広告向け）

**用途**: 差別化の根拠（Before/After比較）

**入力 content**:
```json
{
  "title": "時間を取り戻す",
  "comparisons": [
    { "label": "コードレビュー", "before": "30分/回", "after": "3分", "savings": "90%削減" },
    { "label": "タスク計画", "before": "15分", "after": "1分", "savings": "93%削減" }
  ],
  "tagline": "Harness を使えば、ソロでもチーム級の品質"
}
```

---

## 出力フォーマット

エージェント完了時に以下を返す:

```json
{
  "status": "success",
  "scene_id": 1,
  "file": "remotion/scenes/intro.tsx",
  "duration_frames": 150,
  "assets": [],
  "notes": "生成完了"
}
```

**エラー時**:

```json
{
  "status": "error",
  "scene_id": 2,
  "error": "Playwright capture failed - app not running",
  "recoverable": true,
  "suggestion": "アプリを起動してください: npm run dev"
}
```

### エラーハンドリングガイダンス

| エラー | 原因 | 対処 |
|--------|------|------|
| `Playwright capture failed - app not running` | ローカルアプリ未起動 | `npm run dev` でアプリ起動 |
| `Invalid template` | 未対応テンプレート指定 | 利用可能テンプレートを確認 |
| `Asset not found` | 画像/音声ファイル不在 | `public/` にアセット配置 |
| `Remotion render failed` | コンポジションエラー | Studio でエラー詳細確認 |
| `Network error` | MCP 接続失敗 | Playwright MCP 再起動 |

**リカバリー可能なエラー** (`recoverable: true`):
- ユーザー操作で解決可能（アプリ起動、ファイル配置等）

**リカバリー不可能なエラー** (`recoverable: false`):
- 設計変更が必要（テンプレート未対応、機能制限等）

---

## Playwright キャプチャ手順

ui-demo テンプレートの場合:

1. **アプリ起動確認**
   ```bash
   curl -s http://localhost:3000 > /dev/null && echo "running" || echo "not running"
   ```

2. **Playwright MCP でナビゲート**
   ```
   mcp__playwright__browser_navigate: { url: "http://localhost:3000/login" }
   ```

3. **アクション実行 + スクリーンショット**
   ```
   各 action に対して:
   - click/type/wait を実行
   - mcp__playwright__browser_take_screenshot でキャプチャ
   - assets/{scene.name}/step_{n}.png に保存
   ```

4. **コンポーネント生成**
   - 保存したスクリーンショットパスを配列に
   - UIDemoScene コンポーネントを生成

---

## スタイリングガイドライン（V8基準）

### ブランドシステム（brand.ts）

```tsx
// remotion/src/brand.ts から import
import { brand, gradients, shadows } from "./brand";

// 使用例
style={{
  color: brand.primary,              // #F97316 (orange)
  background: gradients.background,  // ダークグラデーション
  boxShadow: shadows.glow,           // オレンジグロー
}}
```

### SceneBackground パターン（必須）

```tsx
const SceneBackground: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return (
    <AbsoluteFill style={{ background: gradients.background }}>
      <Particles count={60} color={brand.particleColor} />
      <div
        style={{
          position: "absolute",
          top: "50%",
          left: "50%",
          width: 800,
          height: 800,
          transform: "translate(-50%, -50%)",
          background: `radial-gradient(circle, ${brand.glowColor} 0%, transparent 70%)`,
          pointerEvents: "none",
        }}
      />
      {children}
    </AbsoluteFill>
  );
};
```

### アニメーション原則

- **フェードイン**: 30フレーム（1秒）
- **スケール**: 0.8 → 1.0 over 15-30フレーム
- **スライド**: translateY(30px) → 0 over 30フレーム
- **遅延**: 複数要素は各 30-50 フレームずつ遅延
- **spring**: ロゴ等の弾むアニメーション

```tsx
// カードアニメーションの例
const cardOpacity = interpolate(frame, [delay, delay + 30], [0, 1], { extrapolateRight: "clamp" });
const cardY = interpolate(frame, [delay, delay + 30], [40, 0], { extrapolateRight: "clamp" });
const cardScale = interpolate(frame, [delay, delay + 30], [0.8, 1], { extrapolateRight: "clamp" });
```

---

## 注意事項

- 1エージェント = 1シーンの責任
- Playwright シーンはアプリが起動している前提
- 生成後のファイルは手動編集可能
- 並列実行時はファイル競合に注意（scene.name でユニーク化）
