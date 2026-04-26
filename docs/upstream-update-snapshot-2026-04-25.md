# Claude Code / Codex upstream snapshot - 2026-04-25

この snapshot は、2026-04-25 時点の公式 upstream を確認し、Claude Code Harness に直接取り込むべき項目と、自動継承 / 将来タスクに留める項目を分解したもの。

確認日:

- 2026-04-25 (Asia/Tokyo)

一次情報:

- Claude Code docs changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code GitHub changelog: <https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md>
- OpenAI Codex releases: <https://github.com/openai/codex/releases>
- OpenAI Codex `rust-v0.124.0` release tag: <https://github.com/openai/codex/releases/tag/rust-v0.124.0>

確認対象:

- Claude Code `2.1.119`
- Codex `0.124.0` stable
- Codex `0.125.0-alpha.2` pre-release

分類:

- `A: 検証強化`: Harness の実装を変えず、snapshot / Feature Table / CHANGELOG / tests で upstream 追従判断を固定する。
- `C: 自動継承`: Claude Code / Codex 本体の改善をそのまま受ける。Harness wrapper を重ねると二重責務になるもの。
- `P: 将来タスク`: 今回は実装しないが、Plans に次回候補として残す。alpha や仕様未安定の項目は推測実装しない。

## Version-by-version breakdown

| Version | Upstream item | どうよくなる | Category | Harness surface | Harness action |
|---------|---------------|--------------|----------|-----------------|----------------|
| Claude Code 2.1.119 | `/config` settings persist to `~/.claude/settings.json` and join project/local/policy precedence | 手元の theme / editor / verbose 設定が再起動後も残り、managed settings との優先順位が分かりやすくなる | P | setup / managed settings docs | Phase 53 の plugin-managed-settings policy と重複するため、次回 setup docs の precedence 表へ統合する |
| Claude Code 2.1.119 | `prUrlTemplate` customizes footer PR badge URLs | GitHub Enterprise / GitLab / Bitbucket review URL を使うチームでも footer から正しいレビュー面へ飛びやすい | P | review / release docs | GitHub 固定の PR guidance を点検し、企業 git host 対応として後続候補に残す |
| Claude Code 2.1.119 | `--print` honors agent `tools:` and `disallowedTools:` frontmatter | CI / script 実行でも interactive と同じ tool 制限が効きやすい | A | upstream snapshot / tests | `--print` の frontmatter parity を Phase 56 で記録し、将来 CI review runner の gate 候補にする |
| Claude Code 2.1.119 | `--agent <name>` honors `permissionMode` for built-in agents | main-thread agent 実行でも built-in agent の permission 方針が反映されやすい | P | agents / permission docs | Phase 53 の `--agent` + `mcpServers` follow-up と一緒に agents audit へ残す |
| Claude Code 2.1.119 | `PostToolUse` and `PostToolUseFailure` inputs include `duration_ms` | hook 側で tool 実行時間を測り、遅い処理の診断に使える | P | hooks / session monitor | Session Monitor や hook telemetry に取り込む価値が高いが、既存 hook JSON shape を変える前に別 task 化する |
| Claude Code 2.1.119 | OTEL `tool_result` / `tool_decision` include `tool_use_id`, and `tool_result` includes `tool_input_size_bytes` | trace と tool input size を紐付けやすくなる | P | telemetry docs | Harness telemetry を扱う時の後続候補。現状は schema wrapper を追加しない |
| Claude Code 2.1.119 | Status line stdin JSON includes `effort.level` and `thinking.enabled` | status line から思考強度や thinking 状態を表示できる | P | statusline / session monitor | Harness status line に載せる価値があるが、UI 表示方針を別 task にする |
| Claude Code 2.1.119 | Subagent and SDK MCP server reconfiguration connects servers in parallel; MCP OAuth / headers / client secret / env placeholder fixes | MCP の再設定と認証が安定する | C | MCP runtime | 本体改善を自動継承。Harness が reconfiguration wrapper や OAuth workaround を追加しない |
| Claude Code 2.1.119 | `blockedMarketplaces` correctly enforces `hostPattern` and `pathPattern` entries | managed marketplace policy の抜け道が減る | C | managed settings | Phase 53 policy の本体修正として自動継承 |
| Claude Code 2.1.119 | Glob/Grep tools no longer disappear on native macOS/Linux when Bash is denied; auto mode no longer overrides plan mode | Bash deny / plan mode 下の挙動が安定する | C | permissions / search / Auto Mode | 本体修正を自動継承。Harness は Bash deny を緩めず、Auto Mode guidance も増やさない |
| Codex 0.124.0 | TUI quick reasoning controls and model-upgrade reasoning reset | TUI から reasoning level を素早く調整でき、model 変更時の stale reasoning を避けやすい | C | Codex TUI | 本体 UX として自動継承。Harness skill frontmatter は変更しない |
| Codex 0.124.0 | App-server sessions manage multiple environments and choose environment / working directory per turn | 複数 workspace / remote environment を同じ session で扱いやすい | P | Codex workflow / branch policy | Phase 56 follow-up として multi-environment branch/workdir policy を切る |
| Codex 0.124.0 | First-class Amazon Bedrock support for OpenAI-compatible providers with AWS SigV4 auth | Codex 側の Bedrock 利用が公式 provider として扱いやすい | C | Codex provider docs | Phase 53 provider policy を自動継承で維持し、必要時に docs refresh |
| Codex 0.124.0 | Remote plugin marketplaces can be listed and read directly | remote plugin source の確認がしやすい | P | plugin mirror policy | Harness plugin mirror / marketplace source policy の後続候補にする |
| Codex 0.124.0 | Hooks are stable, configurable inline in `config.toml` and managed `requirements.toml`, and can observe MCP tools, `apply_patch`, and long-running Bash | Codex 側でも stable hook policy を組める | P | Codex hooks / guardrails / tests | Claude Code hooks と Codex hooks の parity を別 task に切る。推測で config.toml を変えない |
| Codex 0.124.0 | Eligible ChatGPT plans default to Fast service tier unless explicitly opted out | 対象 plan で応答が速くなる | C | runtime UX | 本体 / plan 側の挙動として自動継承。Harness が service tier を固定しない |
| Codex 0.124.0 | Permission-mode drift, `wait_agent` queued mailbox timeout, relative stdio MCP command resolution, managed config startup edge cases | permissions / subagent wait / MCP startup / managed config が安定する | C | Codex runtime | 本体修正を自動継承。Harness worker prompt や setup defaults は変更しない |
| Codex 0.125.0-alpha.2 | Pre-release tag exists, release body is thin | 次の stable で入る変更候補を早く検知できる | P | upstream watch | alpha から推測実装しない。stable release か十分な release notes が出たら再確認 |

