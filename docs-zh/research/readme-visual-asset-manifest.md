# README 视觉资产清单

日期：2026-05-24
状态：Pattern A 已批准并集成

本清单定义了 README 视觉刷新，但不声称最终图像使用官方 `GPT-image2.0` API 模型标签生成。
已批准的 Pattern A 图像通过内置 Codex 图像生成工具生成并复制到 workspace。

## 选定的方向

- 批准选项：A，操作循环
- 批准者：2026-05-24 应用内浏览器中的用户选择
- 集成的文件：
  - `docs/images/readme/hero-operating-loop-en.png`
  - `docs/images/readme/hero-operating-loop-ja.png`
- 源生成文件：
  - `/Users/tachibanashuuta/.codex/generated_images/019e4363-5936-78f0-bb1a-fc933f9d2693/ig_09f1b2980f71b0db016a126f2bc3a88191b3870aea35668baa.png`
  - `/Users/tachibanashuuta/.codex/generated_images/019e4363-5936-78f0-bb1a-fc933f9d2693/ig_09f1b2980f71b0db016a126f65446c8191a138702a7fe07b9c.png`

## 模型 / 工具边界

- 请求的标签：`GPT-image2.0`
- 2026-05-24 检查的官方 OpenAI API 文档：
  - https://platform.openai.com/docs/guides/image-generation
  - https://platform.openai.com/docs/guides/tools-image-generation/
  - https://platform.openai.com/docs/models/gpt-image-1.5
- 观测到的官方 API 模型系列：`gpt-image-1.5`、`gpt-image-1`、
  `gpt-image-1-mini`；Responses API 图像工具通过 `image_generation`
  使用 GPT Image 模型。
- 决定：`GPT-image2.0` 在本 repo 中仍是未验证的标签。对于 API
  生成，除非用户明确提供不同的本地工具或 ChatGPT UI 路径，否则使用 `gpt-image-1.5`。
  在该路径验证之前，不要在 README 或 CHANGELOG 中写"由 GPT-image2.0 生成"。

## 共享约束

- 白色背景。
- 使用现有的 `docs/images/claude-harness-logo-with-text.png` 色调作为
  品牌参考。
- 不使用不支持的 host logo。
- 不暗示 Cursor、GitHub Copilot CLI、Codex app 或 Antigravity CLI 为
  支持。
- 包含文本的图像必须有单独的英语和日语输出。
- 避免内部代码名和发布历史隐喻。
- 保持文本稀疏以承受图像生成。

## 批准选项

| 选项 | 方向 | 最适合 | 权衡 |
|--------|-----------|----------|----------|
| A | 操作循环 | README hero 和第一个工作流说明。 | 最具产品感；较少技术细节。 |
| B | 证据板 | 支持边界和 review/release 证明。 | 强信任信号；更具操作性。 |
| C | 工具优先地图 | 新用户 onboarding 和安装路径。 | 最明确；可能感觉更繁忙。 |

建议：为 README hero 批准选项 A，然后在刷新后的 README 首次发布后，
对次要图表使用选项 B 风格。

## 候选资产清单

| 资产 | 语言 | 含文本 | 批准后输出路径 | 用途 |
|-------|----------|--------------|----------------------------|---------|
| Hero 操作循环 | EN | 是 | `docs/images/readme/hero-operating-loop-en.png` | 第一个 README 视觉。 |
| Hero 操作循环 | JA | 是 | `docs/images/readme/hero-operating-loop-ja.png` | 第一个日语 README 视觉。 |
| 命令内部图 | EN | 是 | `assets/readme-visuals-en/generated/command-internals.png` | 显示命令内部做什么。 |
| 命令内部图 | JA | 是 | `assets/readme-visuals-ja/generated/command-internals.png` | 日语版本。 |
| 支持边界图 | EN | 是 | `assets/readme-visuals-en/generated/support-boundary.png` | 显示层级但不虚假 parity。 |
| 支持边界图 | JA | 是 | `assets/readme-visuals-ja/generated/support-boundary.png` | 日语版本。 |

## Prompt Pattern A：操作循环

英语 prompt：

```text
Create a clean product README hero image for Claude Code Harness on a white
background. Use a restrained orange, black, and soft green palette inspired by
the provided Claude Harness logo. Show five connected stages as a calm
operating loop: Spec, Plan, Work, Review, Release. Add small evidence chips:
TDD, unknowns, review gate, release proof. No unsupported host logos. No code
names. No dark background. Modern technical product style, polished, spacious,
high legibility, 1536x1024.
```

