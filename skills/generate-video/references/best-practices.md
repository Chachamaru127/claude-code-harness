# SaaS Video Best Practices

A collection of best practices for SaaS introduction videos.
Provides guidelines for selecting the optimal structure based on video purpose and funnel stage.

---

## Core Principles

### 1. Decide "whose pain you eliminate" before designing the screen

Design not as a feature showcase, but as a device that converts viewer pain into conviction of resolution as quickly as possible.

**Risk**: An unclear target will resonate with no one.

### 2. Drop unnecessary ceremony in the first few seconds

Starting with a long logo animation or intro raises drop-off rates — get to the point immediately.
Prioritize speed of audio and topic start.

### 3. Length is determined by purpose

Engagement rates generally decline with length, but the optimal length depends on the goal.

| Length | Use case |
|------|------|
| 1-2 min | Low early drop-off |
| 5-10 min | Longer explainers |

**Conclusion**: For long-form videos, the opening design is everything.

### 4. Don't put CTA only at the end

Place CTAs midway through as well, to retain viewers who might leave early.

### 5. Watchable video is basic hygiene

**Priority order**: Audio quality > Screen readability > Pacing > Aesthetics

**Critical**: Poor audio causes immediate drop-off.

### 6. Subtitles and transcripts are mandatory

Subtitles are a requirement — auto-generation alone is not enough; corrections are needed.

### 7. Long-form needs chapters

Video viewers want to skip around, so add chapters (table of contents).

---

## Video Type Comparison by Funnel Stage

| Purpose (Funnel) | Video Type | Length | Core Structure | Main KPI |
|------------------|------------|----------|----------|---------|
| Awareness → Interest | Short teaser | 30–90s | Pain → Result (future) → "See more here" | Retention/CTR |
| Interest → Consideration | Intro demo | 2–3 min | Complete 1 use case end-to-end | Demo signups/Trial starts |
| Consideration → Conviction | Short sales demo | 2–5 min | Pre-empt top objections | Meeting rate/Reply rate |
| Conviction → Decision | Walkthrough / Webinar | 5–30 min | Real workflow + evidence | CVR/Inquiries |
| Expansion / Efficiency | Hybrid demo | Recording + Q&A | Recording for standardization → Live for personalization | Close rate/Effort reduction |
| Retention / Adoption | Onboarding | 30s–a few min (bite-sized) | Shortest path to quick win → Aha | Activation/Retention rate |
| Support | How-to/Troubleshooting | 1–5 min | One purpose per video | Ticket reduction/Self-service rate |

---

## Category-by-Category Guide

### For LP/Ads: Short Introduction (30–90 seconds)

**Purpose**: Awareness → Interest funnel

**Content outline**:
- 0–5s: Pain or desired outcome
- 5–20s: Target user and promise
- 20–60s: Signature workflow
- 60–90s: Next step

**Pitfalls to avoid**: Feature laundry list, abstract buzzwords

### For Consideration: 2–3 minute Intro Demo

Walk through a single use case end-to-end; avoid jargon and explain step by step.

**Recommendations**:
- Open briefly and get to the point
- Pick the most compelling single use case
- Include mid-video CTA

### For Sales: 2–5 minute Demo

Short sales video designed to move the viewer to the next step in the buying decision.

**Strategy**:
- Pre-empt the top 3 objections
- 1 video = 1 industry / job role

### For Decision-Makers: 15–30 minute Walkthrough

Long-form video promoting deeper understanding and decision-making. Chapters are required.

**Key points**:
- Core workflow
- Objection handling
- Admin/security explanation

### For Onboarding

Designed to get the user to their first success (Aha) moment.

**Guidelines**:
- Don't try to teach everything in one video
- Separate videos by role

### Support / Help Videos

Don't make the video the only answer — use it alongside text.

**Required elements**:
- Video + step-by-step text
- Subtitles + full transcript

---

## Templates

### 90-second Impact Introduction Template

**Use case**: LP/ads, Awareness → Interest funnel

| Time | Content | Frames (30fps) |
|------|------|------------------|
| 0:00–0:05 | Pain or desired outcome | 0-150 |
| 0:05–0:15 | Target user and promise | 150-450 |
| 0:15–0:55 | Signature workflow | 450-1650 |
| 0:55–1:10 | Differentiation evidence | 1650-2100 |
| 1:10–1:30 | CTA | 2100-2700 |

**Total**: 90 seconds = 2700 frames

### 3-minute Intro Demo Template

**Use case**: Consideration, Interest → Consideration funnel

