# Self-Audit Rule

## Integrity Detection

A `<!-- harness-integrity: ... -->` marker is present at the end of CLAUDE.md.
Detection trigger: At `/harness-review` execution or at the start of a diagnostic session,
**use the Read tool to inspect the end of CLAUDE.md** and check the following:

1. Has the number of deny entries in `.claude-plugin/settings.json` **decreased** since the last audit?
2. Has the Feature Table been directly appended to CLAUDE.md? (Only pointers are correct)
3. If there is a discrepancy, run a diagnosis with `/harness-review`

Only the human owner updates the marker. Agents only read and detect.

## Why This Rule Is Necessary

The deny rules in settings.json are "chains that constrain the agent itself."
If the number of chains decreases, there may be an unintended loosening or tampering.
By detecting a decrease in count rather than the absolute number,
legitimate additions are tolerated while any loosening is captured.
