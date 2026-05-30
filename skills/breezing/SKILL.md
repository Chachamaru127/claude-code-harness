---
name: breezing
description: "Team execution mode — backward-compatible alias for harness-work with team orchestration."
description-ja: "チーム実行モード — harness-work のチーム協調エイリアス。breezing, チーム実行, 全部やって でトリガー。"
description-en: "Team execution mode — backward-compatible alias for harness-work with team orchestration."
kind: workflow
purpose: "Wrap harness-work with team execution orchestration"
trigger: "breezing, team execution, do everything"
shape: wrap
role: orchestrator
base: harness-work
pair: harness-review
owner: harness-core
since: "2026-05-05"
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "Task", "WebSearch", "Monitor"]
argument-hint: "[all|N-M|--codex|--cursor|--reviewer-only|--parallel N|--no-commit|--no-discuss|--auto-mode]"
user-invocable: true
---

# Breezing — Team Execution Mode

> **後方互換エイリアス**: `harness-work` をチーム実行モードで動かします。

## Narration Rules (UX Hard Contract)

このスキルは「起動 → 委譲開始」を 3 秒以内に進めるため、中間ナレーションを禁ずる。違反した skill は UX 不合格として扱う。

- **過去経緯の振り返り禁止**: 「先ほど止まった」「以前 Worker は完了済み」を語らない。Plans.md / git 状態から直読する
- **事前宣言禁止**: 「使い方を確認します」「次は X を確認します」を出さない。tool call 自体が宣言なので不要
- **同じ事実の 2 回言い換え禁止**: cursor-companion.sh の確認結果を後段で再度説明しない
- **中間ステータスラベル禁止**: 「実行中」「実行済み」「次は…」を出さない。tool call で自明
- **★ Insight ブロック禁止 (起動シーケンス中)**: Explanatory style を一時停止する。Insight は最終 report で 1 回のみ可
- **最初の text は 1 行のみ**: `🚀 <backend> / <model> / <branch> / <task>` 形式で first text として 1 秒以内に出す

違反例:
```
× "composer 2.5 使うモード" = cursor backend で Composer に委託、ですね
× 「前回 Reviewer が止まったので別系統に逃がすのは理にかなっています」
× 「使い方を確認します」 → bash → 「呼べます」
× ★ Insight ──── 役割分担を明確にします: ...
```

正常例:
```
🚀 cursor / composer-2.5-fast / feat/hah-11-golden-rule-lint / Reviewer
```

## Quick Reference

```bash
/breezing                       # スコープを聞く（claude backend）
/breezing all                   # 全タスク完走（claude backend）
/breezing 3-6                   # タスク3〜6を完走
/breezing --codex all           # Codex CLI で全タスク委託
/breezing --cursor              # cursor backend lean path (--no-discuss all 既定)
/breezing --cursor --reviewer-only  # Reviewer のみ cursor に委譲（Worker は別系統で既完了）
/breezing --parallel 2 all      # 2並列で全タスク完走
/breezing --no-discuss all      # 計画議論スキップで全タスク完走
/breezing --auto-mode all       # 互換な親セッションで Auto Mode rollout を試す
```

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `all` | 全未完了タスクを対象 | - |
| `N` or `N-M` | タスク番号/範囲指定 | - |
| `--codex` | Codex CLI で実装委託 | false |
| `--cursor` | cursor backend lean path (`HARNESS_IMPL_BACKEND=cursor` 相当)。Worker 介在 / self_review / sprint-contract 3 段チェーン / Phase 0 を skip し、起動 → 委譲を 3 秒以内に開始する | false |
| `--reviewer-only` | Reviewer のみ独立系統に委譲（Worker 実装は既完了前提）。`--cursor` と併用で Composer に逃がす | false |
| `--parallel N` | Implementer 並列数 | auto |
| `--no-commit` | 自動コミット抑制 | false |
| `--no-discuss` | 計画議論スキップ | `--cursor` で true 既定 |
| `--auto-mode` | Harness 側の Auto Mode rollout を明示。CC 2.1.111 で不要になった `--enable-auto-mode` とは別物 | false |

