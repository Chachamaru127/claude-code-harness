# Social Content

此目录是 X 等对外发布内容的正本放置处。

## 放置的内容

- 投稿文
- 线程原稿
- 图像生成 prompt
- alt 文本
- 投稿备注

补充：
- `x-article` 的生成中 package 汇总在 `out/social/<slug>/`
- 其中包含 `article.md`、图像、质量报告、API 响应
- `docs/social/` 作为升格为公开用的正本放置处

## 不放置的内容

- 生成图像
- 候选渲染
- 比较用的派生图像
- 临时输出

它们放置在 `out/social/`。

`out/x-post/` 或 `out/x-promo/` 等旧目录为兼容性保留，新的 social 系产物优先使用 `out/social/`。

## 命名规则

- 更新介绍：`claude-code-<version>-harness-update.md`
- 一般告知：`harness-<topic>-x-post.md`
- 优先主题名而非序号

## 运用规则

- 投稿前修改文面时，更新此目录的原稿
- 图像生成后的产物仅追加到 `out/social/`
- 犹豫时以 `docs/content-layout.md` 为正本规则参照
