# Video Planner - Scenario Planner

Automatically proposes a scene structure from analysis results and confirms/adjusts it with the user.

---

## Overview

This is the scenario planner that runs in Step 2 of `/generate-video`.
It receives the output from analyzer.md and proposes an optimal scene structure.

> **Important**: Scene structures must be designed following the funnel-specific guidelines in [best-practices.md](best-practices.md)

## Input

Analysis results from analyzer.md:
- Project information (name, description)
- Detected feature list
- Recommended video type
- Recent changes

---

## Funnel-Specific Template Selection

### Step 0: Confirm the Purpose (Required)

Confirm the video's purpose and select the appropriate template.

| Purpose (Funnel) | Video Type | Length | Core Structure |
|------------------|------------|----------|----------|
| Awareness → Interest | LP/Ad teaser | 30-90s | Pain → Result → CTA |
| Interest → Consideration | Intro demo | 2-3 min | Complete 1 use case end-to-end |
| Consideration → Conviction | Demo/Release notes | 2-5 min | Pre-empt objections |
| Conviction → Decision | Walkthrough | 5-30 min | Real workflow + evidence |
| Retention / Adoption | Onboarding | 30s-a few min | Shortest path to Aha moment |

### 90-second Teaser Template

**Use case**: LP/ads, Awareness → Interest funnel

```
0:00-0:05 (150f)  → HookScene: Pain or desired outcome
0:05-0:15 (300f)  → ProblemPromise: Target user and promise
0:15-0:55 (1200f) → WorkflowDemo: Signature workflow
0:55-1:10 (450f)  → Differentiator: Differentiation evidence
1:10-1:30 (600f)  → CTA: Next step
```

### 3-minute Intro Demo Template

**Use case**: Consideration, Interest → Consideration funnel

```
0:00-0:10 (300f)  → Hook: Conclusion + pain
0:10-0:30 (600f)  → UseCase: Use case declaration
0:30-2:20 (3300f) → Demo: Live screen walkthrough
2:20-2:50 (900f)  → Objection: Address 1 common concern
2:50-3:00 (300f)  → CTA: Call to action
```

### 20-minute Walkthrough Template

**Use case**: Decision-makers, Conviction → Decision funnel

```
0:00-1:00   → Intro: Target and problem
1:00-8:00   → BasicFlow: Core workflow
8:00-12:00  → Objections: Top 2 objections
12:00-15:00 → Security: Admin/Security
15:00-20:00 → CaseStudy+CTA: Success stories + CTA
```

## Scene Templates

### Common Scenes

| Scene | Recommended Time | Content | Required |
|--------|----------|------|------|
| **Intro** | 3-5s | Logo + tagline + fade-in | ✅ |
| **CTA** | 3-5s | URL + contact + fade-out | ✅ |

### Product Demo Scenes

| Scene | Recommended Time | Content |
|--------|----------|------|
| **Feature intro** | 5-10s | Feature name + 1-line description |
| **UI demo** | 10-30s | Playwright capture |
| **Highlight** | 5-10s | Emphasize key characteristics |

### Architecture Overview Scenes

| Scene | Recommended Time | Content |
|--------|----------|------|
| **Overview diagram** | 5-10s | Mermaid diagram of overall structure |
| **Detail explanation** | 10-20s | Zoom into each component |
| **Data flow** | 10-15s | Sequence diagram animation |

### Release Notes Scenes

| Scene | Recommended Time | Content |
|--------|----------|------|
| **Version display** | 3-5s | vX.Y.Z + release date |
| **Change list** | 5-15s | Added/Changed/Fixed animation |
| **Before/After** | 10-20s | Side-by-side UI comparison |
| **New feature demo** | 10-30s | UI demo of added features |

---

## Scenario Generation Logic

### Step 1: Select Template by Video Type