> **CC 2.1.111 note**:
> Opus 4.7 では literal に `/effort xhigh` が使える。
> built-in `/ultrareview` は明示要求時だけ追加で使い、既定レビューは置き換えない。

> **長時間セッション推奨 (CC 2.1.108+)**:
> セッション長が 30 分を超える見込みの場合、plugin bundle root 解決後に
> `bash "${HARNESS_PLUGIN_ROOT}/scripts/enable-1h-cache.sh"` を実行して 1 時間 prompt cache を opt-in すること。
> このスクリプトは `env.local` に `export ENABLE_PROMPT_CACHING_1H=1` を追記する (冪等)。
> 5 分 TTL の既定キャッシュでは breezing の 1 時間超セッションで cache miss が累積し
> input token コストが最大 12 倍になりうるため、長時間 team 実行では明示的に opt-in する。
> Codex CLI 子プロセス (`scripts/codex-companion.sh task --write` 等) は通常 env 継承で
> `ENABLE_PROMPT_CACHING_1H` を読むが、`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` が有効な場合は
> 明示的に export を維持する shell wrapper が必要。詳細は
> [`docs/long-running-harness.md`](../../docs/long-running-harness.md) を参照。

## Execution

**このスキルは `harness-work` に委譲します。** 以下の設定で `harness-work` を実行してください:

1. **引数をそのまま `harness-work` に渡す**
2. **チーム実行モードを強制** — Lead → Worker spawn → Reviewer spawn の三者分離
3. **Lead は delegate 専念** — コードを直接書かない
4. **Auto Mode は opt-in 扱い** — `--auto-mode` は互換な親セッションでの rollout 用フラグとして受け付ける
5. **Advisor は必要時のみ** — Worker が `advisor-request.v1` を返した時だけ Lead が advisor を呼ぶ

### `harness-work` との違い

| 特徴 | `harness-work` | `breezing` (このスキル) |
|------|-----------------|------------------------|
| 並列手段 | 必要数に応じた自動分割 | **Lead/Worker/Reviewer の役割分離** |
| Lead の役割 | 調整+実装 | **delegate (調整専念)** |
| レビュー | Lead 自己レビュー | **独立 Reviewer** |
| デフォルトスコープ | 次のタスク | **全部** |

### Team Composition

| Role | Agent Type | Mode | 責務 |
|------|-----------|------|------|
| Lead | (self) | - | 調整・指揮・タスク分配 |
| Worker ×N | `claude-code-harness:worker` | `bypassPermissions`（現行） / Auto Mode（follow-up）* | 実装 |
| Advisor | `claude-code-harness:advisor` | 読み取り専用 | 方針助言 (`PLAN` / `CORRECTION` / `STOP`) |
| Reviewer | `claude-code-harness:reviewer` | `bypassPermissions`（現行） / Auto Mode（follow-up）* | 独立レビュー |

> *親セッションまたは frontmatter が `bypassPermissions` の場合はそちらが優先される。配布テンプレートは現在も `bypassPermissions` を使うため、Auto Mode は follow-up の rollout 対象であり、既定挙動ではない。

### Codex Mode (`--codex`)

公式プラグイン `codex-plugin-cc` 経由で Codex CLI にすべての実装を委託するモード:

```bash
# タスク委託（書き込み可能）
bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write "タスク内容"

# stdin 経由（大きなプロンプト向け）
CODEX_PROMPT=$(mktemp /tmp/codex-prompt-XXXXXX.md)
# タスク内容を書き出し
cat "$CODEX_PROMPT" | bash "${HARNESS_PLUGIN_ROOT}/scripts/codex-companion.sh" task --write
rm -f "$CODEX_PROMPT"
```

