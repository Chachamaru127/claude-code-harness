# Switch the Claude plugin to `harness`

The Claude plugin ID changes from `claude-code-harness` to `harness` because Claude Code rejects the old name as reserved. The GitHub repository and marketplace remain `Chachamaru127/claude-code-harness` and `claude-code-harness-marketplace`.

[日本語](plugin-rename_ja.md)

## Before switching

These are terminal commands, not messages inside an assistant conversation. End active Harness work and close the old Claude session first. Use a Claude Code version that supports the scope flags shown by `claude plugin disable --help` and `claude plugin install --help`; they were checked on 2.1.296.

Run `claude plugin list` and find every scope where the old plugin is enabled. A scope is where the installation applies: `user` is your account, `project` is shared project configuration, and `local` is personal configuration for one project. Work from the project directory for project/local changes. Changing shared project configuration affects teammates; agree on that switch with them.

## Current Claude Code: follow the rename

Claude Code 2.1.193+ follows the marketplace's `renames` map. It changes old IDs in user, project, and local enabled-plugin/configuration keys; managed settings still need an administrator. See the [official rename contract](https://code.claude.com/docs/en/plugins/host-marketplace#migrate-users-with-a-renames-map).

After the renamed release is published, run in a terminal:

```bash
claude plugin marketplace update claude-code-harness-marketplace
claude plugin install harness@claude-code-harness-marketplace --scope user
claude plugin list
```

Use the old installation's scope (`project` or `local` instead of `user` where applicable). Check all scopes afterwards. Keep deliberate disabled settings disabled; enable the new plugin only if you want it to run. For git/URL marketplaces, installing the new ID once fills its cache. Start a fresh Claude session; `/reload-plugins` can reload supported components, but restarting gives a clear session boundary.

Check `/plugin` shows the intended new ID active and no old copy still active. Run `/harness-setup`, then a small `/harness-plan` request. For a name clash, use `/harness:harness-plan`. Review proposed project edits before accepting them.

## Older builds or manual recovery

Close active work first. For each scope where the old ID remains installed, preserve its data when removing it, then install the new ID in that same scope:

```bash
claude plugin uninstall claude-code-harness@claude-code-harness-marketplace --scope user --keep-data
claude plugin install harness@claude-code-harness-marketplace --scope user
claude plugin list
```

Replace `user` with the actual scope. If your CLI does not support `--keep-data`, stop; do not run an uninstall that deletes data. Follow the supported plugin-manager route after arranging a verified backup. Do not activate both IDs as a workaround for an install failure.

## Data and other tools

Project `Plans.md`, `.claude/state/`, `.claude-code-harness.config.yaml`, and harness-mem storage keep their paths. The plugin-owned directory changes with its ID. Harness uses `${CLAUDE_PLUGIN_DATA}/state.db` and `livemsg.db` when that variable is set, so the new ID can start with fresh plugin-owned state even while old data is retained. The rename map migrates configuration keys, not these databases. No automatic database transfer is promised. Finish active sessions before switching; inspect any pending work and approvals rather than copying live databases or restoring old approvals blindly.

For Codex, Cursor, and Grok, the package manifests also use `harness` because they share this marketplace identity. Their installation methods and support tiers stay the same. Disable/remove the old plugin through the host's supported manager before installing the new package; verify only one copy is active. The copied Cursor/Grok install directories now end in `harness`; their build storage and project configuration keep existing names. CLI skill-copy installations through `setup-codex.sh --user` keep the same skill names and paths.

Do not manually delete caches, credentials, or memory as part of the switch. Rollback to the reserved old name is not guaranteed on newer Claude Code. Local validation of this candidate does not mean the renamed release has been published.
