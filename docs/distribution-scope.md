# Distribution Scope

最終更新: 2026-05-14

この文書は `claude-code-harness` の「repo には存在するが、Claude Code plugin の配布 payload には載せないもの」を明文化する scope table です。
`Plans.md`、README、`.gitattributes`、配布スクリプト、検証スクリプトで迷ったら、この表を正本として扱います。

## Scope Table

| Path | Status | Why it exists | Enforcement signal |
|------|--------|---------------|--------------------|
| `.claude-plugin/` | Distribution-included | Claude Code plugin manifest / hooks / settings | `claude plugin validate`, `test-distribution-archive.sh` |
| `bin/harness*` | Distribution-included | Go-native guardrail / lifecycle runtime | `validate-plugin`, `go test`, archive required entries |
| `skills/` | Distribution-included | Claude Code 用 primary skill surface | `validate-plugin`, mirror sync checks |
| `agents/` | Distribution-included | worker / reviewer / advisor | `validate-plugin`, agent frontmatter tests |
| `hooks/`, `monitors/` | Distribution-included | 実行時 hook / monitor definitions | `hooks/hooks.json`, `validate-plugin` |
| `output-styles/` | Distribution-included | Claude Code output style | `plugin.json`, archive required entries |
| `templates/`, `workflows/` | Distribution-included | project init / rules / workflow templates | `check-consistency.sh`, template registry checks |
| `scripts/` runtime files | Distribution-included | hook handlers, setup, sync, review, plan, loop runtime | `validate-plugin`, runtime hook tests |
| `assets/`, public `docs/` | Distribution-included | README assets and public user documentation | README claim drift checks |
| `commands/` | Compatibility-retained | 旧 slash command 資産。存在する場合のみ検証 | `validate-plugin` |
| `codex/`, `opencode/`, `skills-codex/` | Source-repo mirror only | 代替クライアント向け mirror / setup 導線。Claude plugin archive には載せない | `test-codex-package.sh`, `opencode-compat.yml`, `.gitattributes` |
| `go/`, `tests/`, `benchmarks/`, `.github/` | Development-only and distribution-excluded | source / CI / benchmark / validation | `.gitattributes`, `test-distribution-archive.sh` |
| `.claude/`, `.cursor/`, `CLAUDE.md`, `AGENTS.md`, `Plans.md` | Development-only and distribution-excluded | repo-local agent context, local plans, editor setup | `.gitattributes`, `test-distribution-archive.sh` |
| `.private/` | Local-only and distribution-excluded | `skills/` 直下に置くと `claude --plugin-dir .` の inventory に出る private/dev-only skills の退避先 | `.gitignore`, `test-public-plugin-inventory.sh` |
| `scripts/ci/`, `scripts/evidence/`, `scripts/sandbox-test/` | Development-only and distribution-excluded | CI helpers, evidence fixtures, local sandbox examples | `.gitattributes`, `test-distribution-archive.sh` |
| `mcp-server/` | Development-only and distribution-excluded | オプション機能。repo では開発・調査用に残すが配布 payload には含めない | `.gitignore`, `.gitattributes`, CHANGELOG history |
| `harness-ui/`, `harness-ui-archive/`, `remotion/` | Development-only and distribution-excluded | optional UI / video experiments and archives | `.gitignore`, `.gitattributes`, CHANGELOG history |
| `docs/research/`, `docs/private/`, `docs/notebooklm/`, `docs/slides/`, `docs/presentation/`, `docs/social/` | Private or generated reference | 調査記録、公開前の下書き、生成中間物 | `.gitignore`, `.gitattributes`, `test-distribution-archive.sh` |

## Current Decisions

- `commands/` は削除済み扱いにしない。現在は **Compatibility-retained**。
- `codex/` / `opencode/` は repo 上の mirror として検証対象だが、Claude Code plugin archive からは除外する。
- `.claude/` / `.cursor/` / `CLAUDE.md` / `AGENTS.md` / `Plans.md` は repo-local context であり、plugin payload ではない。
- private/dev-only skills は `skills/` 配下に置かない。`.gitignore` されていても `claude --plugin-dir .` の local inventory には露出するため、`.private/skills/` など public plugin surface の外へ退避する。
- `mcp-server/` は削除済み扱いにしない。現在は **Development-only and distribution-excluded**。
- `scripts/hook-handlers/memory-bridge.sh` と `memory-*.sh` は local bridge でも **Distribution-included**。hook が参照するため、repo に tracked されている必要がある。
- README や `Plans.md` で「削除」と書く場合は、実際に tree から消えたときだけ使う。
- 「配布外」「互換維持」「開発専用」はこの文書のラベルに合わせて使い分ける。

## Update Rule

次のいずれかが起きたら、この表も同じ PR / commit で更新すること。

1. README の architecture / install / compatibility 説明を変更したとき
2. `.gitignore` や build script の除外規則を変更したとき
3. `commands/` や `mcp-server/` など、存在理由が誤解されやすいディレクトリの扱いを変えたとき
4. `.gitattributes` の `export-ignore` や `tests/test-distribution-archive.sh` の required / forbidden list を変更したとき
