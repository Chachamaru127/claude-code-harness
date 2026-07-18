# Known Limitations

Issues observed in real-world Harness usage where the root cause sits outside
Harness's control. This file documents the workaround that Harness applies and
the trigger condition under which the limitation can be revisited.

---

## Multi-host safety is not uniform (Phase 111)

### Symptom

Operators may assume Claude Code, Codex CLI, Cursor, and Grok all stop dangerous
actions the same way because each has an install route.

### Root cause

Hosts differ in hook coverage and containment:

| Host | Pre-action stop | Containment notes |
|------|-----------------|-------------------|
| Claude Code | Strong multi-tool PreToolUse | Primary product floor |
| Codex CLI | Bash-only PreToolUse floor + post quality/merge gates | non-Bash not hard-denied on hook path |
| Cursor | preToolUse can deny (live-proven) | **No traditional FS jail**; allowlists are best-effort; fail-open on non-exit-2 |
| Grok | hookcodec HostGrok uses Claude-compatible deny envelope | Floor membership is codec-level; project hooks need `.grok/hooks` wiring |

### Mitigation Harness applies

1. Public tier wording: 正式対応 only for EN `supported` (Claude today).
2. Capability matrix + hardening-parity document strength differences.
3. H1–H8 bar for any future public promotion (`docs/spec/planning-and-host-adapter.md`).

### Revisit when

Live CI workflow smoke (plan→artifact with host CLI) is green and host-specific
containment limits are accepted in README for a promotion PR.

---

## cyber-safeguard interruption during security review (#172)

### Symptom

When `claude-code-harness:reviewer` (Opus 4.7 era) reviews a change with security
implications, it can detect an issue and then stop mid-output with a message like
"This request triggered cyber-related safeguards." The verdict JSON is never
produced. Downstream skills (`harness-release` Review Gate, commit guard, etc.)
see no `review-result.json` and the workflow halts.

### Root cause

This is a model-side safeguard in Anthropic's Opus 4.7-era product behavior. The
model can interrupt itself when it detects that its own output is moving toward
exploit code, attack PoC, or content that resembles offensive-security tooling.
Harness sits on top of the model and cannot turn the safeguard off; that would
require an inference-side opt-out that Harness does not control.

### Mitigation Harness applies

1. **Reviewer prompt has been narrowed** to record security findings as neutral
   facts (vulnerability type / location / severity), not as exploit code or PoC.
   See `agents/reviewer.md` § "Security finding 記述ルール".
2. CVE / CWE / OWASP identifiers are referenced by ID only; attack steps and
   bypass techniques are not expanded into the body.
3. Mitigation guidance describes the fix direction (for example, "use
   parameterized queries", "escape input"), not the attack.

This narrows the surface that triggers the safeguard but does not eliminate it.
The model can still classify a paragraph as too close to offensive content even
when written under these rules.

### Workarounds for operators

When the safeguard fires anyway:

- **Switch to Opus 4.8** for security-heavy PRs. The newer model has a different
  safeguard calibration. Set `--model claude-opus-4-8` or pin the reviewer model
  via your settings.
- **Escalate security-only PRs to manual review**. Harness's automated reviewer
  is not the appropriate gate for changes whose entire purpose is exploit
  research or red-team tooling.
- **Re-run with the prompt narrowed manually**. If only one finding triggered
  the safeguard, rerun the reviewer with a session instruction that says "Skip
  the PoC sketch, just list the file:line and CWE id."

### Trigger to revisit

- Anthropic ships a documented opt-out or per-prompt suppression for the
  cyber-safeguard.
- A successor model documents the safeguard as removed for security-review use
  cases.
- A pattern emerges where the safeguard fires on findings that follow the
  current "neutral facts only" rule; that would mean the rule is not tight
  enough and the prompt needs another iteration.

### Related

- Issue [#172](https://github.com/Chachamaru127/claude-code-harness/issues/172)
- `agents/reviewer.md` § Security finding 記述ルール