```
Select base template based on recommended video type:
    │
    ├─ LP/Ad teaser (30-90s)
    │   └─ Hook → ProblemPromise → WorkflowDemo → Differentiator → CTA
    │
    ├─ Intro demo (2-3 min)
    │   └─ Hook → UseCase declaration → Live Demo → Objection → CTA
    │
    ├─ Release notes (1-3 min)
    │   └─ Hook → Version → Before/After → New feature Demo → CTA
    │
    ├─ Architecture overview (5-30 min)
    │   └─ Intro → Overview diagram → Detail ×N → Data flow → Admin/Security → CTA
    │
    └─ Onboarding (30s-a few min)
        └─ Welcome → Quick win → Next steps
```

**Key principles**:
- Don't show a long logo or company intro at the start (reduce drop-off)
- Place CTAs not just at the end but also midway through
- Story of "pain → solution", not a feature list

### Step 2: Generate Scenes from Detected Features

```python
# Pseudocode
for feature in detected_features:
    if feature.type == "auth":
        add_scene("Auth flow demo", duration=15, source="playwright")
    elif feature.type == "dashboard":
        add_scene("Dashboard introduction", duration=20, source="playwright")
    elif feature.type == "api":
        add_scene("API overview", duration=10, source="mermaid")
```

### Step 3: Optimize Time Distribution

| Video Length | Recommended Use | Scene Count |
|--------|----------|-------------|
| 15s | Social ads | 3-4 |
| 30s | Short video | 5-6 |
| 60s | Standard demo | 8-10 |
| 2-3 min | Detailed explanation | 15-20 |

---

## User Confirmation Flow

### Proposal Display

```markdown
🎬 Scenario Plan

**Video Type**: Product Demo
**Total Duration**: 45 seconds

| # | Scene | Duration | Content | Source |
|---|--------|------|------|--------|
| 1 | Intro | 5s | MyApp - Simplified task management | Template |
| 2 | Auth flow | 15s | Login screen demo | Playwright |
| 3 | Dashboard | 20s | Main feature introduction | Playwright |
| 4 | CTA | 5s | myapp.com | Template |

Is this structure acceptable?
1. OK, start generation
2. I want to edit
3. Cancel
```

### AskUserQuestion Implementation

```
AskUserQuestion:
  question: "Would you like to generate the video with this scenario?"
  header: "Scenario Confirmation"
  options:
    - label: "OK, start generation"
      description: "Generate the video with this scene structure"
    - label: "I want to edit"
      description: "Add/remove/modify scenes"
    - label: "Cancel"
      description: "Cancel video generation"
```

### Edit Mode

When the user selects "I want to edit":

```markdown
📝 Scenario Edit

You can edit with the following commands:

- **Add**: "Add a demo of feature X"
- **Remove**: "Remove scene 2"
- **Modify**: "Shorten the intro to 3 seconds"
- **Reorder**: "Swap scenes 2 and 3"
- **Done**: "That's good"

What would you like to edit?
```

---

## Output Format

planner.md output (input to generator.md):

```yaml
video:
  type: "product-demo"
  total_duration: 45
  resolution: "1080p"
  fps: 30

scenes:
  - id: 1
    name: "intro"
    duration: 5
    template: "intro"
    content:
      title: "MyApp"
      tagline: "Simplified task management"
      logo: "public/logo.svg"

  - id: 2
    name: "auth-demo"
    duration: 15
    template: "ui-demo"
    source: "playwright"
    content:
      url: "http://localhost:3000/login"
      actions:
        - click: "[data-testid=email-input]"
        - type: "user@example.com"
        - click: "[data-testid=login-button]"

  - id: 3
    name: "dashboard"
    duration: 20
    template: "ui-demo"
    source: "playwright"
    content:
      url: "http://localhost:3000/dashboard"
      actions:
        - wait: 1000
        - scroll: "down"

  - id: 4
    name: "cta"
    duration: 5
    template: "cta"
    content:
      url: "https://myapp.com"
      text: "Try it now"
```

---

## Notes

- If there are too many scenes, lower-priority ones are automatically excluded from the proposal
- Users can also manually add scenes
- Scenes with a Playwright source require the app to be running
