# Vision High-Res Flow (Opus 4.7)

Scenario-specific flows for utilizing the high-resolution vision capability of Opus 4.7 (max 2576px short side) in harness-review.

> **Resolution limit**: 2576px short side is the safe operational upper limit. Pre-resize is recommended for images exceeding this.
> Detailed guide: [`docs/opus-4-7-vision-usage.md`](../../../docs/opus-4-7-vision-usage.md)

---

## Scenario 1: PDF Page Review

When using spec documents, design documents, release notes and other PDFs as review targets.

### Flow

1. **Identify page range**

   Sending an entire PDF at once increases token consumption, so first get a sense of the page structure.

   ```
   Read tool: file_path="<path>.pdf", pages="1-5"
   ```

2. **Check the effective DPI per page**

   If the PDF has high DPI, the rendered short side may exceed 2576px.
   In that case, ask for a re-export at lower DPI (see usage guide for details).

3. **Load the review target pages with Read**

   ```
   Read tool: file_path="<path>.pdf", pages="<target page range>"
   ```

   The Read tool passes the pages specified by the pages parameter to the vision model.
   Up to 20 pages can be specified per call.

4. **Pass to Reviewer agent**

   Feed the loaded page content into the harness-review flow (Step 2: 5 perspectives).
   The Reviewer evaluates including visual layout, diagrams, and code snippets.

5. **Batch processing (for many pages)**

   PDFs over 20 pages are split into batches of 20 pages.

   ```
   pages="1-20"  → review → record findings
   pages="21-40" → review → record findings
   ...
   Consolidate verdict after all batches are complete
   ```

### Determination criteria

PDF reviews treat reviewer_profile as `static` and evaluate the following:

| Perspective | Check content |
|------|------------|
| **Quality** | Are diagrams sufficiently explained? Is the order of steps clear? |
| **Accessibility** | Are there any image-only pages without alt text? |
| **AI Residuals** | Incomplete markers like "TODO", "TBD", "Draft" |

---

## Scenario 2: Architecture Diagram Review

When using system diagrams, ER diagrams, sequence diagrams and other images as review targets.

### Flow

1. **Check image resolution**

   ```bash
   # macOS: check resolution with sips
   sips -g pixelWidth -g pixelHeight diagram.png

   # With ImageMagick
   identify diagram.png
   ```

   If the short side is 2576px or less, it can be passed directly via Read tool.
   If it exceeds this, pre-resize (see usage guide for details).

2. **Load image with Read tool**

   ```
   Read tool: file_path="diagram.png"
   ```

   Opus 4.7 can perceive up to 2576px, so it can analyze fine labels and arrows.

3. **Prepare context to pass to Reviewer agent**

   ```
   Please review the following architecture diagram.
   Target: <system name> <diagram type (configuration diagram / ER diagram / sequence diagram etc.)>
   Review perspective: <review purpose (consistency check / change diff check / security check etc.)>
   ```

4. **Evaluation items**

   | Perspective | Check content |
   |------|------------|
   | **Security** | Are authentication flow, authorization boundaries, and encryption requirements reflected in the diagram? |
   | **Quality** | Are dependencies between components clear? Is single responsibility maintained? |
   | **Performance** | Are bottleneck-prone areas (synchronous processing / N+1 / no caching etc.) visualized? |

5. **Cross-reference with implementation code**

   After the diagram review, cross-reference with the corresponding implementation code via the Code Review flow to verify consistency.

---

## Scenario 3: UI Screenshot Review

When scoring web / mobile UI screenshots with the `--ui-rubric` option.

### Flow

1. **Prepare screenshots**

   Take screenshots of the target page or component.
   In Retina / HiDPI environments, the size is often double the logical pixel size.

   ```bash
   # macOS: screencapture command
   screencapture -x screenshot.png

   # Check resolution
   sips -g pixelWidth -g pixelHeight screenshot.png
   ```

2. **Check resolution and resize if necessary**

   Resize if the short side exceeds 2576px (see usage guide for details).
   If 2576px or less, it can be passed as-is via Read tool.

3. **Evaluate with harness-review --ui-rubric**

   ```
   /harness-review --ui-rubric
   ```

   Before running, load the screenshot with Read tool and pass to Reviewer agent:

   ```
   Read tool: file_path="screenshot.png"
   ```

4. **4-axis scoring (see ui-rubric.md)**

   | Axis | Evaluation content |
   |----|---------|
   | **Design Quality** | Visual hierarchy, whitespace, color consistency |
   | **Originality** | Uniqueness, brand expression |
   | **Craft** | Pixel precision, animations, micro-interactions |
   | **Functionality** | User flow completeness, error state consideration |

5. **Multi-resolution comparison (mobile / tablet / desktop)**

   Load screenshots of each resolution in succession in the same session
   and have the Reviewer agent evaluate responsive support together.

   ```
   Read tool: file_path="mobile.png"    # approximately 375×812
   Read tool: file_path="tablet.png"    # approximately 768×1024
   Read tool: file_path="desktop.png"   # approximately 1440×900
   ```

---

## Connecting to Reviewer Agent

In all 3 scenarios above, after loading images / PDF with the Read tool,
the connection to the Reviewer agent follows this common pattern.

### Connecting in breezing mode

When Lead receives a task with vision input from Worker:

1. Worker returns with image/PDF paths included in `files_changed`
2. Lead loads those paths with the Read tool and runs the review with vision context attached
3. Reviewer agent returns a verdict in the `review-result.v1` schema

```json
// Additional context example to pass to Reviewer
{
  "vision_inputs": [
    { "type": "image", "path": "diagram.png", "role": "architecture_diagram" },
    { "type": "pdf",  "path": "spec.pdf",    "role": "specification", "pages": "1-10" }
  ],
  "review_context": "Review of changes including images and PDFs"
}
```

### Reviewer behavior when receiving image input

- Reviewer treats image input equivalently to "normal diff text" and returns `review-result.v1`
- In `observations[].location`, write entries like `"diagram.png:overall"` / `"spec.pdf:p3"`
- If critical / major cannot be determined from images alone, stay at `minor` or `recommendation`
- Determination criteria (critical / major / minor / recommendation) do not change based on whether there is vision input

---

## Batch Processing Guidelines

When continuously reviewing multiple images / PDF pages:

| Situation | Recommended approach |
|------|--------------|
| PDF 20 pages or fewer | Specify all pages in a single Read |
| PDF 21 pages or more | Split into batches of 20 pages → consolidate findings |
| 1-5 images | Continuous Read → review together |
| 6 or more images | Batch in groups of 5 → consolidate verdict at the end |
| Mixed high-resolution images | Pre-resize then process (see usage guide) |

In batch processing, accumulate `observations` from each batch
and determine the final verdict based on the presence of `critical` / `major` after all batches complete.
