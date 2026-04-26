# Phase 56 Follow-up Decisions - 2026-04-25

この文書は、Phase 56 の follow-up task `56.2.1` から `56.2.4` について、
「今すぐ実装するもの」と「記録だけに留めるもの」を分けて固定するための記録です。

## ひとことで

Harness は、**既に配布している surface にだけ最小追従し、責務が重なる wrapper は増やしません。**

## たとえると

新しい道路標識が増えた時に、
今ある案内板にそのまま足せるものは足し、
交通管制そのものを二重に作るような変更は見送る、という整理です。

## Official References

- Claude Code status line docs: <https://code.claude.com/docs/en/statusline>
- Claude Code hooks docs: <https://code.claude.com/docs/en/hooks>
- OpenAI Codex `rust-v0.124.0` release: <https://github.com/openai/codex/releases/tag/rust-v0.124.0>
- OpenAI Codex config reference: <https://developers.openai.com/codex/config-reference>
- OpenAI blog, Codex App Server: <https://openai.com/index/unlocking-the-codex-harness/>

## 56.2.1 Claude Code `PostToolUse.duration_ms` and status line fields

### Current Harness surface

| Surface | Current state | Decision impact |
|---------|---------------|-----------------|
| `scripts/session-monitor.sh` | `SessionStart` で project / git / Plans 状態を集めるだけで、`PostToolUse` 入力は受け取らない | `duration_ms` をここへ混ぜると責務がずれる |
| `scripts/statusline-harness.sh` | Claude Code status line stdin JSON をすでに読んでいる | `effort.level` / `thinking.enabled` は低リスクで追従できる |
| `statusline-telemetry.jsonl` | status line 由来の cost / duration / role を保存している | `effort` / `thinking` も同じ粒度で残せる |

### Decision

| Upstream field | Harness decision | Why |
|----------------|------------------|-----|
| `PostToolUse.duration_ms` | **PostToolUse.duration_ms は今回は no-op** | Harness の shipped Session Monitor は `SessionStart` 用であり、per-tool latency sink がまだない。`cost.total_duration_ms` と混ぜると「セッション時間」と「個々の tool 時間」が分かりにくくなる |
| `effort.level` | **statusline に採用** | `scripts/statusline-harness.sh` が既に status line JSON を読むため、追加の runtime hook を増やさず反映できる |
| `thinking.enabled` | **statusline に採用** | `effort.level` と同じく、既存 statusline surface で安全に見える化できる |

### Display spec

- status line 1 行目に `effort:<level>` を表示する
- thinking が有効な時は `think:on`、無効な時は `think:off` を表示する
- field が無い時は何も出さない
- telemetry JSONL には `effort_level` と `thinking_enabled` を追加する

## 56.2.2 Codex `0.124.0` stable hooks parity review

### Parity table

| 観点 | Claude Code | Codex `0.124.0` | Harness decision |
|------|-------------|-----------------|------------------|
| Main config surface | `hooks/hooks.json` / `.claude-plugin/hooks.json` | inline `config.toml` と managed `requirements.toml` が release note に明記 | **shipped `codex/.codex/config.toml` には追加しない** |
| Admin policy surface | project / plugin settings + hook files | `requirements.toml` で security-sensitive policy を固定できる | org policy は docs に残し、配布 default には入れない |
| MCP tools observation | Claude Code hook matcher で tool name ごとに扱う | release note で MCP tools observation を明記 | 読み取り系診断の価値はあるが、Claude 側 hook と二重化しない |
| `apply_patch` observation | Claude 側は `Write` / `Edit` 系 guardrail が主 | release note で `apply_patch` observation を明記 | Codex package 専用 test が無い間は no-op |
| long-running Bash observation | Claude 側は `PermissionRequest` / `PostToolUseFailure` / `Monitor` を併用 | release note で long-running Bash observation を明記 | Codex runtime へ二重の log policy を載せない |
| Block timing | 実行前 deny / 実行後 feedback が強い | surface が異なり、admin requirements も絡む | parity は「同じポリシーをどう分担するか」で合わせる |

### Decision