### Execution Backend (persistent)

`HARNESS_IMPL_BACKEND=cursor`（`bash "${HARNESS_PLUGIN_ROOT}/scripts/set-impl-backend.sh" cursor` で設定）にすると、
per-run フラグなしで cursor が既定の worker バックエンドになる。review / advisor ロールは Opus に固定したまま。
バックエンド選択の正本（precedence、role-scope、self_review スキップ、cursor banner）は
`harness-work` の「Execution Backend Selection（実装バックエンド選択）」を参照する。

下の Cursor Backend Fast Path は per-run フラグ (`--cursor`) で同等の lean path を有効化する別軸であり、本節と併読する。

### Cursor Backend Fast Path (`--cursor` / lean mode)

`--cursor` 指定時、または env `HARNESS_IMPL_BACKEND=cursor` の時に有効。Worker 層を介在させず Lead が直接 `cursor-companion.sh` を呼ぶ（Phase 85 SSOT、`.claude/rules/cursor-cli-only.md` Topology 節）。

#### 削除される step（claude backend と比べて節約）

| Step | 削除理由 | 節約秒数 |
|---|---|---|
| `claude-code-harness:worker` agent spawn | cursor backend は Worker 介在なし | 5-30s |
| self_review 5 件ゲート | `worker-report.v1` が cursor では生成されないため不要 | 10-60s × retry |
| sprint-contract 3 段チェーン (generate→enrich→ensure) | Worker 契約不要なら contract 不要 | 2-5s × N |
| Phase 0 Q1-Q3 interactive | `--no-discuss all` 既定 (Plans/Depends は Lead が直読み) | 15-30s |
| Effort スコアリング | cursor backend では ultrathink 注入不要 | 0.5-1s × N |
| Plans.md re-parse (per task) | session 内 cache (mtime+hash で短絡) | 3-8s |

合計 baseline `15-35s` → target `3-7s` で 1 タスク目の cursor 委譲開始までを短縮。

#### 既定 flow（cursor backend）

1. **first text 1 行 echo** (`🚀 cursor / <model> / <branch> / <task>`、1 秒以内)
2. **1 bash で並列 pre-check**: `git branch --show-current` + `cat VERSION` + `Plans.md tail` + `cursor-agent --version`
3. **1 bash で resolve**: `scripts/resolve-impl-backend.sh` + `bash scripts/model-routing.sh --host cursor --role worker --field model`
4. **即 委譲**: `bash scripts/cursor-companion.sh task --write --workspace <wt> "<task>"`
5. cursor 出力を Lead が diff レビュー → cherry-pick → Plans.md `cc:done [hash]` 更新

#### Reviewer-only mode (`--cursor --reviewer-only`) — read = lean

Worker 実装は既完了（別系統 = claude / Codex で済んだ）、Reviewer のみ独立系統 (Composer) で回したい時の lean path。read-only 委譲なので **worktree 不要・cherry-pick 不要・Lead diff review 不要**:

1. 1 行 echo: `🚀 cursor / composer-2.5-fast / review`
2. `bash scripts/cursor-companion.sh task "diff レビュー: <base_ref>..HEAD"` — **`--write` も `--workspace` も付けない**
   - companion は `--write` 未指定で default `--mode ask` (hard read-only stop) になる (cursor-companion.sh の workspace guard は `--write` 時のみ発火)
   - cursor 側はファイル書込・コマンド実行が disabled、worktree 隔離不要
3. cursor 出力 (REQUEST_CHANGES / APPROVE 相当) を Lead が解釈し、`dual_review.cursor_verdict` に advisory として格納
4. **primary verdict は Opus reviewer から取る**。cursor 単独では APPROVE を確定しない (harness-work/SKILL.md「実装したバックエンドが自分の出力をレビューしてはならない」不変ルールと整合)
5. APPROVE なら Plans.md `cc:done [hash]` を Lead が更新

