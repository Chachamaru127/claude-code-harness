# Runtime Floor Secret-Read Allowlist

The Runtime Floor treats secret reads the same way it treats network egress:
explicit allowlist first, default deny. The egress side uses `isAllowlistedHost`
to require named hosts before outbound calls; the secret-read side requires named
project-local paths before a pipeline may read files that contain credentials,
tokens, keys, or other operator-provided secrets.

## Contract

- Project config should declare only the specific project-local file paths a run
  needs. `HARNESS_RUNTIME_FLOOR_SECRET_ALLOW` additionally accepts
  comma-separated path prefixes for operator-managed work roots.
- Empty strings, `*`, `**`, and `/` are invalid. Treat any all-open style
  declaration as deny, not as a wildcard.
- The effective allowlist is the union of:
  - `HARNESS_RUNTIME_FLOOR_SECRET_ALLOW`
  - `.claude-code-harness.config.json` `runtimefloor.secretAllow`
- If project config is missing, unreadable, malformed, or `runtimefloor.secretAllow`
  is not a string array, the config contribution is fail-safe empty. Secret reads
  remain denied unless the environment declaration provides a valid path.
- Project-config relative paths resolve under the project root.
  Project-config absolute paths outside the project root are invalid and
  ignored. Environment entries are lexical prefixes or globs and may name an
  operator-managed root outside the current project.

## Operator Flow

Before starting work, list the secret files the task will need and declare them
once in project config or in the environment. After that, the run should not stop
mid-task for repeated secret-read approvals, because the Runtime Floor can decide
from the predeclared contract.

Use project config when the same pipeline needs the same secret files across
runs:

```json
{
  "$schema": "./claude-code-harness.config.schema.json",
  "runtimefloor": {
    "secretAllow": [
      ".env.local",
      "secrets/pipeline.key"
    ]
  }
}
```

Use the environment for one-off CI or local runs. Separate multiple paths with
commas:

```bash
export HARNESS_RUNTIME_FLOOR_SECRET_ALLOW=".env.local,secrets/pipeline.key"
```

The two sources are additive. For example, if project config declares
`.env.local` and CI exports `secrets/pipeline.key`, both paths are allowed for
that run.

When adding a new work root, add that root as one comma-separated prefix in
`HARNESS_RUNTIME_FLOOR_SECRET_ALLOW`. Keep the trailing path separator so a
similarly named sibling does not match by prefix:

```bash
export HARNESS_RUNTIME_FLOOR_SECRET_ALLOW="/Users/alice/orca/workspaces/,/Users/alice/new-worktrees/"
```

The environment match is lexical. Use the same absolute or `~/` spelling that
the pipeline command uses. This declaration cannot disable the category:
`*`, `**`, and `/` are discarded.

## Pipeline Example

Declare the secrets before invoking the pipeline:

```bash
export HARNESS_RUNTIME_FLOOR_SECRET_ALLOW="secrets/deploy-token,config/private.env"
bash scripts/pipeline/deploy-preview.sh
```

Inside the pipeline, keep the read path identical to the declaration:

```bash
DEPLOY_TOKEN="$(cat secrets/deploy-token)"
set -a
. config/private.env
set +a
```

Prefer project-relative paths for project config. For the environment variable,
use a narrow file path or a trailing-separator work-root prefix. An absolute path
outside the project is valid only through the environment source.

## Bad Declarations

These examples must not grant access:

```bash
export HARNESS_RUNTIME_FLOOR_SECRET_ALLOW=""
export HARNESS_RUNTIME_FLOOR_SECRET_ALLOW="*"
export HARNESS_RUNTIME_FLOOR_SECRET_ALLOW="/"
```

```json
{
  "runtimefloor": {
    "secretAllow": ["*", "/Users/alice/.ssh/id_rsa"]
  }
}
```

The shell examples are all-open or empty declarations. The JSON example
combines a bare wildcard with an absolute path outside the project. Both JSON
entries are invalid, so the effective project-config contribution is empty.

## R04: Writes Outside the Project

R04 (`R04:confirm-write-outside-project`) distinguishes interactive sessions
from autonomous work:

- During `/work` or `/breezing`, `WorkMode` skips R04 confirmation for every
  path outside the project.
- During an interactive session without `WorkMode`, R04 skips only OS-managed
  scratch roots: `/tmp`, `/var/tmp`, `/private/tmp`, `/private/var/tmp`,
  `$TMPDIR`, `~/.cache`, and `~/Library/Caches`. Other external paths still ask.

R04 resolves symlinks before classifying a scratch path. If the final file does
not exist, it resolves the nearest existing ancestor and appends the missing
suffix. A scratch-path symlink that resolves outside the scratch roots does not
receive the skip. Resolution errors retain the `ask` result.

R02 and R03 run before R04. Their protected-path decisions remain in force even
when R04 would skip an OS scratch path or `WorkMode` would skip an external-path
confirmation.

## R05: Recursive Deletion Inside the Worktree

R05 (`R05:confirm-rm-rf`) uses the same dangerous-removal detector and target
extractor as the Runtime Floor. Outside `WorkMode`, R05 skips confirmation only
when every extracted target resolves inside `ProjectRoot`, which is the task
worktree. Both the target and project root are resolved through symlinks before
comparison. For a target that does not exist, R05 resolves the nearest existing
ancestor and then appends the missing suffix. The shared `find` target extractor
recognizes GNU global options and combined BSD `-E`, `-H`, `-L`, `-P`, `-X`,
`-d`, `-s`, and `-x`. A combined option containing `-L` retains `ask`. A BSD
`-f path`, `-fpath`, or combined `-Efpath` argument is collected as a search
root rather than discarded as an option value.

R05 retains `ask` when no target can be extracted, a target requires shell
expansion or can be appended by `xargs` or `parallel`, a relative target follows
a directory-changing command, a raw target contains a `..` component, the
project root is empty, symlink resolution fails, any resolved target is outside
the worktree, or `find` may follow descendant symlinks or read roots through
`-files0-from`. Dynamic command names and backtick command substitution also
retain `ask`. A removal nested in a general-purpose interpreter also retains
`ask`. R05 also retains `ask` when a non-removal shell segment precedes a
dangerous removal or an unknown launcher precedes `rm` or `find`. Such a segment
could replace a missing target ancestor with an external symlink after policy
evaluation but before deletion. Pipelines and background execution retain `ask`
because their concurrent segments can create the same race. Process substitution
through `<(` or `>(` is treated the same way. An executable path such as
`/custom/rm` and an environment assignment before the removal program are
indeterminate because they can replace or inject into the expected program.
File-descriptor duplication such as `2>&1` is parsed as redirection, not
background execution. Commands launched by `find -exec`, `-execdir`, `-ok`, or
`-okdir` receive the same executable-path, launcher, and environment checks.
These actions may launch a validated bare `rm`; nested `find` removal retains
`ask` because its roots are not part of the outer target extraction.
These execution-context checks use the same shell tokenizer as target
extraction, so line continuations, quoting, and escape concatenation cannot
change the command name seen by R05. A worktree-local symlink to an external
directory therefore does not receive the skip. `WorkMode` retains its existing
R05 bypass. Destruction outside the task worktree remains a hard deny in the
Runtime Floor, which runs before the policy rules and does not depend on
`WorkMode`.

Worktree-local approval is not a recovery guarantee. A linked worktree stores
its `.git` entry as a pointer to metadata in the main repository, so committed
objects and the staged index snapshot remain outside the deleted working tree.
Unstaged changes and untracked files, including generated artifacts and
in-progress files, have no recoverable Git copy and can be lost permanently.
