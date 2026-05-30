# Team Composition

Harness の標準チーム構成は 5 ロール。
実装系の teammate を増やす時も、この 5 ロールの責務境界は変えない。

## 構成図

```text
Lead
├── Worker x 1..3
├── Advisor x 0..1
├── Reviewer x 1
└── Scaffolder x 0..1
```

## spawn 権限

- Lead だけが teammate を spawn する
- Worker は teammate を spawn しない
- Reviewer は teammate を spawn しない
- Scaffolder は teammate を spawn しない
- Worker が相談したい時は subagent を増やさず `advisor-request.v1` を返す

## role contract

| Role | subagent_type | 数 | 使うツール | 返すもの |
|------|---------------|----|------------|----------|
| Lead | Execute skill 内部 | 1 | Agent, SendMessage, Bash | task 分解、review 判定、main 反映 |
| Worker | `claude-code-harness:worker` | 1..3 | Read, Write, Edit, Bash, Grep, Glob | 実装結果または `advisor-request.v1` |
| Advisor | `claude-code-harness:advisor` | 0..1 | Read, Grep, Glob | `advisor-response.v1` |
| Reviewer | `claude-code-harness:reviewer` | 1 | Read, Grep, Glob | `review-result.v1` |

## worker 数の決め方

| 条件 | worker 数 |
|------|-----------|
| 書き込み対象ファイルが 1 グループ、またはファイルが重なる | 1 |
| 書き込み対象ファイルが 2 グループで、互いに重ならない | 2 |
| 書き込み対象ファイルが 3 グループ以上で、互いに重ならない | 3 |

ここでいう「グループ」は、同じ commit にまとめても競合しない書き込み集合を指す。
同じファイルを 2 worker に書かせる分割は禁止。

### Opus 4.8 での spawn 明示

Opus 4.8（host = Lead）はデフォルトで subagent を少なく spawn する傾向がある。
そのため上の worker 数条件は **明示的な spawn トリガー**として扱う。

- 独立した書き込みグループが 2 つあるのに「直接やった方が速い」で 1 worker に畳むのは、このケースでは誤り。グループ数 2 なら 2 worker、3 以上なら 3 worker を spawn する。
- 逆に、1 ファイルで完結する作業や直列依存タスクは、subagent を増やさず Lead が直接進める。

## Worker stall 時の re-spawn (CC 2.1.113+)

Lead は次の 2 条件のいずれかを満たしたら、同じ task を **最大 1 回** 再 spawn する。

- Plans.md `cc:WIP` 状態が **10 分** (600 秒) 超で更新されない
- CC 本体が stall log を出力 (`subagents stalling mid-stream fail after 10 minutes`)

再 spawn 後も同じ条件が再現したら escalation する。Worker 並列数の決め方には影響せず、stall 検出は Lead 側のみ責務。詳細は [`agents/worker.md`](../agents/worker.md) の「Stall 検出 — 2 層防御」を参照。

## 実行フロー

1. Lead が task を分解し、`sprint-contract` を作る
2. Lead が worker を spawn する
3. Worker が実装、preflight、検証、commit 準備を行う
4. Worker が相談条件に当たった時だけ `advisor-request.v1` を返す
5. Lead が Advisor を呼び、`advisor-response.v1` を同じ Worker に返す
6. Worker が結果を返したら Lead が review を実行する
7. `APPROVE` の時だけ Lead が main へ反映する

## review loop

| 条件 | Lead の動き |
|------|-------------|
| `review-result.v1.verdict == APPROVE` | cherry-pick して main に commit |
| `review-result.v1.verdict == REQUEST_CHANGES` | 同じ Worker に修正依頼を返す |
| 修正に仕様・Plans・API・権限・課金・移行の意思決定が必要 | AskUserQuestion で user decision を取る。推測で修正しない |

修正ループは最大 3 回。
4 回目には入らず、Lead が task をエスカレーションする。

`harness-review` は必要時に TeamAgent Debate を使う。
これは Reviewer の判定権限を増やすものではなく、Spec Agent / Plans Agent / Regression Agent / Skeptic Agent の read-only 視点を衝突させるための材料集めである。
最終 verdict は引き続き Reviewer が `review-result.v1` と明確な合格ラインに基づいて出す。

## SendMessage の固定パターン

Lead が Worker に修正を返す時は、次の構文を使う。

