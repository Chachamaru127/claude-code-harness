# 2026-11-08の全体整理（claude-code-harness）

既存の仕様・台帳・GitHubのmerge条件・公開手順を棚卸しした診断。2026-11-08 JST時点の正本hashに固定したスナップショットで、以後のPlans更新は再生成が必要。対象commitは `c2304c32`（origin/main、v5.16.0）。集約先は `Plans.md` Phase 151 と Issue #389。新しい仕事状態をこのフォルダへ確定しない。

表示入力は `report.json`、主模型は `MergeGate.qnt`。R3/R4はC1、R6はC3、R7はC2へ対応する。全条件をこの一つの模型で検証したとは扱わない。枝番の実装対応は `mapping.json` に残す。

## 条件の棚卸し

| ID | 条件 | 出典 | 分類 |
| --- | --- | --- | --- |
| R0 | 仕様と承認範囲を確定する | spec.md / Plans.md | 未モデル化: 公開・法務・本人判断は模型の外 |
| R1 | 依頼を正規のIssue/タスクへ対応付ける | Plans.md | 未モデル化: 人手の対応で、状態機械として未定義 |
| R2 | 実装前にPlans/specを現在真実へ更新する | Plans.md | 未モデル化: `project-doc-gate` の実行有無は別入口 |
| R3 | mainへのmergeは必須CI 3件の成功を伴う | branch-protection.json / validate-plugin.yml / Plans.md | C1 |
| R4 | base前進後は現在のbaseで再検査する | branch-protection.json | C4 |
| R5 | CI成功やAPPROVEはmerge・公開の自動許可ではない | autonomous-confirmation-scope.md / workflow-review-and-release.md | 未モデル化: 確認ゲートは人手 |
| R6 | merge済みmain到達commitだけにtagする | workflow-review-and-release.md | C3 |
| R7 | 検査済み経路でリリースまで到達できる | Plans.md / workflow-review-and-release.md | C2 |

## 遷移の一覧（図の代替）

| 遷移 | 開始状態 | 操作 | 終了状態 |
| --- | --- | --- | --- |
| open | PRなし | PR作成 | PR作成済み |
| checks | PR作成済み | 必須CI成功 | 必須CI緑・base一致 |
| baseMove | 必須CI緑・base一致 | base前進 | base前進で再検査待ち |
| rechecks | base前進で再検査待ち | 再検査成功 | 必須CI緑・base一致 |
| merge | 必須CI緑・base一致 | 通常merge | 通常merge済み |
| admin | PR作成済み | 未検査のまま管理者merge | 管理者merge（検査迂回） |
| adminStale | base前進で再検査待ち | base不一致のまま管理者merge | 管理者merge（検査迂回） |
| tag | 通常merge済み | tag | main到達commitへtag |
| tagBypass | 管理者merge（検査迂回） | tag | main到達commitへtag |
| release | main到達commitへtag | Release検証 | Releaseと配布物を確認 |

## 表示補助の制約

HTMLは create-formal-check の表示補助が `report.json` から生成する。到達可能性チェック（C2）の合否文言は不変条件向けの汎用文言で、経路の存在を「違反なし」と表示する。C2の意味は `result.json` とこのREADMEを正とする。図の状態と遷移は上の一覧と状態対応表を正とし、HTMLだけに依存しない。`current_match` は生成時点の照合結果で、以後のPlans更新では再生成が必要。

## 模型と状態の対応

模型の状態は表示用にまとめた抽象で、TLCが列挙した全状態の一覧ではない。

| 表示状態 | 模型の値 |
| --- | --- |
| PRなし | `prOpen=false, merged=false` |
| PR作成済み | `prOpen=true, checksPassed=false` |
| 必須CI緑・base一致 | `checksPassed=true, baseCurrent=true` |
| base前進で再検査待ち | `checksPassed=false, baseCurrent=false` |
| 通常merge済み | `merged=true, cleanMerge=true` |
| 管理者merge（検査迂回） | `merged=true, cleanMerge=false` |
| main到達commitへtag | `tagged=true` |
| Releaseと配布物を確認 | `released=true` |

## 検査結果

- **C1 `CleanMerge`（不変条件）**: 反例あり。State1初期 → State2 `OpenPR` → State3 `AdminMerge` で `merged=true, cleanMerge=false`。未検査の状態から管理者がmergeできる経路で、branch protection の `enforce_admins=false` に対応する。実際に迂回が起きた記録ではない。
- **C2 `NotReleasedClean`（到達可能性）**: 反例あり = 目標への経路あり。State2 `OpenPR` → State3 `ChecksPass` → State4 `Merge` → State5 `Tag` → State6 `Release`。通常経路が存在する。必ず到達する保証ではない。
- **C3 `NoTagWithoutMerge`（不変条件）**: 違反なし。全探索でTLC終了0。
- **C4 `NoStaleMerge`（不変条件）**: 反例あり。State2 `OpenPR` → State3 `ChecksPass` → State4 `BaseMoves` → State5 `AdminMerge` で `merged=true, baseCurrent=false`。base前進後の再検査を経ないmergeの経路。
- **自己確認**: `Merge` の前提を外した隔離模型は `CleanMerge` 違反（TLC終了12）。`Merge` は検査状態から `cleanMerge` を決めるため、通常mergeの検査漏れを検出できる。実行記録は `.local/route-setup-2026-11-08/selftest/`。

検査範囲は有限模型の中だけ。実装のCI内容の十分性、merge・tag・Releaseの実行履歴、配布物の実読戻しはこの検査の対象外。

## 再実行

`check.py` は `report.json` の出典と模型hashを照合し、`q_init` / `q_step` / `q_inv` を設定してTLCを実行する。外部Skillは要らない。Java 21を明示する。

```
export JAVA_HOME=/opt/homebrew/opt/openjdk@21
export PATH="$JAVA_HOME/bin:$PATH"
python3 formal/baseline/route-setup-2026-11-08/check.py C1 \
  --result .local/route-setup-2026-11-08/C1/result.json \
  --stdout .local/route-setup-2026-11-08/C1/stdout.log
```

結果の保存先は毎回未使用のパスへ変更する。既存の有効結果を理由なく上書き・反復しない。HTML生成は route-project-setup の `build_report.py` を使う場合だけで、検査の再実行には要らない。生成補助は検査を実行しない。

## 道具

`formal/quint/` は RouteCLI の固定toolchain（Quint 0.33.1 / Apalache 0.62.4、`provenance.json` の6ファイルhash一致）。`node_modules/` と `.cache/` はgit管理外。Apalache jarのsha256は `versions.json` の値で確認する。

## 対象外

実SKR、実DB、実Stripe、実配備、法務承認、T3プロジェクト、Bot、Instabox接続はこの診断から推論しない。branch protectionの変更、公開、releaseも行っていない。
