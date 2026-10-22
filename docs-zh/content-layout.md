# Content Layout

本 repository 中，`docs/` 和 `out/` 按以下规则区分使用。

## 基本规则

- `docs/`: 人阅读的正本。放置手写编辑的文章、公开用的原稿、prompt、设计备忘录、参考资料
- `out/`: 工具或生成处理的输出目标。放置图片、候选方案、导出、比较用的派生物

犹豫时按以下标准决定。

1. 人之后会阅读再利用的文章吗
   - 是: `docs/`
2. 是可再生成的生成物吗
   - 是: `out/`

## Social / X 运营

- `docs/social/`
  - 投稿文的正本
  - 图片生成 prompt
  - alt 文本
  - 投稿备忘录、构成方案
- `out/social/`
  - 生成的图片
  - 候选卡片
  - 工具输出的草稿
  - 比较用的一时成果物

也就是说，`docs/social/` 是 "要发布什么"，`out/social/` 是 "生成了什么"。

过去的运营中存在 `out/x-post/`、`out/x-posts/`、`out/x-promo/`、`out/x-release/`。这些暂时保留，但**今后新的 social 系输出统一归到 `out/social/`**。

## Slides / Media 运营

- `docs/slides/`
  - 幻灯片原稿、规格、YAML 源码
- `out/slides/`
  - 输出图片、选定图片、质量报告

## 添加时的规则

- 保存新的投稿文时，首先保存到 `docs/social/`
- 图片生成和输出回卷的结果保存到 `out/social/`
- 不在 `docs/` 中增加生成图片
- 不在 `out/` 中增加正本说明文

## 本次整理方针

- X 投稿的原稿源码统一到 `docs/social/`
- 现有 `out/social/` 作为已生成成果物保留
- 今后添加也遵循相同规则
