# Claude Code Harness v3.10 — X (Twitter) ポストツリー

> **投稿タイミング**: 平日 19:00〜21:00（エンジニア帰宅後のゴールデンタイム）
> **ターゲット**: AI支援開発に関心のある日本人開発者

---

### 🧵 1/6

Claude Code を「Plan → Work → Review」で自律運用する Harness、v3.10 になりました。

Claude Code 2.1.50〜2.1.74 の全機能を整理し、50以上のエントリを1つの Feature Table に集約。

「この機能、どう使えばいいの？」の答えがここにあります。

🔗 github.com/Chachamaru127/claude-code-harness

#ClaudeCode #AIDevTools #Harness

---

### 🧵 2/6

⚡ Auto Mode 対応

Claude Code の Research Preview として始まった Auto Mode。

Harness では bypassPermissions → Auto Mode への段階移行を整理しました。

・shipped default は bypassPermissions を維持
・--auto-mode は opt-in で段階導入
・Hooks 多層防御との併用で安全に自律運用

「安全な AI 自律運用」の現実的な橋渡し。

#ClaudeCode #AutoMode #AIDevTools

---

### 🧵 3/6

🤖 Agent Teams が進化

SubagentStart / SubagentStop に matcher を追加。Worker・Reviewer・Scaffolder・Video Generator の起動と停止を個別にトラッキングできるようになりました。

さらに：
・タスク依存関係の自動管理
・5-6 tasks/teammate の公式ベストプラクティス準拠
・permissionMode をエージェント定義に宣言的に記述

チームの見える化と制御が一段上に。

#ClaudeCode #AgentTeams #Harness

---

### 🧵 4/6

🛠️ 開発体験が大幅に向上

📊 Status Line — コンテキスト使用率・コスト・git状態を常時表示。90%超えは赤で警告。

⏪ Checkpointing — `/rewind` でセッション内の任意ポイントに巻き戻し。デバッグ迷子からの脱出に。

🔒 Sandboxing — OS レベルのファイルシステム/ネットワーク隔離。bypassPermissions の補完レイヤー。

地味だけど毎日使う機能。

#ClaudeCode #DevEx #AIDevTools

---

### 🧵 5/6

📖 Feature Table 完全版

Claude Code 2.1.50〜2.1.74 の機能を Harness がどう活用しているか、1つのテーブルに集約。

50+エントリ、1,000行超。

Agent Memory, Worktree, Hooks, Chrome Integration, LSP統合, 1M Context...

開発者のための「Claude Code 機能辞典」。

🔗 docs/CLAUDE-feature-table.md

#ClaudeCode #Harness #AIDevTools

---

### 🧵 6/6

🔄 Harness は self-referential

このプラグイン自体が、自分自身の改善に Harness を使っています。

`/breezing` で Agent Teams 起動 → Worker が実装 → Reviewer がレビュー → Harness 自身のコードを書く。

ドッグフーディングの極み。

試してみたい方👇
🔗 github.com/Chachamaru127/claude-code-harness

⭐ いただけると励みになります

#ClaudeCode #AIDevTools #Harness

---

## 画像プロンプト候補（Nano Banana Pro / Gemini 画像生成用）

### Post 1 用

```
A sleek infographic showing the "Plan → Work → Review" cycle as three interconnected nodes in a circular flow diagram. Dark background with blue and purple gradient accents. Text "v3.10" prominently displayed. "50+ Features" badge in the corner. Modern tech aesthetic, clean lines, minimal design. Japanese text labels for each node: 計画, 実装, レビュー. 16:9 aspect ratio.
```

### Post 2 用

```
A diagram showing a migration path from "bypassPermissions" to "Auto Mode" with a bridge metaphor. Left side labeled "Current: bypassPermissions" in blue, right side "Future: Auto Mode" in green, bridge in the middle with safety guardrails. Shield icons representing Hooks defense layers. Dark tech background. 16:9 aspect ratio.
```

### Post 3 用

```
Four agent icons (Worker, Reviewer, Scaffolder, Video Generator) arranged around a central monitoring dashboard with tracking lines for each role. Each agent has a distinct color: Worker in blue, Reviewer in green, Scaffolder in orange, Video Generator in magenta. Metrics and status indicators floating around each agent. "SubagentStart/Stop" label. Dark background, modern UI style. 16:9 aspect ratio.
```

### Post 4 用

```
A developer's terminal screen showing three feature panels: Left panel shows a status bar with context usage meter (gradient from green to yellow to red at 90%), cost counter, and git branch. Center panel shows a timeline with rewind points marked as checkpoints. Right panel shows a sandbox container with lock icon. Dark theme terminal aesthetic. "DevEx" header text. 16:9 aspect ratio.
```

### Post 5 用

```
A large reference book or encyclopedia open to a two-page spread, with a dense feature table visible on the pages. "50+" floating above the book as a badge. Small icons representing different features scattered around: gears, terminal, brain, shield, git branch. Title "Claude Code Feature Dictionary" on the cover. Blue and purple color scheme, dark background. 16:9 aspect ratio.
```

### Post 6 用

```
An ouroboros (snake eating its own tail) reimagined as a code loop: a plugin icon that points to itself with arrows labeled "improve". The cycle shows: "Harness writes code" → "Code improves Harness" → repeat. GitHub star icon in the corner with a sparkle effect. "Self-Referential" label. Minimal, modern design with dark background and accent colors. 16:9 aspect ratio.
```