```text
SendMessage(
  to: "{worker_agent_id}",
  message: "以下の critical/major 指摘を修正してください:\n\n{issues}\n\n修正後 git commit --amend して完了を返してください。"
)
```

## breezing 時の main 反映

Worker は worktree または feature branch で commit する。
Lead は `APPROVE` 後に次の 2 コマンドで main へ取り込む。

```bash
git cherry-pick --no-commit {worktree_commit_hash}
git commit -m "feat: {task_description}"
```

Lead が main に反映するまでは、Worker は Plans.md を `cc:完了` に更新しない。

## Advisor の境界

- Advisor は `PLAN | CORRECTION | STOP` だけ返す
- Advisor は `APPROVE | REQUEST_CHANGES` を返さない
- Advisor はコードを編集しない
- Reviewer は advisor の提案文ではなく、最終成果物だけを見る
- Phase 61 の weak-supervision cue は Advisor の入力情報を増やすだけで、返答種類や最終判定権限は増やさない

## Codex bridge

Claude Code から Codex へ委譲する時の標準コマンドは次の 2 つだけ。

```bash
bash scripts/codex-companion.sh task --write "タスク内容"
bash scripts/codex-companion.sh review --base "${TASK_BASE_REF}"
```

raw `codex exec` をチーム標準手順として書かない。

## 2.1.111 優先ルール

- `xhigh` は caller 側の推論強度指定。worker prompt が文字列から自動判定しない
- `/ultrareview` は caller 側の review entrypoint。review artifact の契約は `review-result.v1` のまま
- `--auto-mode` は opt-in rollout。shipped default にしない

## permission mode

Plugin subagent frontmatter には `permissionMode` を置かない。
Claude Code の plugin agent では agent-local `permissionMode` が無視されるため、
権限は親セッションと plugin settings から継承する。

安全境界は次の層で担保する。

- plugin-level hooks
- Go guardrails
- Worker preflight
- Reviewer 判定

`--auto-mode` は rollout 用の opt-in。
既定値にはしない。

### background permission mode 保持 (CC 2.1.141+)

`/bg` / `←←` / `claude agents` で teammate を background 化した場合、
CC 2.1.141 以降は起動時の permission mode が保持される (default に戻らない)。

- Lead は `claude agents --permission-mode <mode>` で明示した mode が
  background 化後も維持される前提で運用する。
- breezing teammate の permission mode 再注入は不要。
  従来 `--auto-mode` で扱っていた特殊起動も CC 本体が mode 保持を保証する。
- 例外: `bypassPermissions` で起動した teammate も `.claude-plugin/settings.json` の
  `permissions.deny` / `autoMode.hard_deny` を override しない (多層防御は維持)。

### `claude agents` 経由の dispatched session (CC 2.1.142+)

Lead が `claude agents --add-dir / --settings / --mcp-config / --plugin-dir /
--permission-mode / --model / --effort / --dangerously-skip-permissions` で
dispatched background session を起動する場合は、`docs/agent-view-policy.md` の
flag 利用条件を参照する。teammate spawn workflow (breezing skill / Agent tool) との
分離が前提。

## Cursor adapter mapping (candidate)

Cursor host maps core roles to adapter surfaces without changing the core
Breezing contract:

| Core role | Cursor adapter surface | Parallelism |
|---|---|---|
| Lead | Parent agent session | Orchestrates only |
| Worker | Task tool / `.cursor/agents/worker.md` | Parallel when file groups do not overlap |
| Advisor | `.cursor/agents/advisor.md` on `advisor-request.v1` | On demand; max 3 per task |
| Reviewer | `.cursor/agents/reviewer.md` (`readonly: true`) | Serial per worker result |
| Scaffolder | Optional Task/subagent | On demand |

Multitask / background agents may fan out Workers but **must not** parallelize
Reviewer verdict or main-branch cherry-pick. That boundary is core-owned.

Model resolution:

```bash
bash scripts/model-routing.sh --host cursor --role <role> --format json
```

Explicit subagent/Task `model` overrides routed defaults. Cursor multitask is a
smoke target, not a public support or parity claim.

Verification: `bash tests/test-cursor-adapter-candidate.sh`

## チームサイズ

- 標準は 3 から 5 teammate
- Harness の通常構成は `Worker 1..3 + Reviewer 1`
- Advisor と Scaffolder は必要時のみ追加する
