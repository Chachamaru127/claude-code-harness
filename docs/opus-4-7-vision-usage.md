# Opus 4.7 Vision Usage Guide

Usage guide for the enhanced vision capabilities in Opus 4.7 (resolution limit ~2576px).
Applies to harness-review when reviewing PDFs, schematics, and UI screenshots.

> **Source**: Claude / Opus 4.7 release notes and the vision specification in Claude Code
> documentation. "Safe up to 2576px on the short side" is the value from those documents;
> no other figures should be used.

---

## Basic guidelines

### Resolution limit

**2576px on the short side** is the operational safe limit for vision in Opus 4.7.

| Image size | Action |
|-----------|--------|
| Short side 2576px or less | Pass directly to the Read tool |
| Short side exceeds 2576px | **Pre-resize required** (see below) |

- "Short side" is the smaller of width and height. Example: a 3840×2160 image has a short
  side of 2160px (within limit).
- Example: a 5000×3000 image has a short side of 3000px (exceeds limit → resize required).
- The long side may exceed 2576px as long as the short side stays at 2576px or below.

---

## Pre-resize procedure when the short side exceeds 2576px

### macOS (sips command)

```bash
# Check resolution
sips -g pixelWidth -g pixelHeight input.png

# Resize: fit the longest dimension within 2576px
sips -Z 2576 input.png --out output.png
```

`-Z 2576` preserves aspect ratio and fits the long side within 2576px.
It also works when the short side exceeds 2576px (e.g., portrait images).

### ImageMagick (cross-platform)

```bash
# Resize: shrink so neither dimension exceeds 2576px (preserving aspect ratio)
convert input.png -resize 2576x2576\> output.png
```

`\>` is a modifier meaning "shrink only when the original is larger than the specified value".
Images at 2576px or below are left unchanged.

### Batch resize multiple files (macOS sips)

```bash
# Resize all PNGs in the current directory and output to resized/
mkdir -p resized
for f in *.png; do
  sips -Z 2576 "$f" --out "resized/$f"
done
```

---

## Notes for PDFs

PDFs are passed to the vision model **one page at a time**.
If the rendering resolution (DPI) is high, a single page may exceed 2576px.

### DPI and effective resolution

| DPI | A4 page effective resolution (height × width) | Short side |
|-----|----------------------------------------------|-----------|
| 72 dpi  | 595 × 842 px | 595px (within limit) |
| 150 dpi | 1240 × 1754 px | 1240px (within limit) |
| 200 dpi | 1654 × 2340 px | 1654px (within limit) |
| 250 dpi | 2067 × 2926 px | 2067px (within limit) |
| 300 dpi | 2480 × 3508 px | 2480px (within limit) |
| 360 dpi | 2976 × 4210 px | **2976px (exceeds limit)** |

For A4 size, up to 300 dpi is generally safe. 360 dpi and above requires attention.

### Re-export PDF at a target DPI (Ghostscript)

```bash
# Re-export at 150 dpi (also reduces file size)
gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite \
   -dPDFSETTINGS=/screen \
   -sOutputFile=output_150dpi.pdf input.pdf

# Specify a target resolution explicitly
gs -dNOPAUSE -dBATCH -sDEVICE=pdfwrite \
   -dCompatibilityLevel=1.4 \
   -dDownsampleColorImages=true \
   -dColorImageResolution=200 \
   -sOutputFile=output_200dpi.pdf input.pdf
```

### Loading a PDF with the Read tool

```
Read tool: file_path="spec.pdf", pages="1-5"
```

- Use the `pages` parameter to specify the page range (e.g., `"1-5"`, `"3"`, `"10-20"`).
- Up to 20 pages can be specified per request.
- PDFs longer than 20 pages must be read in 20-page batches.

---

## Token consumption estimates

Passing multiple high-resolution images increases token consumption. Use the table below
to decide how many images to include.

| Resolution per image | Estimated token consumption (vision input) |
|---------------------|--------------------------------------------|
| 512 × 512 px | ~85 tokens |
| 1024 × 1024 px | ~340 tokens |
| 2048 × 2048 px | ~1,360 tokens |
| 2576 × 2576 px | ~2,100 tokens (near limit) |

> These are rough estimates. Actual consumption varies based on image content,
> compression rate, and model internal processing.

### Estimates for N images

| Images × resolution | Estimated token consumption |
|--------------------|----------------------------|
| 5 × 2576px | ~10,500 tokens |
| 10 × 2576px | ~21,000 tokens |
| 20 × 2048px | ~27,200 tokens |

With Opus 4.7's 1M context window these represent approximately 2-3% of the total.
However, batch splitting is recommended when processing large numbers of high-resolution
images within a single session.

---

## Common errors and remedies

| Symptom | Cause | Remedy |
|---------|-------|--------|
| Read tool returns no image | Incorrect file path or unsupported format | Verify path; limit to PNG / JPG / GIF / WebP / PDF |
| Review result says "image is unclear" | Resolution too low (100px or below, etc.) | Provide a higher-resolution version or add text context |
| Some PDF pages are missing | `pages` range exceeds the total page count | Keep `pages` within the valid range |
| Slow processing / timeout | Large number of high-resolution images | Split into batches of 5 images |

---

## Related documents

- [`skills/harness-review/references/vision-high-res-flow.md`](../skills/harness-review/references/vision-high-res-flow.md) — Per-scenario flows (PDF / schematic / UI screenshot)
- [`skills/harness-review/SKILL.md`](../skills/harness-review/SKILL.md) — harness-review main skill definition
- [`docs/CLAUDE-feature-table.md`](CLAUDE-feature-table.md) — Opus 4.7 feature list (vision 2576px entry)