read mode で省略できるもの: 専用 `.git` worktree / Lead diff review / cherry-pick / `worker-report.v1` / self_review 5 件。
read mode でも保持必要: `.cursorignore` / egress allowlist (`*.cursor.sh`) / permissions.json (best-effort)。詳細は `.claude/rules/cursor-cli-only.md` 「Read mode delegation (lean path)」節を参照。

**用途**:
- Anthropic 側 server rate limit で Reviewer が止まった時の逃げ道
- Worker 完了済みで Reviewer だけ別系統に分散
- Codex review が auth 失敗した時の manual fallback

#### Cursor adapter support claim

Cursor は依然 `internal-compatible` tier（Phase 87 / PR #174 で promotion）。`supported` public claim は CI-gated workflow smoke 充足まで継続 gate。`--cursor` lean path は support tier を昇格させない。

Bootstrap route: `.cursor/AGENTS.md` + `.cursor-plugin/plugin.json`。

Verification:

```bash
bash tests/test-cursor-adapter-candidate.sh
bash tests/test-support-claim-wording.sh
```

## Flow Summary

```
breezing [scope] [--codex] [--parallel N] [--no-discuss] [--auto-mode]
    │
    ↓ Load harness-work with team mode
    │
Phase 0: Planning Discussion (--no-discuss でスキップ)
Phase A: Pre-delegate（チーム初期化）
Phase B: Delegate（Worker 実装 + 必要時 Advisor + Reviewer レビュー）
Phase C: Post-delegate（統合検証 + Plans.md 更新 + commit）
```

## Advisor Protocol

Worker は generic な subagent を増やさない。
迷った時は構造化 JSON で相談要求だけ返し、Lead が advisor を呼ぶ。

1. Worker → `advisor-request.v1`
2. Lead → Advisor
3. Advisor → `advisor-response.v1`
4. Lead → 同じ Worker に advice を返して続行
5. Reviewer は最後の成果物だけを見る

相談条件は loop / solo とそろえる。

- 高リスク task（`needs-spike` / `security-sensitive` / `state-migration`）の初回実行前
- 同じ原因の失敗が 2 回続いた後
- plateau により `PIVOT_REQUIRED` を返す直前
- 同じ `trigger_hash` は 1 回だけ。task ごとの相談回数は最大 3 回

### Progress Feed（Phase B 中の進捗通知）

Lead は Worker のタスク完了ごとに、以下のフォーマットで進捗を出力する:

```
📊 Progress: Task {completed}/{total} 完了 — "{task_subject}"
```

**出力例**:
```
📊 Progress: Task 1/5 完了 — "harness-work に失敗再チケット化を追加"
📊 Progress: Task 2/5 完了 — "harness-sync に --snapshot を追加"
📊 Progress: Task 3/5 完了 — "breezing にプログレスフィードを追加"
```

> **設計意図**: breezing は長時間実行になることが多い。
> ユーザーがターミナルをチラ見した時に「今どこまで進んでいるか」が一目で分かるようにする。
> task-completed.sh フックが systemMessage で同等の情報を出力するため、Lead の出力と補完し合う。

### Silence Policy（長時間実行の通知整理）

Codex `0.123.0` の realtime handoff では、background agent が transcript delta を受け取り、必要ない時は明示的に沈黙できる。
Breezing の progress feed はこの前提に合わせ、通知を「作業の節目」に絞る。

報告するもの:

- task 完了、blocked、validation failure、review `REQUEST_CHANGES`
- Advisor の `PLAN` / `CORRECTION` / `STOP`
- Reviewer の `APPROVE` / `REQUEST_CHANGES`
- advisor / reviewer drift、plateau、contract readiness failure
- user が明示的に status を求めた時の要約

沈黙してよいもの:

- transcript delta を受け取っただけで、判定や status が変わっていない時
- tool stdout の細かな増分で、log に残っていれば十分な時
- 並列 Worker の待機中 heartbeat

