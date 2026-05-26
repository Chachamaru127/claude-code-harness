# Video Analyzer - Codebase Analysis Engine

Automatically analyzes a project and extracts the information needed for video generation.

---

## Overview

This is the analysis engine that runs in Step 1 of `/generate-video`.
It parses the codebase and project assets to determine the optimal video structure.

## Analysis Items

### 1. Framework Detection

| Detection Target | Detection Method |
|---------|---------|
| Next.js | Presence of `next.config.*` |
| React | `package.json` dependencies |
| Vue | `vue.config.*` or `nuxt.config.*` |
| Svelte | `svelte.config.*` |
| Express/Fastify | `package.json` dependencies |

**Commands**:
```bash
# Extract dependencies from package.json
cat package.json | jq '.dependencies, .devDependencies'

# Check for config file presence
ls -la *.config.* 2>/dev/null
```

### 2. Key Feature Detection

| Feature | Detection Pattern |
|------|-------------|
| Authentication | `auth/`, `login/`, `@clerk`, `@auth0`, `supabase` |
| Payments | `payment/`, `billing/`, `stripe`, `@stripe` |
| Dashboard | `dashboard/`, `admin/`, `analytics` |
| API | `api/`, `routes/`, `trpc`, `graphql` |
| DB | `prisma/`, `drizzle/`, `@supabase` |

**Commands**:
```bash
# Infer features from directory structure
find src app -type d -name "auth" -o -name "login" -o -name "dashboard" 2>/dev/null

# Infer features from packages
grep -E "clerk|stripe|supabase|prisma" package.json
```

### 3. UI Component Detection

| Item | Detection Method |
|------|---------|
| Page count | Count of `app/**/page.tsx` or `pages/**/*.tsx` |
| Component count | Count of `components/**/*.tsx` |
| UI library | Detect `shadcn`, `radix`, `chakra`, `mui` |

**Commands**:
```bash
# Count pages
find . -name "page.tsx" -o -name "page.jsx" 2>/dev/null | wc -l

# Count components
find . -path "*/components/*" -name "*.tsx" 2>/dev/null | wc -l
```

### 4. Project Asset Analysis

| Asset | Purpose |
|------|------|
| `package.json` | Project name, description |
| `README.md` | Project overview, tagline |
| `Plans.md` | Completed tasks (for release notes) |
| `CHANGELOG.md` | Changes (for release notes) |
| `.claude/memory/decisions.md` | Technical decisions (for architecture explainers) |

**Commands**:
```bash
# Extract project info
cat package.json | jq '{name, description, version}'

# Extract first paragraph of README
head -20 README.md
```

---

## Video Type Auto-Detection

### Detection Logic

```
Determine video type from analysis results:
    │
    ├─ CHANGELOG updated recently (within 7 days)
    │   └─ → Release notes video
    │
    ├─ Major structural changes (new directories added, etc.)
    │   └─ → Architecture overview
    │
    ├─ Many UI changes (components added/modified)
    │   └─ → Product demo
    │
    └─ Multiple conditions match
        └─ → Combined video (confirm with user)
```

### Detection Criteria

| Type | Condition |
|--------|------|
| **Release notes** | `git log --since="7 days ago"` contains a tag/release |
| **Architecture** | New `src/*/` directories, large refactor |
| **Product demo** | UI component additions/changes |
| **Default** | Product demo (most general purpose) |

---

## Output Format

Analysis results are output in the following format:

```yaml
project:
  name: "MyAwesomeApp"
  description: "Simplified task management"
  version: "1.2.0"

framework:
  primary: "Next.js"
  ui_library: "shadcn/ui"

features:
  - name: "Authentication"
    type: "auth"
    path: "src/app/(auth)/"
    provider: "Clerk"
  - name: "Dashboard"
    type: "dashboard"
    path: "src/app/dashboard/"
  - name: "API"
    type: "api"
    path: "src/app/api/"

stats:
  pages: 12
  components: 45
  api_routes: 8

recent_changes:
  changelog_updated: true
  last_release: "2026-01-20"
  major_changes:
    - "Added authentication flow"
    - "Dashboard improvements"

recommended_video_type: "release-notes"
confidence: 0.85
```

---

## Example Output

```
Analyzing project...

Analysis complete

| Item | Result |
|------|------|
| Project name | MyAwesomeApp |
| Framework | Next.js 14 |
| UI library | shadcn/ui |
| Pages | 12 |
| Components | 45 |

Detected features:
- Authentication (Clerk)
- Dashboard
- API (8 endpoints)

Recent changes:
- v1.2.0 release (3 days ago)
- Added authentication flow
- Dashboard improvements

Recommended video type: Release notes video
Reason: Recent release with major feature additions
```

---

## Notes

- Analysis is non-destructive (no files are modified)
- Completes in seconds even for large projects
- Undetected features can be added manually (via planner.md)