| Time | Content |
|------|------|
| 0:00–0:10 | Conclusion + pain |
| 0:10–0:30 | Use case declaration |
| 0:30–2:20 | Live screen walkthrough |
| 2:20–2:50 | Address 1 common concern |
| 2:50–3:00 | CTA |

### 20-minute Decision-Maker Walkthrough

**Use case**: Conviction → Decision funnel

| Time | Content |
|------|------|
| 0:00–1:00 | Target and problem |
| 1:00–8:00 | Core workflow |
| 8:00–12:00 | Top 2 objections |
| 12:00–15:00 | Admin/Security |
| 15:00–20:00 | Success stories + CTA |

---

## Production Checklist

### Before Recording

- [ ] Script: cut everything unnecessary
- [ ] Demo environment: notifications off, personal info removed
- [ ] Screen: zoomed enough to read UI text

### During Recording

- [ ] Audio: clarity is top priority
- [ ] Lighting/appearance: minimum acceptable
- [ ] Pacing: cut every moment of hesitation

### At Publication

- [ ] Subtitles: quality review required
- [ ] Transcript: for search and skimming
- [ ] Long-form: chapters are mandatory

---

## Common Failure Patterns

| Failure | Impact |
|------|------|
| Unclear target audience | Resonates with no one |
| Long logo / company intro | Early drop-off |
| Everything-and-the-kitchen-sink | Loses focus |
| No subtitles / poor subtitles | Reduced accessibility |
| Just posting the video and calling it done | No way to measure impact |
| CTA only at the end | Missed by viewers who leave early |

---

## Recommended 3-Video Set

The core set for achieving results as quickly as possible:

1. **90-second teaser** - Awareness acquisition
2. **3-minute Intro demo** - Drive consideration
3. **15–25 minute decision-maker walkthrough** - Support conversion

**Outcome**: Fills the information gaps from acquisition → consideration → decision

---

## Using in Harness

### Video Type Auto-Detection

| Harness Detection Condition | Recommended Video Type | Template |
|-----------------|----------------|--------------|
| New project | Short LP/ad | 90-second teaser |
| UI changes detected | Intro demo | 3-minute template |
| CHANGELOG updated | Release notes | Before/After focus |
| Major structural changes | Architecture overview | Walkthrough |

### Scene Structure Guide

#### Short-form (30-90 seconds)

```
HookScene (3s) → ProblemPromise (7s) → WorkflowDemo (40-60s) → Differentiator (10s) → CTA (10s)
```

#### Intro demo (2-3 minutes)

```
Hook (10s) → UseCase declaration (20s) → Live screen demo (110s) → Address concern (30s) → CTA (10s)
```

#### Walkthrough (15-30 minutes)

```
Target and problem (1 min) → Core workflow (7 min) → Objection handling (4 min) → Admin/Security (3 min) → Success stories + CTA (5 min)
```

---

## Remotion Implementation Rules

### Animation

| Rule | Reason |
|--------|------|
| `useCurrentFrame()` required | CSS animations are prohibited; use Remotion's frame control |
| `spring({ damping: 200 })` | Smooth motion |
| `interpolate()` + `extrapolateRight: 'clamp'` | Prevent value runaway |
| Typewriter effect via `text.slice(0, charCount)` | Per-character opacity changes are not recommended |

### Audio

| Rule | Reason |
|--------|------|
| Import `Audio` from `@remotion/media` | `Html5Audio` is deprecated |
| Audio start = scene start + 30f (1-second delay) | Start audio after the slide has settled visually |
| Scene length = 30f + audio length + 20f buffer | Audio ends before transition begins |
| Pre-check audio length with `ffprobe` | Required info before designing scenes |

### TransitionSeries

| Rule | Reason |
|--------|------|
| Transition length: 15f (0.5s) recommended | Natural handoff |
| Scene start = previous scene start + previous scene length - transition length | Accounts for overlap |
| End audio before transition starts | Audio during a cut is jarring |

### Scene Length Calculation Example

```
Audio length (at 30fps):
  hook: 4.0s = 121 frames
  problem: 12.0s = 360 frames

Scene length:
  hook: 30(wait) + 121(audio) + 24(buffer) = 175 frames
  problem: 30(wait) + 360(audio) + 25(buffer) = 415 frames

Scene start frames (transition 15f):
  hook: 0
  problem: 175 - 15 = 160

Audio start timing:
  hook: 0 + 30 = 30
  problem: 160 + 30 = 190
```

---

## References

- [planner.md](planner.md) - Scenario planning
- [generator.md](generator.md) - Parallel scene generation
- [analyzer.md](analyzer.md) - Codebase analysis