頻度は「task 完了ごとに 1 回」を基本にする。
heartbeat を増やして安心感を作るのではなく、status / log / drift 検知に責務を分ける。
ただし Advisor request 未応答、Reviewer result 未到着、plateau 直前の警告は silence 対象にしない。

### Monitor ツール活用ガイド (CC 2.1.98+)

長時間実行コマンドを監視する時は、ポーリング (Read で定期的にファイル末尾を読む) ではなく **Monitor ツール** を使用する。Monitor はバックグラウンドプロセスの stdout 各行を逐次通知として Lead に届けるため、polling より低レイテンシかつ低トークン消費で状況を把握できる。

**適用例**:
- `go test ./... -v` の実行中進捗監視
- `gh run watch` による GitHub Actions 進捗追跡
- `npm run build --watch` / `vite build --watch` のビルドエラー即時検知
- `codex-companion.sh status <job-id>` での Codex job 完了検知
- `docker-compose logs -f` / `kubectl logs -f` のデプロイログ追跡

**使い分けの判断基準**:

| 対象 | Monitor 使う? | 理由 |
|---|---|---|
| Agent (Worker / Reviewer) の完了監視 | 不要 | Agent 層が自前で完了通知する |
| `run_in_background: true` で投げた shell process | 推奨 | stdout 各行を逐次通知で拾える |
| 短時間の一発コマンド (`go test` 1 回実行) | 不要 | 通常の Bash tool 実行で十分 |
| 長時間 tail / watch / stream 系コマンド | 推奨 | polling より効率的 |

**Breezing Lead での典型パターン**:

```
Lead:
  Task(Worker1, ...)           ← Agent 完了待ち (Monitor 不要)
  Task(Worker2, ...)           ← 同上
  Bash(run_in_background, "gh run watch --exit-status")
  Monitor(tailCommand="...")   ← CI 失敗を即時検知 → Worker に修正指示
```

これにより Lead が「Worker 完了 → CI 失敗検知 → 修正指示」の反応速度を上げられる。

### Review Policy（全モード統一）

Breezing モードでもレビューは **Codex exec 優先 → 内部 Reviewer フォールバック** の統一ポリシーに従う。
詳細は `harness-work` の「レビューループ」セクションを参照。

- Worker が worktree 内で実装・commit → `worker-report.v1` (self_review 5 件) を Lead に返却
- **self_review ゲート (Reviewer spawn 前)**: Lead が `self_review[].verified` と `evidence` を機械検証。1 件でも `verified:false` or `evidence:""` なら Reviewer を spawn せず Worker に自動差し戻し（同一セッション内 最大 2 回、3 回目で escalate）
- Lead が Codex exec でレビュー（120s タイムアウト、フォールバック: Reviewer agent）
- REQUEST_CHANGES → Lead が SendMessage で Worker に修正指示、Worker が amend（最大 `MAX_REVIEWS` 回。`MAX_REVIEWS = read_contract(contract_path, ".review.max_iterations") or 3`）
- APPROVE → **Lead** が main に cherry-pick → Plans.md を `cc:完了 [{hash}]` に更新

### 完了報告（Phase C — Lead が生成）

全タスク完了後、**Lead** が以下の手順でリッチ完了報告を生成する:

1. `git log --oneline {base_ref}..HEAD` で全 cherry-pick コミットを収集
2. `git diff --stat {base_ref}..HEAD` で全体の変更規模を取得
3. Plans.md の `cc:TODO` / `cc:WIP` 残タスクを抽出
4. `harness-work` の「完了報告フォーマット」の Breezing テンプレートに従い出力

> **生成者は Lead**。Worker や hook ではない。Lead が Phase C で git + Plans.md を読んで生成する。

### Phase 0: Planning Discussion（構造化 3 問チェック）

全タスク実行前に、以下の 3 問で計画の健全性を確認する。
`--no-discuss` 指定時は全スキップ。

