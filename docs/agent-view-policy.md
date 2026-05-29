# Agent View (`claude agents`) Policy

CC `2.1.139`+ で `claude agents` (agent view, Research Preview) が単一 entrypoint として導入され、
`2.1.141` で `--cwd <path>` flag、`2.1.142` で `--add-dir` / `--settings` / `--mcp-config` /
`--plugin-dir` / `--permission-mode` / `--model` / `--effort` / `--dangerously-skip-permissions`
flag が追加された。

Harness はこれを **Lead (operator) が複数の Worker / Reviewer / Scaffolder 系 session を一覧監視する
独立 entrypoint** として扱い、Harness 内部の teammate spawn workflow とは分離する。

## 適用範囲

| 対象 | 利用方法 |
|------|----------|
| Lead (operator, 人間) | `claude agents` で複数 project の状態を 1 画面で確認 |
| Harness teammate spawn (Worker / Reviewer / Scaffolder) | `claude agents` ではなく Agent tool / breezing skill 経由 |
| Codex teammate | `bash scripts/codex-companion.sh task` (raw `codex exec` も `claude agents` も使わない) |

## 動作前提 (2.1.139-2.1.142)

- `claude agents --json` で live session 一覧を JSON 出力できる (2.1.145)。tmux-resurrect、status bar、session picker 等の **diagnostic / scripting** 用途に限定する。Harness teammate spawn の代替にしない。
- agent view は session ごとに **running / blocked on you / done** を表示する。
- `claude agents --cwd <path>` で session list を directory scope できる (2.1.141)。
- `claude agents` 起動時に `--add-dir`, `--settings`, `--mcp-config`, `--plugin-dir`,
  `--permission-mode`, `--model`, `--effort`, `--dangerously-skip-permissions` で dispatched
  background session を構成できる (2.1.142)。
- Background session で起動した teammate は permission mode を保持する (2.1.141)。default に戻らない。

## Harness 安全運用ポリシー

### A. 利用許可

| 利用ケース | 推奨 |
|-----------|------|
| 別 project の状況を確認しながら現 project で作業する | `claude agents --cwd <other-project>` |
| 別 project で安全な long-running task (test / lint) を background dispatch | `claude agents --cwd <path> --permission-mode default --effort low` |
| Read-only な調査 task (調査結果をすぐ確認したい) | `claude agents` で並列起動 |

### B. flag 利用条件

| Flag | 利用条件 | 禁止条件 |
|------|----------|----------|
| `--cwd <path>` | 別 project の状態を見るとき | --- |
| `--add-dir` | 検索 scope を拡張するとき | 同 dir 内 secret 含 path (`.env*`, `secrets/**`, `.ssh/**`) は denyRead 後でも opt-in 禁止 |
| `--settings <path>` | project 固有設定を試行する開発時 | `.claude-plugin/settings.json` を agent ごとに override し続けるのは禁止 (SSOT 崩壊) |
| `--mcp-config <path>` | 一時的 MCP server を試行 | プロジェクト永続 MCP は `.mcp.json` に統一する |
| `--plugin-dir <path>` | 未公開 plugin の local 試験 | --- |
| `--permission-mode <mode>` | `default` / `acceptEdits` / `plan` を明示 | `bypassPermissions` を protected branch (`main`/`master`) で使うのは禁止 |
| `--model <model-id>` | 一時的 model 切替 | release / hotfix セッションで小型 model にダウングレードするのは禁止 |
| `--effort <level>` | task 規模に応じた強度設定 | guard rail (R01-R13) を effort で緩和してはならない |
| `--dangerously-skip-permissions` | 信頼できる ephemeral sandbox 内のみ | (a) protected branch 上の session, (b) credentials を読む session, (c) production deployment session で使用禁止 |

### C. teammate spawn との分離

- `claude agents` は **operator (人間 Lead) が複数 session を見るための UI**。
  Harness 内の teammate spawn (Worker / Reviewer / Scaffolder) は **Agent tool / breezing skill** が起動する。
- Worker / Reviewer は `claude agents` から他 session を spawn しない。Lead 限定 (詳細: `.claude/rules/opus-4-7-prompt-audit.md` の権限と責務境界)。
- breezing skill は `claude --teammate-mode in-process` / `tmux` を使う。`claude agents` には依存しない。

### D. Background permission mode 保持 (2.1.141)

- `/bg` / `←←` または `claude agents` で background 化した teammate は、起動時の permission mode を保持する。
- Harness 側で **permission mode を再注入する必要なし**。breezing teammate の起動契約はそのまま使える。
- 確認: teammate が `plan` mode で起動された場合、background 後も `plan` mode のまま (CC 本体が保証)。

### E. agent view 起動順序 (推奨)

1. operator が `claude` で対話セッションを開く。
2. 必要に応じて `claude agents` で他 session の状態を確認。
3. 別 task を dispatch する場合は明示的に `claude agents --cwd <path> --permission-mode <mode> --effort <level>` を使う。
4. Lead が breezing を開始する場合は `claude agents` 経由ではなく `/breezing` skill から起動する。

## 違反例

| 違反 | 影響 | 推奨対応 |
|------|------|----------|
| Worker subagent が `claude agents` を呼んで別 session spawn | 権限境界の崩壊 (Lead だけが spawn) | Worker の手順から `claude agents` 呼び出しを削除 |
| protected branch (`main`) 上で `claude agents ... --dangerously-skip-permissions` | guard rail (R12 ask) bypass | `--permission-mode default` または `acceptEdits` を使う |
| `.claude-plugin/settings.json` を `--settings` で agent ごとに上書き | settings SSOT 崩壊 | project-level `.claude/settings.local.json` に変更を一元化 |
| `--dangerously-skip-permissions` を `harness-mem` 等 credential を扱う session で使用 | secrets 流出リスク | 該当 flag を外す |

## CI / gate

- `tests/validate-plugin.sh` は `claude agents` flag の存在を検証しない (CC 本体機能のため)。
- 代わりに `.claude/rules/opus-4-7-prompt-audit.md` の権限境界と `.claude-plugin/settings.json` の
  deny ルールが多層防御として機能する。
- `claude agents` の利用を運用上 audit したい場合は env `CLAUDE_CODE_SESSION_ID` を webhook 経由で
  記録する (`scripts/hook-handlers/webhook-notify.sh`)。

## 関連

- `docs/team-composition.md` — teammate spawn と並列度の SSOT
- `agents/worker.md` — Worker 契約
- `.claude/rules/opus-4-7-prompt-audit.md` — agent 契約 audit ルール (Lead 限定 spawn を明記)
- `docs/upstream-update-snapshot-2026-05-15.md` — Phase 69 snapshot
- `docs/upstream-update-snapshot-2026-05-27.md` — Phase 80 snapshot
- `.claude/rules/hooks-2.1.139-plus.md` — hook 周辺の 2.1.133+ rules
- `.claude/rules/hooks-2.1.152-plus.md` — MessageDisplay / reloadSkills / sessionTitle (2.1.152+)

## 見直し条件

- CC `claude agents` が GA に昇格 (Research Preview を抜ける) した時 → policy 全体を再確認
- `--dangerously-skip-permissions` flag が deprecate / rename された時 → 該当 cell を update
- Harness teammate spawn が `claude agents` API に統合可能になった時 → C 節 (teammate spawn との分離) を再検討
