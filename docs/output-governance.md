# Output Governance Policy

Last updated: 2026-05-05

This document defines the safety policy for hooks and automated formatting processes
when handling Claude Code tool output.

## In a nutshell

`PostToolUse.hookSpecificOutput.updatedToolOutput` is not used by default.
When used, it is limited to opt-in redaction, compaction, or normalization, and must
never erase audit trails or review / test evidence.

## By analogy

Tool output is like security camera footage from a work site.
You may summarize for readability, but you must not cut out sections that constitute
evidence of an incident.

## Policy

| Item | Decision |
|------|---------|
| Default behavior | Do not return `updatedToolOutput` |
| Permitted uses | Explicitly opt-in redaction, compaction, normalization |
| Prohibited uses | Concealing test failures, review findings, security findings, or command errors |
| Audit trail | Preserve the storage location of the original output, the reason for the transformation, and the transformation rule |
| Output contract | stdout is a single JSON object. Explanatory logs go to stderr |

## Permitted transformations

### Redaction

Transformations that mask secret information.

Examples:

- Replace API keys with `<REDACTED:api-key>`
- Replace access tokens with `<REDACTED:token>`
- Replace personal data with `<REDACTED:personal-data>`

Prohibited:

- Deleting entire error lines
- Removing failing test names
- Removing file:line references from review findings

### Compaction

Transformations that shorten large outputs.

Examples:

- Collapse duplicate lines from success logs
- Summarize dependency install logs longer than 1000 lines
- Save the full output to a file and leave only `full_output_path` in the output

Prohibited:

- Omitting failure summaries
- Removing both the beginning and end of a stack trace
- Removing failing test locations from `pytest`, `vitest`, `go test`, or `npm test`

### Normalization

Transformations that smooth out display variations.

Examples:

- Replace absolute temp paths with stable placeholders
- Replace timestamps with `<TIMESTAMP>`
- Remove control characters from progress spinners

Prohibited:

- Changing the meaning of an exit code
- Making stderr appear to indicate success
- Replacing verdict words from reviews or tests

## JSON stdout contract

When a hook returns structured output to Claude Code, stdout must contain JSON only.
Human-readable logs go to stderr.

Minimal form:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse"
  }
}
```

When using `updatedToolOutput`:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "updatedToolOutput": "redacted or compacted tool output",
    "additionalContext": "Output was redacted with policy output-governance.v1. Full output is stored at .claude/state/audit/tool-output/<id>.log."
  }
}
```

Required conditions:

1. Do not mix anything other than JSON into stdout.
2. Confirm opt-in configuration before returning `updatedToolOutput`.
3. Save the full output or a recoverable audit record.
4. Record the reason and type of transformation in `additionalContext` or the audit record.
5. Do not delete review / test evidence.

## Harness default

Harness does not use `updatedToolOutput` by default.
The reason is that shortening the basis for reviews and tests without authorization makes
it impossible to later determine "was there actually a failure?" or "what was fixed?".

When needed, enable it explicitly per individual hook:

```json
{
  "outputTransform": {
    "enabled": true,
    "mode": "redact",
    "auditTrail": true
  }
}
```

This configuration name is a policy-level example; the implementation only needs to
have an equivalent opt-in mechanism.
The three key principles are: "do not modify by default", "modifications must be
traceable", and "do not erase quality evidence".
