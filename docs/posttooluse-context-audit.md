# PostToolUse コンテキスト監査

対象: `.claude-plugin/hooks.json` / `hooks/hooks.json`（同一内容）

## 判定

PostToolUse は 9 matcher、20 hook で構成される。成功時の親コンテキスト削減対象は、状態を記録または解消するだけで、従来も `{"continue":true}` 以外の情報を返さなかった 3 hook に限定する。

| Hook | matcher | 成功時の副作用 | 変更 |
| --- | --- | --- | --- |
| `log-toolname` | `*` | tool / LSP / session / Skill のログ | stdout を空にする |
| `usage-tracker` | `Skill\|Task\|SlashCommand` | `usage-stats.jsonl` への追記 | stdout を空にする |
| `clear-pending` | `Skill` | `pending-skills/*.pending` の削除 | stdout を空にする |

各 hook は従来、成功ごとに `{"continue":true}\n`（18 bytes）を出力していた。変更後も記録・削除の副作用は同じで、成功時の添付は 0 bytes になる。

## 維持するシグナル

次の 17 hook は安全性・品質・進捗・可観測性に関わるため、成功・異常時の出力プロトコルを変更しない。`—` は command hook ではないため stdout を持たない。

| Hook | matcher | 副作用 / シグナル | 成功時 stdout | 無音化 |
| --- | --- | --- | --- | --- |
| `post-tool` | `Write\|Edit\|MultiEdit\|Bash` | policy approval | protocol 維持 | 不可 |
| `post-tool-use-file-lease` | `Write\|Edit` | lease conflict | protocol 維持 | 不可 |
| review agent | `Write\|Edit` | secret / stub / security review | — | 不可 |
| `memory-bridge` | `*` | session memory | protocol 維持 | 不可 |
| `commit-cleanup` | `Bash` | approval state | protocol 維持 | 不可 |
| `ci-status` | `Bash` | CI status | protocol 維持 | 不可 |
| `todo-sync` | `TodoWrite` | progress state | protocol 維持 | 不可 |
| `posttool-progress-regen` | `Write\|Edit\|MultiEdit\|Bash` | progress regeneration | protocol 維持 | 不可 |
| `emit-trace` | `Write\|Edit\|Task` | trace | protocol 維持 | 不可 |
| `auto-cleanup` | `Write\|Edit\|Task` | automation cleanup | protocol 維持 | 不可 |
| `track-changes` | `Write\|Edit\|Task` | change tracking | protocol 維持 | 不可 |
| `auto-test` | `Write\|Edit\|Task` | asynchronous test | protocol 維持 | 不可 |
| `quality-pack` | `Write\|Edit\|Task` | quality gate | protocol 維持 | 不可 |
| `plans-watcher` | `Write\|Edit\|Task` | plan progress | protocol 維持 | 不可 |
| `tdd-check` | `Write\|Edit\|Task` | TDD signal | protocol 維持 | 不可 |
| `skill-mirror-drift` | `Write\|Edit\|Task` | skill consistency | protocol 維持 | 不可 |
| `auto-broadcast` | `Write\|Edit\|Task` | progress / failure notification | protocol 維持 | 不可 |

`valid_root` による plugin-root の検証と fallback 探索も変更しない。これは成功時に親へ出力する経路ではなく、未検証の実行ファイルを避けるセキュリティ境界である。プロセスをまたぐ安全なキャッシュ機構がないため、ここだけを最適化しても品質を下げる。`test-hooks-trusted-root.sh` で維持を確認する。

## 効果測定

ユニットテストでは 3 対象 hook の成功出力が 0 bytes、記録・状態解消の副作用が維持されることを確認する。実運用では同一 autopilot 操作の前後で、PostToolUse 成功添付 bytes または `cache_read` を比較し、品質ゲート通過率と完走率が低下しないことを完了条件とする。
