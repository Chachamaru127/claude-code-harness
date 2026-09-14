---
name: agent-run-forensics
description: "Answers questions about an agent run that already happened by reading its recording rather than the agent's memory: which step changed a file, why a command ran, where the build broke. Use when investigating a past agent session, reproducing a failure someone reported, or turning a failed session into an offline regression test. Do NOT load for: planning the next change, reviewing a diff, or debugging code no agent ran."
description-en: "Answers questions about an agent run that already happened by reading its recording rather than the agent's memory: which step changed a file, why a command ran, where the build broke. Use when investigating a past agent session, reproducing a failure someone reported, or turning a failed session into an offline regression test. Do NOT load for: planning the next change, reviewing a diff, or debugging code no agent ran."
allowed-tools: ["Read", "Grep", "Bash", "Task"]
user-invocable: true
context: fork
argument-hint: "[explain|reproduce|compare]"
---

# /agent-run-forensics — Answer From the Recording, Not From Memory

## When to Use

- A past agent run changed a file, ran a command, or broke a build, and nobody knows which step did it.
- A colleague reports a failure you cannot reproduce, and you do not have their key or their machine.
- A failed session should become a regression test rather than a paragraph in an issue.
- Someone is treating an agent's own explanation as a conclusion and you need to know whether evidence supports it.

**Do not use** for planning the next change, reviewing a diff, or debugging code that no agent ran. This skill only reads runs that already happened. If there is no recording, say so and offer to start one — do **not** substitute recall.

## Orientation

An agent asked "why did you do that?" answers from a summary of its own context window. The tool results, the shell exit codes, and the files that changed without anyone mentioning them are already gone from it. The answer comes out fluent, confident, and occasionally wrong — worse than "I don't know", because it gets believed and written into a commit message. A transcript is no better: it is the conversation's projection of the run, not the run.

## Inputs

- A run identifier, or "the most recent run".
- The specific thing to explain: a file change, a command, a build failure.
- Whether the ask is explanation, reproduction, or model comparison.
- The acceptable blast radius for a replay (may it reach a database, a container, another host?).

## Prerequisites

```bash
node --version                          # Node 20+
which orca || npm install -g orcareplay # exposes an MCP server; register it as `orca`
orca list                               # at least one run, or there is nothing to read
```

## Protocol

1. **Confirm a recording exists.** Run `orca list`. If empty, state that plainly and offer `orca record <agent>`; stop here rather than reconstructing from memory.
2. **Classify the question.**
   - *What happened?* → `orca_show_run`: model turns with token counts and stop reasons, tool calls with arguments and results, shell commands with exit codes, files changed.
   - *Why did this happen?* → `orca_graph` with `to: <event seq>` — **only** the causal chain to that one event. Reading a 200-event timeline and reasoning over it is slower, costs more context, and invites the confident guess this skill exists to prevent.
   - *Does it still reproduce?* → `orca_replay`.
   - *Would another model do better?* → `orca_checkpoints`, then `orca_compare`.
3. **Label every causal claim.** Each edge is `recorded` (the recorder watched it) or `inferred` (derived at query time from a named rule). Never merge them:
   - ✅ "The trace shows the `rm` at step 14 removed it."
   - ✅ "This looks like the `rm` at step 14, going by timing — that edge is inferred, not recorded."
   - ❌ "Step 14 removed it." (when the edge was inferred)
4. **Before any replay, read the recorded shell commands.** A replay is not a dry run: the agent process runs again, so every command it issued runs again. List what will repeat before running anything.
5. **Replay into a scratch worktree.** Otherwise the recorded file tree is restored over the working tree; uncommitted work is absent meanwhile and stays absent if the replay is interrupted.
6. **Report the verdict line verbatim**, then the residual uncertainty.

## Fringe Cases

- **Empty trace.** Not "nothing happened" — nothing was captured, usually an agent that pins its own provider origin and reads no base-URL variable.
- **`reused=3/5` is usually not a partial failure.** Harnesses make calls for themselves (a quota probe, a session-naming request) and a replay does not repeat them. This one costs people twenty minutes of debugging a non-problem.
- **A typed-in session replays approximately.** Prompts entered interactively were never on the wire and are recovered from the harness transcript; the replay output says which is which.
- **Vision agents never match byte for byte.** A re-rendered screenshot is different bytes, so expect a divergence rather than `exact`.
- **Node projects.** A scratch worktree is built from tracked files, so `node_modules` is absent and the run fails to start; replay in place for those.

## Quality Gates

- [ ] `orca list` was run and a recording was confirmed before any claim about a past run.
- [ ] A "why" question used the causal chain, not the whole timeline.
- [ ] Every causal claim is labelled `recorded` or `inferred`, with the rule named for each inferred one.
- [ ] The recorded shell commands were read before the first replay, and anything touching a database, container, package manager or another host was flagged.
- [ ] The replay ran in a scratch worktree, or the reason it could not is stated.
- [ ] The verdict line (`reused` / `exact` / `divergences` / `unmatched`) is quoted verbatim.
- [ ] No matching replay was described as proof of determinism, and no blocked replay was described as a sandbox.
- [ ] Any model comparison obtained disclosure, side-effect and cost approval **separately**, and graded with a command the repository declares — never `npx <tool>`.

## Exit Protocol

Deliver in this order and stop:

1. **Conclusion** — one sentence answering the question asked.
2. **Evidence** — the specific events (sequence numbers, types, key arguments, exit codes).
3. **Source labels** — `recorded` / `inferred` per claim.
4. **Reproduction**, if replayed — the verdict line verbatim, plus which side effects actually repeated.
5. **Residual uncertainty** — what the recording does not cover, and how external state may differ today.

If the recording cannot answer the question, say that and name what would — a new recording, a different run, or a live reproduction. Do not close the gap with a plausible reconstruction.