日语 prompt：

```text
白背景の Claude Code Harness README 用ヒーロー画像。既存 Claude Harness
ロゴに合う落ち着いた orange / black / soft green の配色。5つの段階を
読みやすい loop として表示: 仕様, 計画, 実装, レビュー, 出荷。小さな
evidence chip として TDD, unknown, review gate, release proof を配置。
未サポート host のロゴや、内部コード名は入れない。暗い背景にしない。
技術プロダクトらしい、余白のある、文字が読みやすい構図。1536x1024。
```

## Prompt Pattern B：证据板

英语 prompt：

```text
Create a white-background product illustration for Claude Code Harness focused
on trustworthy delivery. Center a clean evidence board with columns:
Plan Source, Test Result, Review Verdict, Release Gate. Use thin lines,
subtle shadows, orange accents, and green pass indicators. Include a small
"not observed != absent" note as a neutral footnote. No broad host support
claims, no external product logos, no code names. 1536x1024.
```

日语 prompt：

```text
Claude Code Harness の信頼できる出荷を表す白背景のプロダクト画像。
中央に evidence board を置き、列は 仕様正本, テスト結果, レビュー判定,
出荷ゲート。細い線、控えめな影、orange accent、green pass indicator。
小さな注として "not observed != absent" を中立的に入れる。広い host
support claim、外部プロダクトロゴ、内部コード名は入れない。1536x1024。
```

## Prompt Pattern C：工具优先地图

英语 prompt：

```text
Create a white-background onboarding map for Claude Code Harness. Show a
tool-first start: Claude Code supported, Codex CLI internal-compatible,
OpenCode internal-compatible, Candidate hosts research only. Use simple lanes
that flow into Harness setup, spec and plan, work, review, release. Use
Claude Harness brand orange, black, soft green. No unsupported parity claim,
no external logos, no code names. 1536x1024.
```

日语 prompt：

```text
Claude Code Harness の tool-first onboarding map を白背景で作る。
導線は Claude Code supported, Codex CLI internal-compatible, OpenCode
internal-compatible, candidate hosts は research only として分ける。
各 lane は Harness setup, 仕様と計画, 実装, レビュー, 出荷へ流れる。
Claude Harness らしい orange / black / soft green。未サポート parity claim、
外部ロゴ、内部コード名は入れない。1536x1024。
```

## 批准门控

Pattern A 已于 2026-05-24 满足。未来如果改变声明边界或添加含文本图像，
仍需单独批准。

## 2026-10-13 动作 hero 候选

- 授权：用户在要求视觉问题优先开场后请求 README hero 的 SVG 动态图形。候选已本地集成，未公开发布。
- 方向和时间线：`specs/2026-10-readme-motion/design.md`。一个持久的纸制物体世界将分散的工作沉淀为可见的路径；最终决定权在用户。
- 来源/构建：`specs/2026-10-readme-motion/build-assets.py`；720 × 390 SVG，EN/JA；12 秒循环。使用系统字体，无外部运行时或 API。
- 资产路径：`docs/images/readme/hero-motion-{en,ja}.svg`、`hero-motion-{en,ja}.gif`、`hero-motion-{en,ja}-poster.svg`。
- README alt 文本描述概念工作路径，非实时项目进度。艺术作品中未声称实际测试结果。
- 动作缩减：SVG 显示无动画的静止场景；README 图片为减少动作偏好选择 poster。GIF 是默认 README 显示，因为 GitHub 记录了 SVG 动画限制：https://docs.github.com/en/repositories/working-with-files/using-files/working-with-non-code-files 。
- 光栅导出使用 librsvg/Pango 进行日语字形整形，Pillow 进行 GIF 编码。它共享 SVG 时间线，而非编辑手绘光栅帧。未重绘源 logo。
- 验证：浏览器原生 SVG 转换在 0s 和 4s 之间不同；8s 保持沉降布局。两个 GIF 解码为 120 个不同帧，去重帧优化后恰好 12,000ms。日语字形通过 librsvg/Pango 验证；360px/720px 预览已检查。独立裁决待定。实际发布的 GitHub 回读未观测到。
