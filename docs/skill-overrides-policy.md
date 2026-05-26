# Skill Overrides Policy (Phase 62.2.5)

> **Status**: Active (2026-05-07)
> **Scope**: Claude Code `2.1.129` added support for `skillOverrides` setting with 3 modes:
> `off` / `user-invocable-only` / `name-only`. This document defines the relationship with
> Harness skill governance and establishes appropriate defaults for enterprise / individual use.

## In one sentence

The `skillOverrides` 3 modes are a **policy for whether the model is allowed to override skills**.
Harness **sets nothing by default** (= CC default behavior), but recommends `name-only` for
enterprise governance.

## Analogy

Think of it as a policy for "how much the chef (model) can modify the recipe (skill)."
- `off`: No modifications allowed (only execute default skills)
- `user-invocable-only`: Only modifications that the user explicitly names are allowed
- `name-only`: Only modifications named explicitly are allowed; the model cannot pull in other recipes on its own
- Unset: CC default = some degree of modification allowed

## Meaning of the 3 modes

| Mode | Meaning | Use case |
|------|------|------|
| `off` | Completely disables model-driven skill activation | High-security enterprise environments; when you want to fully fix skill behavior |
| `user-invocable-only` | Only skills explicitly launched by the user with `/<skill>` are allowed; model auto-launch is prohibited | When you want to avoid the model implicitly calling skills |
| `name-only` | Only activation by skill name field match is allowed (description-based auto-trigger is suppressed) | When you want to prevent unexpected skill activation from fuzzy description matching |
| Unset (default) | CC default behavior. All features including description-based auto-trigger are enabled | Personal development, Harness default |

## Harness default policy

| Environment | Recommended mode | Reason |
|------|-----------|------|
| Individual / solo development | Unset (CC default) | Description-based auto-trigger is convenient |
| Team (small) | Unset + skill manifest audit | Visualize skill list with `scripts/generate-skill-manifest.sh` |
| Enterprise governance | **`name-only`** | Suppress description fuzzy matching; allow only explicit skill launches |
| Education / training sessions | `user-invocable-only` | Prohibit model auto-launch; have learners actively choose skills |

`harness-init`-generated templates **do not include a default** (= respecting CC default).
Enterprise users explicitly set this in `.claude/settings.json` or `.claude/settings.local.json`.

## Relationship with skill manifest

Phase 59.1.2 updated `scripts/generate-skill-manifest.sh` to output metadata such as `kind` /
`purpose` / `trigger` / `shape` / `role` / `base` / `pair` / `owner` in a machine-readable format.

In a `skillOverrides: name-only` environment, CC only matches on the skill's **name**.
Description-based auto-trigger is disabled.
Therefore, skill names should be **semantically explicit** (`harness-work` / `harness-review`, etc. with verb + noun).

| Skill naming | Behavior in name-only mode |
|-----------|----------------------|
| `harness-work` | Explicit launch OK (`/harness-work`) |
| `breezing` (alias) | Explicit launch OK (`/breezing`) |
| `harness-loop` | Explicit launch OK (`/harness-loop`) |
| Abstract / generic name (e.g., `helper`) | Avoid due to name collision risk |

## Configuration examples

### Enterprise governance (`.claude/settings.json`)

```json
{
  "skillOverrides": "name-only"
}
```

### Disable individually (specific environments only)

```json
{
  "skillOverrides": "off"
}
```

This completely stops implicit skill invocation in automated batch execution.

### Default (not recommended to set explicitly)

Since there is no mode for explicitly specifying `default`, keep CC default by leaving it unset.

## Handling in tests / `harness-init`

- `tests/test-settings-baseline.sh` (considered for creation in Phase 62.1.4) **allows but does not enforce** the presence of `skillOverrides` (to not prevent `default` in personal development)
- `harness-init` does **not** add `skillOverrides` to generated settings
- When enterprise governance is needed during migration/customization, refer to this document

## Acceptance criteria (Phase 62.2.5 DoD)

- [x] The meaning of the 3 modes is described in a table
- [x] Recommended defaults are fixed per environment (individual / team / enterprise / education)
- [x] Enterprise governance use case is explicitly stated
- [x] Relationship with Phase 59.1.2 skill manifest is documented
- [x] Decision on whether `harness-init` includes a default is recorded (= does not include)

## Related docs

- Phase 59.1.2 (`scripts/generate-skill-manifest.sh`) — skill metadata automation
- Phase 58.2.3 (`docs/upstream-followups-phase58-2026-05-03.md`) — handling as setup / docs candidate
- Claude Code 2.1.129 CHANGELOG: `skillOverrides` setting now works with `off`, `user-invocable-only`, `name-only` options