**Q1. スコープ確認**:
> 「{{N}} 件のタスクを実行します。スコープは適切ですか？」

多すぎる場合は優先度（Required > Recommended > Optional）で絞り込みを提案。

**Q2. 依存関係確認**（Plans.md に Depends カラムがある場合のみ）:
> 「タスク {{X}} は {{Y}} に依存しています。実行順序は合っていますか？」

Depends カラムを読み取り、依存チェーンを表示。循環依存があればエラー。

**Q3. リスクフラグ**（`[needs-spike]` タスクがある場合のみ）:
> 「タスク {{Z}} は [needs-spike] です。先に spike しますか？」

spike 未完了の `[needs-spike]` タスクがある場合、spike を先行実行するか確認。

3 問とも問題なければ、Phase A に進む（合計 30 秒で完了する設計）。

### Universal Violations Injection（セッション内 Worker 間の学習伝播）

同一 `/breezing` 起動内で蓄積された Reviewer の universal gotchas を次 Worker の briefing 冒頭に自動注入する。**同一セッション内のみ有効**（セッション終了で破棄、`session-memory` には書かない）。

```python
# Phase A 開始時に Lead プロセスの in-memory 配列を初期化
universal_violations = []  # List[str] — このセッション内で蓄積

# Phase B で Worker を spawn する直前、briefing 冒頭に注入:
def build_worker_briefing(task, contract_path):
    header = ""
    if universal_violations:
        header = (
            "🚨 同一セッションで既に検出された universal 違反（再発禁止）:\n"
            + "\n".join(f"- {v}" for v in universal_violations)
            + "\n\n"
        )
    return header + f"タスク: {task.内容}\nDoD: {task.DoD}\ncontract_path: {contract_path}\nmode: breezing"

# Reviewer が review-result.v1 を返した後、Lead が scope="universal" のみ抽出して累積:
for update in reviewer_result.memory_updates:
    # 後方互換: 文字列は task-specific 扱い → 無視
    if isinstance(update, str):
        continue
    if update.get("scope") == "universal":
        universal_violations.append(update["text"])
```

**方針**: 過剰設計回避のため、`session-memory` や `decisions.md` への永続化は行わない。Lead プロセスの in-memory 配列に保持するだけで、`/breezing` セッション終了時に破棄する（issue #87 本文の方針）。

### 依存グラフに基づくタスク割り当て

Plans.md に Depends カラムがある場合（v2 フォーマット）、依存グラフに従ってタスクを実行する:

1. **Depends が `-` のタスク**を先に実行。独立タスクが複数あれば並列 spawn 可能
2. 各 Worker 完了後、Lead がレビュー→cherry-pick（harness-work Phase B 参照）
3. 依存元タスクが main に cherry-pick されたら、そのタスクに依存していたタスクを次に実行
4. 全タスクが完了するまで繰り返す

> **注意**: 各タスクの「Worker 完了→レビュー→cherry-pick」は逐次処理。
> 並列化できるのは独立タスク（Depends が `-`）の Worker spawn 部分のみ。

## Codex Native Orchestration

Codex では native subagent を使う。
代表的な制御面は `spawn_agent`, `wait`, `send_input`, `resume_agent`, `close_agent`。

> **Claude Code vs Codex の通信 API**（SSOT: `team-composition.md` の API マッピング表）:
> - Claude Code: `SendMessage(to: agentId, message: "...")` で Worker に修正指示
> - Codex: `resume_agent(agent_id)` で Worker を再開 → `send_input(agent_id, "...")` で指示送信
>
> harness-work の擬似コードは Claude Code 構文で記述。Codex 環境では上記に読み替えること。

## Related Skills

- `harness-work` — 単一タスクからチーム実行まで（本体）
- `harness-sync` — 進捗同期
- `harness-review` — コードレビュー（breezing 内で自動起動）
