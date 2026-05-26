# Codex Plugin Workflows Policy

最終更新: 2026-05-15

Codex plugin / workflow 連携と、Claude Code native `/goal` (2.1.139+) を Harness で扱う時の運用方針。

## ひとことで

Harness の SSOT は `Plans.md`。
Codex 側の `/goal` も、Claude Code native の `/goal` も、workflow state は補助入力として扱い、同じ計画を二重管理しない。

## たとえると

`Plans.md` はチームのホワイトボード。
`/goal` はその場のメモ。
メモは便利だが、ホワイトボードと食い違ったら、どちらを見ればよいか分からなくなる。

## `/goal` と `Plans.md` (Codex `/goal` + CC native `/goal` 共通)

CC 2.1.139 で Claude Code native `/goal` が追加された。Codex `/goal` と CC native `/goal` は
**どちらも session continuation memo** として扱う。Plans.md は唯一の task SSOT のままにする。

| 項目 | 方針 |
|------|------|
| 長期タスク管理 | `Plans.md` を正本にする |
| Codex `/goal` | 現在 turn / current run の補助メモとして扱う |
| CC native `/goal` (2.1.139+) | 同じく現在 turn / current run の補助メモとして扱う |
| task status | `Plans.md` の `cc:TODO` / `cc:WIP` / `cc:完了` を優先 |
| conflict | `Plans.md` を読み、必要なら `/goal` 側を更新する |

禁止:

- `/goal` (Codex or CC) にだけ acceptance criteria を置く
- `Plans.md` と `/goal` に別々の task list を持つ
- worker が `Plans.md` を読まずに `/goal` だけで完了判断する
- CC native `/goal` 完了条件を Plans.md DoD と差し替える

### CC native `/goal` の使ってよいケース

- 「次の 1 turn だけ集中したい sub-goal」を一時的に表示する
- `--print` / `-p` モードで完了条件を 1 ターン分だけ宣言する
- Remote Control 越しに operator が hand-off メモを残す

### CC native `/goal` で禁止のケース

- Plans.md `cc:WIP` の task を `/goal` 側で「完了」に書き換える
- Plans.md と独立した DoD を `/goal` だけに残す
- `/goal` の completion condition が Plans.md acceptance criteria と矛盾する状態で turn を継続する

## Codex `0.130.0` stable workflow updates

Codex `0.130.0` stable (`rust-v0.130.0`, published `2026-05-08T23:09:55Z`) で増えた workflow surface は、Harness では「便利になった観測・接続手段」として扱う。
`Plans.md` 正本、primary environment write guard、hook opt-in の境界は緩めない。

| 項目 | Codex `0.130.0` の変更 | Harness 判断 |
|------|-------------------------|--------------|
| `codex remote-control` | headless remotely controllable app-server の simpler top-level entrypoint | 明示起動する診断・操作 surface として案内する。配布 config では remote-control default を持たない |
| App-server thread pagination | app-server clients can page large threads | 長い Breezing / loop transcript は page して読む。1 回で全 transcript を読み込む前提にしない |
| `view_image` selected environment resolution | multi-environment session で selected environment 経由の file 解決ができる | screenshot / artifact evidence には environment と workdir を添える。non-primary environment の artifact を primary repo の証拠と混同しない |
| Live app-server config refresh | live app-server threads pick up config changes without restart | 設定反映確認には使うが、Harness setup は「再起動不要」を秘密値更新や権限変更の雑な運用理由にしない |
| Turn diff accuracy | `apply_patch` partial failure を含めて turn diffs が正確になった | turn diff は review 補助として使う。ただし最終判定は `git diff`、tests、package checks で行う |
| Plugin details bundled hooks | plugin details now show bundled hooks | plugin install / share 前に bundled hooks を確認する。Harness bundled hooks は opt-in 原則を維持する |
| Plugin sharing metadata | plugin sharing exposes link metadata and discoverability controls | link metadata と discoverability controls を公開範囲の一部として扱う。既定で過度に discoverable にしない |
| Configurable OTel trace metadata | configurable OpenTelemetry trace metadata | trace metadata は debugging / triage の補助。customer data や secret を入れない |
| Built-in MCPs as runtime servers | built-in MCPs first-class runtime servers | built-in MCP と plugin-provided MCP を混同しない。所有者と設定源を report に残す |
| `CODEX_HOME` environments TOML provider | `CODEX_HOME` 配下の environment provider を扱える | user-level environment と repo-local config の優先順位を明示し、write は primary environment に固定する |
| Skill root cleanup | remove skills list extra roots | 余分な skills root を前提にした fallback を増やさない。Harness は明示 mirror / path-based loading を維持する |

## Remote-control / app-server operations

`codex remote-control` は、headless app-server を遠隔操作しやすくする入口です。
Harness では次の扱いに固定する。

- 起動は user / operator が明示する。`codex/.codex/config.toml` には remote-control defaults を入れない。
- port、pid、auth boundary、selected environment、workdir を確認してから操作する。
- app-server clients が large threads を扱う時は pagination を使い、必要な page と timestamp を report に残す。
- live app-server threads が config changes を拾える場合でも、secret、network、provider、hook policy の変更は repo / user config の diff として残す。
- stale artifact を見つけても、担当外の environment なら勝手に削除しない。

