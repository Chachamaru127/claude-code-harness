# Visual Effects Library

動画にインパクトを与える視覚効果のテンプレート集です。

---

## カラーパレット

### Cyberpunk / Neon（推奨）

インパクトのある技術系動画向け。

```tsx
const colors = {
  background: "#0A0A0F",  // ディープダーク
  primary: "#00F5FF",     // シアン
  secondary: "#FF00FF",   // マゼンタ
  accent: "#7B2FFF",      // パープル
  text: "#FFFFFF",
  glow: "rgba(0, 245, 255, 0.5)",
};
```

### Corporate / Professional

ビジネス向け落ち着いたトーン。

```tsx
const colors = {
  background: "#FFFFFF",
  primary: "#FF6B35",     // オレンジ
  secondary: "#004E89",   // ネイビー
  accent: "#2EC4B6",      // ティール
  text: "#1A1A2E",
};
```

---

## 効果コンポーネント

### GlitchText - グリッチテキスト

RGB分離 + ランダムオフセットでサイバーパンク風テキスト。

```tsx
import { useCurrentFrame, interpolate, random } from "remotion";

const GlitchText: React.FC<{
  text: string;
  fontSize?: number;
  startFrame?: number;
}> = ({ text, fontSize = 72, startFrame = 0 }) => {
  const frame = useCurrentFrame();
  const adjustedFrame = frame - startFrame;

  // グリッチ強度（最初の20フレームで減衰）
  const glitchIntensity = adjustedFrame < 20
    ? interpolate(adjustedFrame, [0, 20], [20, 0])
    : 0;
  const opacity = interpolate(adjustedFrame, [0, 15], [0, 1], {
    extrapolateRight: "clamp",
  });

  // ランダムオフセット
  const offsetX = glitchIntensity > 0
    ? (random(`x-${frame}`) - 0.5) * glitchIntensity
    : 0;
  const offsetY = glitchIntensity > 0
    ? (random(`y-${frame}`) - 0.5) * glitchIntensity * 0.5
    : 0;

  return (
    <div style={{ position: "relative", opacity }}>
      {/* Red channel (マゼンタ) */}
      <div
        style={{
          position: "absolute",
          fontSize,
          fontWeight: 800,
          color: "#FF00FF",
          transform: `translate(${offsetX - 3}px, ${offsetY}px)`,
          mixBlendMode: "screen",
          opacity: glitchIntensity > 0 ? 0.8 : 0,
        }}
      >
        {text}
      </div>
      {/* Blue channel (シアン) */}
      <div
        style={{
          position: "absolute",
          fontSize,
          fontWeight: 800,
          color: "#00F5FF",
          transform: `translate(${offsetX + 3}px, ${offsetY}px)`,
          mixBlendMode: "screen",
          opacity: glitchIntensity > 0 ? 0.8 : 0,
        }}
      >
        {text}
      </div>
      {/* Main text */}
      <div
        style={{
          fontSize,
          fontWeight: 800,
          color: "#FFFFFF",
          textShadow: "0 0 20px rgba(0, 245, 255, 0.5)",
          transform: `translate(${offsetX}px, ${offsetY}px)`,
        }}
      >
        {text}
      </div>
    </div>
  );
};
```

**使用例**:
```tsx
<GlitchText text="革新的な機能" fontSize={64} startFrame={0} />
```

---

### Particles - パーティクルシステム

浮遊・収束するパーティクルアニメーション。

