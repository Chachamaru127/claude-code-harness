# Remotion Setup Reference

Setup Remotion programmatic video generation environment.

## Quick Reference

- "**動画を作りたい**" → Remotion setup
- "**プロダクト紹介動画**" → First run this setup
- "**Remotion使いたい**" → This setup

## Deliverables

- `remotion/` - Remotion project directory
- Remotion Agent Skills (Claude Code integration)
- Harness templates (optional)

---

## Prerequisites

- Node.js 18+
- pnpm / npm / yarn
- Sufficient disk space (~500MB)

---

## Usage Options

```bash
/setup-tools remotion                 # Basic setup
/setup-tools remotion --with-templates    # With Harness templates
/setup-tools remotion --brownfield        # Add to existing project
/setup-tools remotion --with-narration    # With narration features
/setup-tools remotion --with-image-gen    # With AI image generation
```

---

## Execution Flow

### Step 1: Environment Check

```bash
# Check Node.js version
node --version  # Must be 18.0.0 or higher

# Check package manager
which pnpm || which npm
```

### Step 2: Setup Method Selection

> Setup method:
> 1. **New project** - Create `remotion/` directory
> 2. **Add to existing project** - Integrate into current project
>
> Which do you choose?

### Step 3a: New Project Creation

```bash
# Create Remotion project
npx create-video@latest remotion

# Recommended settings:
# - Template: Empty
# - TailwindCSS: Yes
# - Skills: Yes
```

### Step 3b: Add to Existing Project (Brownfield)

```bash
# Install required packages
npm install remotion @remotion/cli @remotion/player

# Optional: For rendering
npm install @remotion/renderer

# Optional: For Lambda
npm install @remotion/lambda
```

**Create folder structure**:

```
remotion/
├── Composition.tsx    # Main composition
├── Root.tsx           # Remotion root
└── index.ts           # Entry point
```

### Step 4: Install Agent Skills

```bash
npx skills add remotion-dev/skills
```

### Step 5: Add Harness Templates (Optional)

> Add Harness templates?
>
> Available templates:
> - Shared components (FadeIn, SlideUp, TextReveal)
> - Brand assets (COLORS, FONTS)
> - Presets (1080p, vertical, square)
>
> Add? (y/n)

**If "y"**:
```bash
PLUGIN_DIR="${CLAUDE_PLUGIN_ROOT:-$(dirname $(dirname $0))}"
cp -r "$PLUGIN_DIR/templates/remotion/"* remotion/
```

### Step 6: Narration Feature (Optional)

> Add narration feature?
>
> Uses Aivis Cloud API for AI voice narration.
>
> **Required**:
> - Aivis Cloud API key
> - Commercial-use model (ACML 1.0 license)
>
> Add? (y/n)

**If "y"**:
```bash
export AIVIS_API_KEY=aivis_xxxxxx
mkdir -p remotion/src/utils remotion/src/hooks remotion/src/components remotion/public/audio
```

### Step 7: AI Image Generation (Optional)

> Add AI image generation?
>
> Uses Nano Banana Pro (Google DeepMind) for scene images.
>
> **Required**:
> - Google AI Studio API key
> - Gemini API billing setup
>
> Add? (y/n)

**If "y"**:
```bash
export GOOGLE_AI_API_KEY="your-api-key"
mkdir -p out/assets/generated
```

### Step 8: Add package.json Scripts

```json
{
  "scripts": {
    "remotion": "remotion studio remotion/index.ts",
    "render": "remotion render remotion/index.ts Main out/video.mp4",
    "render:gif": "remotion render remotion/index.ts Main out/video.gif",
    "generate-narration": "npx ts-node src/utils/narration-generator.ts"
  }
}
```

### Step 9: Completion Message

> Remotion setup complete!
>
> **Created files**:
> - `remotion/` - Remotion project
> - `.claude/skills/remotion/` - Agent Skills
>
> **Usage**:
> ```bash
> # Start Studio (preview)
> npm run remotion
>
> # Render video
> npm run render
>
> # Generate narration (optional)
> AIVIS_API_KEY=your_key npm run generate-narration
>
> # Create video with Claude Code
> claude
> > "Create intro video"
> ```
>
> **Next steps**:
> - `/generate-video` for automated video generation
> - Manual editing in Studio: http://localhost:3000

---

## Troubleshooting

### "Cannot find module 'remotion'"

```bash
rm -rf node_modules && npm install
```

### "Skills not found"

```bash
npx skills list
```

### Rendering is slow

```bash
npx remotion render --concurrency 4
```

---

## License Notice

> **Remotion License**
>
> Remotion requires paid license for enterprise use.
> Details: https://www.remotion.dev/license
>
> Personal/OSS use is free.

> **Aivis Cloud API License (when using narration)**
>
> Use ACML 1.0 licensed models for commercial use.
> Pricing: Pay-as-you-go (440 JPY/10,000 chars) or monthly (1,980 JPY/month)