## Telemetry / MCP / environment setup surfaces

Codex `0.130.0` は configurable OpenTelemetry trace metadata、built-in MCPs first-class runtime servers、`CODEX_HOME` environments TOML provider も含む。
Harness はこれらを便利な setup surface として扱うが、所有者境界を曖昧にしない。

- OpenTelemetry trace metadata には user / customer data、API key、provider credential、private URL を入れない。debugging / triage に必要な low-cardinality metadata だけを使う。
- built-in MCPs は Codex runtime の owned surface。plugin-provided MCP と同じ名前・同じ責務にしない。
- `CODEX_HOME` environments TOML provider は user-level environment source として扱う。repo-local `.codex/config.toml` や managed requirements と衝突する時は、実際に選択された environment を report する。
- remove skills list extra roots により、暗黙の extra root fallback に頼る運用は弱くなる。Harness は `scripts/setup-codex.sh` による user install、または `[[skills.config]]` path-based loading のどちらかを明示する。
- write turn は引き続き one primary environment。environment provider が増えても、複数 environment へ同時に書かない。

## Plugin-bundled hooks

Codex `0.128.0` の plugin-bundled hooks は、Harness では opt-in の workflow extension として扱う。
Codex `0.130.0` では plugin details に bundled hooks が表示されるため、install / share 前の確認項目として明示的に見る。

Plugin に hooks を同梱する場合、既定で project の挙動を強く変えない。

方針:

- hook は opt-in にする
- 破壊的操作、push、deploy、外部送信は既定無効
- `PostToolUse` で output を改変する場合は `docs/output-governance.md` に従う
- hook の stdout は JSON contract を守る
- plugin details に表示される bundled hooks と、実際に配布する hooks の差分を残さない

なぜ:

plugin を入れただけで hook が勝手に強く動くと、user / project の権限境界が見えにくくなるため。

## Plugin sharing metadata and discoverability

Codex `0.130.0` では plugin sharing に link metadata と discoverability controls が出る。
Harness の plugin 配布では、共有 URL そのものだけでなく、誰に見つかるか、何の説明で表示されるかを release surface として扱う。

方針:

- link metadata は plugin 名、用途、危険な hook / external-send の有無が分かる形にする。
- discoverability controls は明示的に選ぶ。内部検証中の plugin を公開 discoverable にしない。
- shared link を貼る時は、対象 version と install 後の verification command を併記する。
- plugin details で bundled hooks を確認してから share する。

## External agent import ownership

外部 agent を import する時は、所有者を明確にする。

| ケース | 所有者 | 方針 |
|--------|--------|------|
| Harness 配布 agent | Harness | repo 内で review / test / sync 対象 |
| user local agent | User | Harness は上書きしない |
| third-party plugin agent | Third-party plugin | Harness は依存関係として扱い、内容を fork しない |
| copied external agent | Harness fork | fork 元、変更理由、更新責任を docs に残す |

禁止:

- 外部 agent を黙って Harness 配布物に混ぜる
- user local agent を setup で上書きする
- fork 元の policy / license / update path を記録せずに改変する

## MultiAgentV2 and `agents.max_threads = 8`

`agents.max_threads = 8` は強い並列実行の上限として扱う。
常に 8 並列で走らせるという意味ではない。

方針:

- default は task size と risk に応じて少なめに始める
- IO-bound な調査は並列度を上げてよい
- 同じファイルを触る worker は並列にしない
- write-heavy work は ownership file list を先に固定する
- 8 は上限。review / integration / final verification は直列に戻す

例:

| 作業 | 推奨 |
|------|------|
| docs grep / evidence collection | 4-8 threads |
| 独立した docs 章の作成 | 2-4 threads |
| 同じ TypeScript module の修正 | 1-2 threads |
| release / version sync | 1 thread |

## Sticky environments

Sticky environment は、同じ作業環境を再利用して setup cost を下げる仕組みとして扱う。
ただし、古い server / cache / artifact が残るリスクがある。

safe default:

- one primary environment per write turn を維持する
- remote / sticky environment は read-only first で確認し、書き込み前に primary environment を明示する
- task 開始時に `git status --short` を確認する
- app server の port / pid / health を確認する
- env var と secret をログに出さない
- stale artifact を見つけても、担当外なら勝手に削除しない

## App-server artifacts

app server が生成する artifact は、review / reproduction に役立つ一方で、古くなると誤判定の原因になる。

方針:

- screenshot、trace、coverage、test output は path と生成時刻を報告する
- artifact を根拠にする時は、再生成コマンドも残す
- stale artifact を cleanup する時は、対象 path を明示する
- production credential や customer data を artifact に含めない

## Codex cloud / local boundary

Codex cloud task は sandboxed environment で動く。
Harness repo 内の local `Plans.md` と cloud 側の task state は自動同期される前提にしない。

そのため:

- cloud task の成果は PR / diff / report として受け取る
- Harness の完了判定は local repo で `git diff`、tests、`Plans.md` を確認して行う
- cloud artifact をそのまま source of truth にしない

## Sources

- OpenAI Codex docs: https://platform.openai.com/docs/codex
