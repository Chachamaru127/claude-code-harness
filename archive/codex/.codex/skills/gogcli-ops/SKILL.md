---
name: gogcli-ops
description: "Use gogcli for Google Workspace CLI operations (Drive/Sheets/Docs/Slides). Trigger when a user asks to check, list, search, export, read, or update Google files via gogcli; when a Google URL/ID needs parsing; when auth/account selection or safe read-only workflows are needed; or when troubleshooting gogcli access/errors. Do NOT load for: general file operations, non-Google cloud storage, or standard shell commands."
description-en: "Use gogcli for Google Workspace CLI operations (Drive/Sheets/Docs/Slides). Trigger when a user asks to check, list, search, export, read, or update Google files via gogcli; when a Google URL/ID needs parsing; when auth/account selection or safe read-only workflows are needed; or when troubleshooting gogcli access/errors. Do NOT load for: general file operations, non-Google cloud storage, or standard shell commands."
description-ja: "gogcli でGoogle Workspace操作（Drive/Sheets/Docs/Slides）。ユーザーがGoogleファイルの確認・検索・エクスポート・読み取り・更新をgogcliで依頼する時に使用。Trigger when a user asks to check, list, search, export, read, or update Google files via gogcli; when a Google URL/ID needs parsing; when auth/account selection or safe read-only workflows are needed; or when troubleshooting gogcli access/errors. Do NOT load for: general file operations, non-Google cloud storage, or standard shell commands."
allowed-tools: ["Read", "Bash", "Grep", "Glob"]
disable-model-invocation: true
---

# Gogcli Ops

## Overview
Standardize gogcli usage: verify auth, resolve IDs from URLs, default to read-only checks, then run the minimum command needed.

## Quick start
- Confirm gogcli is available: `gog --version`
- List accounts and pick one explicitly if more than one: `gog auth list`
- Resolve URL to ID with `python3 scripts/gog_parse_url.py "<url-or-id>"`
- Run a read-only metadata command first (Drive/Sheets/Docs/Slides)

## Workflow decision tree
1. Identify target type: `sheet | doc | slide | file | folder | id | unknown` via `scripts/gog_parse_url.py`.
2. Choose the smallest read-only command to confirm access:
   - Sheets: `gog sheets metadata <spreadsheetId>`
   - Docs: `gog docs info <docId>`
   - Slides: `gog slides info <presentationId>`
   - Drive file/folder: `gog drive get <fileId>` or `gog drive permissions <fileId>`
3. Only proceed to write operations (update/append/move/share/delete) after explicit user confirmation.

## Core tasks

### Auth and account selection
- Show stored accounts: `gog auth list`
- Show auth configuration: `gog auth status`
- Add/authorize account: `gog auth add <email>`
- Always use `--account <email>` when multiple accounts exist.

### Resolve IDs from URLs
- Parse a URL or ID:
  - `python3 scripts/gog_parse_url.py "<url-or-id>"`
- If output type is `unknown`, ask for a direct ID or a different URL.

### Drive (files/folders)
- List root or a folder: `gog drive ls`
- Search by query: `gog drive search "<query>"`
- Get metadata: `gog drive get <fileId>`
- Download/export: `gog drive download <fileId>`
- Permissions check: `gog drive permissions <fileId>`

### Sheets
- Metadata: `gog sheets metadata <spreadsheetId>`
- Read values: `gog sheets get <spreadsheetId> <range>`
- Export: `gog sheets export <spreadsheetId>`
- Write operations (update/append/clear/format): require explicit confirmation and exact range.

### Docs
- Metadata: `gog docs info <docId>`
- Read text: `gog docs cat <docId>`
- Export: `gog docs export <docId>`

### Slides
- Metadata: `gog slides info <presentationId>`
- Export: `gog slides export <presentationId>`

### Output modes
- Use `--plain` for stable TSV output.
- Use `--json` when a caller wants structured output.
- Use `--no-input` in non-interactive flows to avoid hanging.

## Error handling
- 403/404: verify account (`gog auth list`), check permissions (`gog drive permissions <fileId>`), and confirm the ID.
- If access fails, request the user to share the file with the selected account or provide the correct account.

## Resources
- See `${CLAUDE_SKILL_DIR}/references/gogcli-cheatsheet.md` for a compact command list.
- Use `scripts/gog_parse_url.py` to normalize URLs into IDs before running commands.