## Phase 56 follow-up candidates

| Follow-up | Why it matters | Suggested Plans owner |
|-----------|----------------|-----------------------|
| Claude Code `PostToolUse.duration_ms` を Session Monitor / hook telemetry に入れるか検討 | 遅い hook / tool 実行を user-facing に説明できる | hooks / session monitor |
| Claude Code status line `effort.level` / `thinking.enabled` を Harness status line に載せるか検討 | 長時間作業で「今どの強さで考えているか」を見える化できる | statusline / session monitor |
| `prUrlTemplate` / `--from-pr` multi-host review support を整理 | GitHub Enterprise / GitLab / Bitbucket 利用者の review 導線が自然になる | harness-review / release |
| Codex `0.124.0` stable hooks と Claude Code hooks の parity review | Codex 側の stable hooks を guardrail / long-running Bash / MCP tool observation に活かせる可能性がある | Codex package / guardrails |
| Codex multi-environment app-server と branch/workdir policy | 複数 repo / worktree / remote environment の取り違えを減らせる | Codex workflow |

## Phase 56.2 closeout

Phase 56 の follow-up decision は `docs/upstream-followups-phase56-2026-04-25.md` に記録した。

要点:

- `PostToolUse.duration_ms` は今回は no-op とし、per-tool telemetry sink を別 task に残す
- `effort.level` / `thinking.enabled` は `scripts/statusline-harness.sh` に取り込み、statusline telemetry にも保存する
- Codex stable hooks は parity review のみ行い、`codex/.codex/config.toml` には no-op 理由のコメントだけ残す
- `prUrlTemplate` / `--from-pr` multi-host review は docs-only とし、owner / branch / CI の automation は GitHub-first を維持する
- Codex multi-environment app-server は workflow guidance として扱い、write は 1 turn につき 1 primary environment に絞る safe default と write guard を採る

## B: 書いただけ 0 件の理由

- Feature Table の Phase 56 追加行は、すべてこの snapshot と Plans の Phase 56 task に接続している。
- 今回は配布 hook / settings / guardrail を変えず、公式差分を `A: 検証強化`, `C: 自動継承`, `P: 将来タスク` に分類した。
- `A` は「Phase 56 snapshot と upstream integration test による検証強化」であり、実装を捏造しない。
- `P` は Plans に後続 task として残し、stable でない `0.125.0-alpha.2` からは推測実装しない。

## No-op adaptation decision

今回は no-op adaptation とする。

理由:

- Claude Code `2.1.119` の多くは本体 runtime / TUI / MCP OAuth / managed settings の修正で、Harness が wrapper を重ねると二重責務になりやすい。
- Codex `0.124.0` の stable hooks は価値が高いが、Claude Code hooks とは config surface が違う。即時に `codex/.codex/config.toml` へ hook を追加するより、Codex hooks parity review として切る方が安全。
- Pre-release の Codex `0.125.0-alpha.2` は release body が薄く、compare から仕様を推測して実装しない。