```tsx
import { useMemo } from "react";
import { useCurrentFrame, useVideoConfig, interpolate, random } from "remotion";

const Particles: React.FC<{
  count?: number;
  converge?: boolean;      // 中央に収束するか
  convergeFrame?: number;  // 収束完了フレーム
}> = ({ count = 50, converge = false, convergeFrame = 100 }) => {
  const frame = useCurrentFrame();
  const { width, height } = useVideoConfig();

  // useMemo でパーティクル初期位置を固定（重要！）
  const particles = useMemo(() => {
    return Array.from({ length: count }, (_, i) => ({
      id: i,
      startX: random(`px-${i}`) * width,
      startY: random(`py-${i}`) * height,
      speed: 0.5 + random(`speed-${i}`) * 2,
      size: 2 + random(`size-${i}`) * 4,
      hue: random(`hue-${i}`) > 0.5 ? "#00F5FF" : "#FF00FF",
    }));
  }, [count, width, height]);

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden" }}>
      {particles.map((p) => {
        const progress = converge
          ? interpolate(frame, [0, convergeFrame], [0, 1], {
              extrapolateRight: "clamp",
            })
          : 0;

        const targetX = width / 2;
        const targetY = height / 2;

        // 収束 or 浮遊
        const x = converge
          ? interpolate(progress, [0, 1], [p.startX, targetX])
          : p.startX + Math.sin(frame * 0.02 * p.speed + p.id) * 30;
        const y = converge
          ? interpolate(progress, [0, 1], [p.startY, targetY])
          : p.startY + ((frame * p.speed * 0.5) % height);

        const opacity = converge
          ? interpolate(progress, [0, 0.8, 1], [0.8, 0.8, 0])
          : 0.6 + Math.sin(frame * 0.1 + p.id) * 0.4;

        return (
          <div
            key={p.id}
            style={{
              position: "absolute",
              left: x,
              top: y % height,
              width: p.size,
              height: p.size,
              borderRadius: "50%",
              backgroundColor: p.hue,
              boxShadow: `0 0 ${p.size * 2}px ${p.hue}`,
              opacity,
            }}
          />
        );
      })}
    </div>
  );
};
```

**使用例**:
```tsx
{/* 浮遊パーティクル */}
<Particles count={80} />

{/* 収束パーティクル（CTAシーン向け） */}
<Particles count={100} converge convergeFrame={150} />
```

---

### ScanLine - スキャンライン

画面を走る解析波エフェクト。

```tsx
const ScanLine: React.FC<{ speed?: number }> = ({ speed = 1 }) => {
  const frame = useCurrentFrame();
  const { height } = useVideoConfig();
  const y = (frame * speed * 5) % (height + 100);

  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        top: y - 50,
        height: 100,
        background: `linear-gradient(180deg, transparent, #00F5FF40, transparent)`,
        boxShadow: "0 0 60px #00F5FF",
      }}
    />
  );
};
```

**使用例**:
```tsx
{/* 解析中の演出 */}
{frame < 60 && <ScanLine speed={3} />}
```

---

### ProgressBar - 進行バー

並列処理の進行状況を可視化。

```tsx
const ProgressBar: React.FC<{ progress: number; label: string }> = ({
  progress,
  label,
}) => {
  return (
    <div style={{ width: 400, marginBottom: 16 }}>
      <div
        style={{
          fontSize: 18,
          color: "#FFFFFF",
          marginBottom: 8,
          fontFamily: "monospace",
        }}
      >
        {label}
      </div>
      <div
        style={{
          height: 8,
          background: "rgba(255,255,255,0.1)",
          borderRadius: 4,
          overflow: "hidden",
        }}
      >
        <div
          style={{
            width: `${progress * 100}%`,
            height: "100%",
            background: "linear-gradient(90deg, #00F5FF, #FF00FF)",
            boxShadow: "0 0 20px #00F5FF",
            borderRadius: 4,
          }}
        />
      </div>
    </div>
  );
};
```

**使用例**:
```tsx
const agents = [
  { name: "Agent 1: Intro", progress: Math.min(1, frame / 150) },
  { name: "Agent 2: Demo", progress: Math.min(1, (frame - 30) / 180) },
  { name: "Agent 3: CTA", progress: Math.min(1, (frame - 60) / 120) },
];

