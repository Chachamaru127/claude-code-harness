# Opus 4.7 Vision 使用指南

关于在 Opus 4.7 中强化的 vision 功能（分辨率上限 ~2576px）的运用指
南。 适用于 harness-review 中对 PDF・设计图・UI 截图的 review。

> **来源**: Claude / Opus 4.7 发布说明以及 Claude Code 文档中记载
> 的 vision 规格。 「短边 2576px 以内是安全的」是基于这些文档的数值，不使用其他数值。

---

## 基本方针

### 解像度上限

**短边 2576px** 是 Opus 4.7 的 vision 在运用上的安全上限。

| 图像尺寸 | 对应 |
|-----------|------|
| 短边 2576px 以下 | 可直接通过 Read tool 传入 |
| 短边 2576px 以上 | **必须事先 resize**（参见下文） |

- 「短边」是横竖中较小的一方。例: 3840×2160 的图像短边 = 2160px（在上限内）
- 例: 5000×3000 的图像短边 = 3000px（超出上限 → 需要 resize）
- 即使长边超过 2576px，只要短边在 2576px 以下就没有问题

---

## 超过 2576px 时的事先 resize 步骤

### macOS (sips 命令)

```bash
# 解像度確認
sips -g pixelWidth -g pixelHeight input.png

# リサイズ: 長辺・短辺のうち大きい方を 2576px に収める
sips -Z 2576 input.png --out output.png
```

`-Z 2576` 是在保持宽高比的前提下，把长边收敛到 2576px。
 在短边超过 2576px 的情况下（例如竖长图），同样有效。

### ImageMagick (跨平台)

```bash
# リサイズ: 縦横どちらも 2576px を超えないよう縮小（アスペクト比保持）
convert input.png -resize 2576x2576\> output.png
```

`\>` 是「仅当原始尺寸大于指定值时才缩小」
的修饰符。 2576px 以下的图像不会被改变。

### 批量 resize 多个文件 (macOS sips)

```bash
# カレントディレクトリの PNG を全てリサイズして resized/ に出力
mkdir -p resized
for f in *.png; do
  sips -Z 2576 "$f" --out "resized/$f"
done
```

---

## PDF 时的注意事项

PDF 是 **按页** 传给 vision 模型的。 每页
的渲染分辨率（DPI）过高时，1 页可能超过 2576px。

### DPI 与实际分辨率的关系

| DPI | A4 页的实际分辨率（纵×横） | 短边 |
|-----|-------------------------------|------|
| 72 dpi  | 595 × 842 px | 595px（上限内） |
| 150 dpi | 1240 × 1754 px | 1240px（上限内） |
| 200 dpi | 1654 × 2340 px | 1654px（上限内） |
| 250 dpi | 2067 × 2926 px | 2067px（上限内） |
| 300 dpi | 2480 × 3508 px | 2480px（上限内） |
| 360 dpi | 2976 × 4210 px | **2976px（上限超）** |

在 A4 尺寸的情况下，300 dpi 为止基本安全。360 dpi 以上需要注意。

### 调整 PDF 的 DPI 并导出（Ghostscript）

```bash
# 150 dpi で再エクスポート（ファイルサイズも削減）
gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite \
   -dPDFSETTINGS=/screen \
   -sOutputFile=output_150dpi.pdf input.pdf

# 特定の解像度を明示指定
gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite \
   -dCompatibilityLevel=1.4 \
   -dDownsampleColorImages=true \
   -dColorImageResolution=200 \
   -sOutputFile=output_200dpi.pdf input.pdf
```

### 在 Read tool 中读取 PDF

```
Read tool: file_path="spec.pdf", pages="1-5"
```

- 用 `pages` 参数指定读取的页范围（例如: `"1-5"`, `"3"`, `"10-20"`）
- 单次请求最多可指定 20 页
- 超过 20 页的 PDF 需按 20 页为单位分批读取

---

## 内存消耗的参考值

传入多张高分辨率图像时，token 消耗会增加。请参考以下数值调整张数。

| 每张图像的分辨率 | 概算 token 消耗（vision 输入部分） |
|------------------------|-------------------------------|
| 512 × 512 px | ~85 tokens |
| 1024 × 1024 px | ~340 tokens |
| 2048 × 2048 px | ~1360 tokens |
| 2576 × 2576 px | ~2100 tokens（接近上限） |

> 上述为概算值。实际消耗量会因图像内容・压缩率・模型的内部处理而变动。

### 传入 N 张时的换算示例

| 枚数 × 解像度 | 概算 token 消費 |
|--------------|----------------|
| 5 张 × 2576px | ~10,500 tokens |
| 10 张 × 2576px | ~21,000 tokens |
| 20 张 × 2048px | ~27,200 tokens |

在拥有 1M 上下文窗口的 Opus 4.7 中，这些大约只占整体的
2〜3% 左右。 但在同一会话中处理大量高分辨率图像时，建议分批处理。

---

## 常见错误与处理

| 症状 | 原因 | 対処 |
|------|------|------|
| Read tool 不返回图像 | 文件路径不正确，或格式不受支持 | 检查路径。限定为 PNG / JPG / GIF / WebP / PDF |
| review 结果为「图像不清晰」 | 分辨率过低（100px 以下等） | 准备高分辨率版本，或补充文字说明 |
| PDF 缺少部分页面 | pages 指定超过了 PDF 的总页数 | 将 `pages` 收敛到有效范围 |
| 处理缓慢 / 超时 | 传入了大量高分辨率图像 | 以 5 张为单位分批处理 |

---

## 相关文档

- [`skills/harness-review/references/vision-high-res-flow.md`](../skills/harness-review/references/vision-high-res-flow.md) — 按典型场景划分的流程（PDF / 设计图 / UI 截图）
- [`skills/harness-review/SKILL.md`](../skills/harness-review/SKILL.md) — harness-review 主 skill 定义
- [`docs/CLAUDE-feature-table.md`](CLAUDE-feature-table.md) — Opus 4.7 功能一览（vision 2576px 条目）
