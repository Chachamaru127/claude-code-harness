# UI Rubric Reviewer Profile

A visual quality-focused review profile activated by `harness-review --ui-rubric`.
Rather than leaving UI quality assessment as "just a feeling," it scores 4 axes on a 0-10 scale and makes a determination.

---

## The 4-Axis Framework

### 1. Design Quality

- What to look at: organization of information, whitespace, visual guidance, readability
- Common low-score examples: text too cramped, priority of elements is not conveyed
- Common high-score examples: what to look at is conveyed naturally

### 2. Originality

- What to look at: low sense of familiarity, intentional individuality, expression choices
- Common low-score examples: using a generic template layout as-is
- Common high-score examples: a unique presentation tailored to the brand or problem

### 3. Craft

- What to look at: attention to detail, alignment, spacing, typography, state transitions
- Common low-score examples: subtle misalignment, uneven spacing, rough hover/active states
- Common high-score examples: consistent in every detail with little sloppiness

### 4. Functionality

- What to look at: is it usable without confusion, do main flows work, is the UI practical?
- Common low-score examples: intent of buttons or forms is unclear, main flow is broken
- Common high-score examples: the user's next action is clear without hesitation

---

## Anchor Examples (0 / 5 / 10)

| Axis | 0 points | 5 points | 10 points |
|---|---|---|---|
| Design Quality | Unclear what is being shown, hard to read | Minimally readable but organization is weak | Information priority and visual guidance are clear |
| Originality | Looks like an off-the-shelf template | Some creative touches but weak impression | Has individuality suited to the problem, leaves an impression |
| Craft | Alignment and spacing are scattered, rough detail | No major issues but lacking polish | Whitespace, typography, and state transitions are carefully crafted |
| Functionality | Main flows are unclear and hard to use | Main operations are possible but have moments of confusion | Main flows are natural and operations are intuitive |

---

## Determination Method

1. Score each of the 4 axes on a scale of 0-10
2. If `review.rubric_target` exists, use those values as per-axis thresholds
3. If `review.rubric_target` does not exist, use default threshold=6 for all 4 axes
4. If even 1 axis falls below the threshold → `REQUEST_CHANGES`
5. If all axes meet the threshold → `APPROVE`

### `rubric_target` example

```json
{
  "design": 7,
  "originality": 6,
  "craft": 8,
  "functionality": 9
}
```

---

## How to Output

- Always set `reviewer_profile` to `"ui-rubric"`
- In `observations`, write the reason for score deductions in terms understandable to non-experts
- For each axis, include at least 1 note on "what to fix to improve the score"

### Output example

```json
{
  "reviewer_profile": "ui-rubric",
  "verdict": "REQUEST_CHANGES",
  "ui_rubric": {
    "scores": {
      "design": 7,
      "originality": 5,
      "craft": 8,
      "functionality": 8
    },
    "targets": {
      "design": 6,
      "originality": 6,
      "craft": 6,
      "functionality": 6
    }
  }
}
```

---

## Notes on Determination

- Do not give high scores for flashiness alone
- Do not inflate Originality just because something is "unusual"
- When usability is broken, prioritize Functionality and evaluate strictly
- Judge by **intent and completeness**, not design taste