{agents.map((agent) => (
  <ProgressBar key={agent.name} progress={agent.progress} label={agent.name} />
))}
```

---

### 3D Parallax - パララックス効果

奥行きのある3Dカード表示。

```tsx
const ParallaxCard: React.FC<{
  children: React.ReactNode;
  delay: number;
  color: string;
}> = ({ children, delay, color }) => {
  const frame = useCurrentFrame();

  const opacity = interpolate(frame, [delay, delay + 30], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const z = interpolate(frame, [delay, delay + 30], [-100, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });
  const rotateY = interpolate(frame, [delay, delay + 30], [45, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <div
      style={{
        width: 280,
        height: 160,
        background: `linear-gradient(135deg, ${color}30, ${color}10)`,
        border: `2px solid ${color}`,
        borderRadius: 16,
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        opacity,
        transform: `translateZ(${z}px) rotateY(${rotateY}deg)`,
        boxShadow: `0 0 40px ${color}40`,
      }}
    >
      {children}
    </div>
  );
};
```

**使用例**:
```tsx
<div style={{ display: "flex", gap: 40, perspective: 1000 }}>
  <ParallaxCard delay={30} color="#00F5FF">LP/広告</ParallaxCard>
  <ParallaxCard delay={70} color="#FF00FF">Introデモ</ParallaxCard>
  <ParallaxCard delay={110} color="#7B2FFF">リリースノート</ParallaxCard>
</div>
```

---

## 組み合わせ例

### インパクト重視のHookシーン

```tsx
const HookScene: React.FC = () => {
  const frame = useCurrentFrame();

  return (
    <AbsoluteFill style={{ background: "#0A0A0F" }}>
      <Particles count={80} />
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          alignItems: "center",
        }}
      >
        <GlitchText text="コードから動画が" fontSize={64} startFrame={0} />
        <div style={{ height: 20 }} />
        <GlitchText text="自動生成される時代へ" fontSize={64} startFrame={15} />
      </div>
      {frame < 30 && <ScanLine speed={3} />}
    </AbsoluteFill>
  );
};
```

### CTAシーン（パーティクル収束）

```tsx
const CTAScene: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const logoScale = spring({ frame: frame - 60, fps, config: { damping: 200 } });
  const pulse = Math.sin(frame / 10) * 0.03 + 1;

  return (
    <AbsoluteFill style={{ background: "#0A0A0F" }}>
      <Particles count={100} converge convergeFrame={150} />
      <div
        style={{
          position: "absolute",
          inset: 0,
          display: "flex",
          flexDirection: "column",
          justifyContent: "center",
          alignItems: "center",
        }}
      >
        <div
          style={{
            opacity: interpolate(frame, [60, 90], [0, 1], {
              extrapolateRight: "clamp",
            }),
            transform: `scale(${Math.max(0, logoScale)})`,
          }}
        >
          <Img src={staticFile("logo.png")} style={{ width: 120, height: 120 }} />
        </div>
        <div
          style={{
            marginTop: 40,
            padding: "16px 48px",
            background: "linear-gradient(90deg, #00F5FF, #FF00FF)",
            borderRadius: 12,
            fontSize: 24,
            fontWeight: 700,
            color: "#0A0A0F",
            transform: `scale(${pulse})`,
            boxShadow: "0 0 40px rgba(0, 245, 255, 0.6)",
          }}
        >
          今すぐ試す
        </div>
      </div>
    </AbsoluteFill>
  );
};
```

---

## 注意事項

| 項目 | ルール |
|------|--------|
| `random()` | 引数でシード指定必須（フレーム毎に同じ値） |
| `useMemo` | パーティクル等の大量オブジェクトは必ずメモ化 |
| `interpolate` | `extrapolateRight: "clamp"` で値の暴走防止 |
| `spring` | `config: { damping: 200 }` で滑らかに |
| CSS animations | 使用禁止、Remotion の `useCurrentFrame()` を使う |

---

## References

- [generator.md](generator.md) - 並列生成エンジン
- [best-practices.md](best-practices.md) - 動画制作ベストプラクティス
