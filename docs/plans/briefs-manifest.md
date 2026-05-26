# Optional Briefs and Skill Manifest

`harness-plan create` attaches a brief only when needed. A brief does not replace Plans.md; it is a short supporting document that locks in the preconditions for a specific implementation task.

The project spec SSOT is treated as the authoritative source above any brief. A brief locks in the short-form preconditions for individual tasks such as screens or APIs, while the spec SSOT locks in the acceptance criteria for the project as a whole.

Details: `docs/plans/spec-ssot.md`

## Design Brief

For tasks that involve UI, create a `design brief`.

Minimum required content:

- What needs to be achieved
- Who will use it
- Key screen states
- Visual and interaction constraints
- Acceptance criteria

## Contract Brief

For tasks that involve an API, create a `contract brief`.

Minimum required content:

- What is received / returned
- Input validation rules
- Failure behavior
- External dependencies
- Acceptance criteria

## Skill Manifest

`scripts/generate-skill-manifest.sh` converts the `SKILL.md` frontmatter in the repo into stable JSON.

Use cases:

- Auditing the skill surface
- Comparing across mirrors
- Input for automated docs generation

The output includes the following fields:

- `name`
- `description`
- `do_not_use_for`
- `allowed_tools`
- `argument_hint`
- `effort`
- `user_invocable`
- `surface`
- `related_surfaces`

`related_surfaces` also includes mirror information such as `skills`, `codex/.codex/skills`, and `opencode/skills`.

## Example

```bash
scripts/generate-skill-manifest.sh --output .claude/state/skill-manifest.json
```
