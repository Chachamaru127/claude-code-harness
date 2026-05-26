# Gogcli quick commands (v0.9.0)

## Auth and account
- List stored accounts:
  - `gog auth list`
- Show auth status and keyring backend:
  - `gog auth status`
- Add/authorize an account:
  - `gog auth add <email>`
- Use a specific account for any command:
  - `gog <area> <cmd> --account <email>`

## Output modes
- Machine-readable TSV:
  - `--plain`
- JSON output:
  - `--json`
- Non-interactive:
  - `--no-input` (fails instead of prompting)

## Drive
- List files in a folder (default: root):
  - `gog drive ls`
- Search:
  - `gog drive search "<query>"`
- Get metadata:
  - `gog drive get <fileId>`
- Download (exports Google Docs formats):
  - `gog drive download <fileId>`
- Permissions:
  - `gog drive permissions <fileId>`

## Sheets
- Spreadsheet metadata:
  - `gog sheets metadata <spreadsheetId>`
- Read a range:
  - `gog sheets get <spreadsheetId> <range>`
- Export:
  - `gog sheets export <spreadsheetId>`

## Docs
- Metadata:
  - `gog docs info <docId>`
- Export:
  - `gog docs export <docId>`
- Plain text:
  - `gog docs cat <docId>`

## Slides
- Metadata:
  - `gog slides info <presentationId>`
- Export:
  - `gog slides export <presentationId>`

## URL parsing helper (this skill)
- Extract type and ID:
  - `python3 scripts/gog_parse_url.py "<url-or-id>"`
  - Output format: `<type>\t<id>` where type is `sheet|doc|slide|file|folder|id|unknown`