- **Codex hooks は parity review のみ行い、shipped config は no-op にする**
- `codex/.codex/config.toml` には「なぜ追加していないか」のコメントだけ残す
- managed `requirements.toml` は組織ポリシーなので、配布 template に推測で書かない
- Claude Code 側ですでに持っている guardrail と同じ責務を、Codex 側へ即時に二重実装しない

### Note on docs drift

`rust-v0.124.0` release では hooks の stable 化と inline / managed config が明記されています。
一方で current config reference には `hooks.json` 読み込み向けの feature flag 記述も残っています。
Harness はこの docs drift を理由に、**今は parity table と no-op 理由だけを残し、config 推測実装をしません。**

## 56.2.3 `prUrlTemplate` / `--from-pr` multi-host review support

### Current boundary

| Surface | Current assumption | Decision |
|---------|--------------------|----------|
| `harness-review` | diff / file review は git ベースで host 非依存だが、PR metadata の自動取得はまだ抽象化していない | review core はそのまま、PR host abstraction は後続 |
| `harness-release` | `gh` CLI と GitHub remote を前提に release automation を組んでいる | GitHub-first automation を維持 |
| footer PR links | `prUrlTemplate` があれば human-facing link は multi-host にできる | **docs-only** で整理し、automation surface にはまだ広げない |

### Decision

- `prUrlTemplate` / `--from-pr` multi-host support は **docs-only** に留める
- GitHub Enterprise / GitLab / Bitbucket で review URL を出すこと自体は将来候補として残す
- ただし owner / branch / CI / release asset 取得は **GitHub CLI remains primary**
- 非 GitHub host を automation に混ぜるのは、host ごとの API / auth / CI surface を切り分ける task を別に起こしてからにする

## 56.2.4 Codex `0.124.0` multi-environment app-server and branch/workdir policy

### Current Harness policy

| Current mechanism | What it protects | Multi-environment implication |
|-------------------|------------------|-------------------------------|
| Worker `isolation: worktree` | 同一 repo 内の並列書き込み競合を減らす | primary repo の branch/worktree 境界は維持する |
| Codex sandbox / remote policy docs | remote host ごとの sandbox 差を整理する | environment を増やしても sandbox policy の置き場所は requirements 側 |
| cherry-pick based merge | main 取り込み境界を明確化する | 複数 environment の成果物をそのまま混ぜない |

### Safe default

| Scenario | Safe default |
|----------|--------------|
| 1 session で複数 environment を見たい | 調査はよいが、**write は 1 turn につき 1 primary environment** に絞る |
| remote environment を混ぜる | 非 primary environment はまず read-only で確認し、write は明示的に切り替える |
| branch / workdir が複数ある | merge / cherry-pick / Plans 更新は primary repo/worktree だけで行う |
| environment を切り替える | 次の write 前に target repo / branch / workdir を明文化する |

### Decision

- Codex App Server の multi-environment は **workflow guidance として採用**
- Harness 自身の branch/workdir 実装は、単一 repo / primary worktree を safe default にしたうえで、**Codex write 前の primary-environment guard** を追加する
- `codex/README.md` に **one primary environment per write turn** を safe default として追記する
- remote workspace を含む時も、primary 以外は read-only から始める

### Runtime guard

- `scripts/codex-primary-environment-guard.sh` が初回 write 先を primary environment として記録する
- 後続の write が別 worktree / 別 repo を向いた時は、デフォルトでは停止する
- 一時的に許可したい時は `HARNESS_CODEX_ALLOW_NON_PRIMARY_WRITE=1`
- primary 自体を切り替える時は `HARNESS_CODEX_RESET_PRIMARY_ENVIRONMENT=1`
- guard を無効化したい特殊環境だけ `HARNESS_CODEX_DISABLE_PRIMARY_ENV_GUARD=1`

## Why This Way

Harness が守りたいのは、「upstream の新機能を取り逃さないこと」と、
「便利そうだからといって wrapper を二重に増やさないこと」の両立です。

そのため Phase 56.2 では、
すでに配布している statusline には小さく追従し、
hook / multi-host / multi-environment は docs と safe default で先に境界を固定しました。
