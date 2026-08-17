# Blind Evaluator (opt-in) — Step 4.5 の詳細

`harness-accept` の Step 5 (recommendation 算出) の直前に挟む optional step。
`skills/harness-review/references/blind-judge.md` (以下 blind-judge.md) と同じ問題意識 —
「rubric を満たしていても、意図した読者に伝わるかは rubric では測れない」— を
Acceptance Demo の文脈に適用する。

## blind-judge.md からの流用可否

**設計原則は流用し、Output Contract と消費のされ方は流用しない (新規に定義する)。**

流用する部分:

- **Task tool で起動する plain fresh sub-agent。`context: fork` skill にしない**。理由は
  blind-judge.md と同じ — host project の rules が fork 先に流入する実測 (Issue #84) があり、
  評価者がそれ自身の評価基準を「知らないふり」をする rubric-aware reviewer に化けると、
  blind 評価という設計の前提が崩れる。
- 「渡してよいもの / 渡してはいけないもの」を明示表で固定する設計。
- Judge Prompt Template を `{...}` 埋め込みだけで固定文言にする方式。

流用しない部分 (この成果物専用に再定義する理由):

- **Eligibility の軸は同じだが対象が違う**。blind-judge.md は「code review の対象物」
  (UI コピー / ドキュメント / cognitive-load HTML surface vs コード / テスト / 設定 / スキーマ)
  を切り分ける。ここでは「Acceptance Demo が受け入れ判断しようとしているタスクの成果物」を
  同じ軸 (説得系/文書系 vs 機能系) で切り分ける。対象の主語が違うため Eligibility 判定は
  harness-accept 側で独立して行う。
- **Advisory-only 制約が正反対**。blind-judge.md は「divergence は verdict を書き換えない」
  ことを絶対制約にしている (rubric が security / regression 等の最終防衛線であるべきため)。
  harness-accept の recommendation は最終防衛線ではなく、非エンジニア発注者への**判断材料**
  そのものが目的であるため、ここでは **divergence が recommendation を wait 側へ丸める**
  (下記「Recommendation への反映」)。この違いは重要なので、次にこのファイルを直す人が
  blind-judge.md と同じ advisory-only に「揃えよう」としないよう明記しておく。
- Output Contract は `review-result.v1` の `blind_judge` ではなく `acceptance-context.v1` の
  `blind_evaluation` として独立に持つ (フィールド名・enum 値も accept 文脈向けに再設計)。

このため `skills/harness-review/references/blind-judge.md` への reference 差し替えでは済まず、
本ファイルを harness-accept 側の新規 reference として持つ。

## Eligibility（対象を絞る）

説得すること・読ませて理解させることが目的の文書系成果物だけに使う。機能系タスクは
「正しく動くか」が verified_criteria (Step 4) で機械的に判定できるため、rubric なしの
第一印象はノイズになる。

| 成果物の種類 | 適用 | 理由 |
|---|---|---|
| 提案書・レポート・investor/顧客向け資料 | 適用可 | 読み手を説得できるかが本質。verified_criteria だけでは測れない |
| README・ユーザー向け説明文・オンボーディング文 | 適用可 | 読み手が迷わず理解できるかは fresh eyes でしか測れない |
| 外部向け UI コピー (ボタン文言・エラーメッセージ) | 適用可 | 同上 |
| コード実装・バグ修正・機能追加 | **不可 (functional-skip)** | 正誤は verified_criteria (テスト・型・動作確認) で判定すべき |
| 設定ファイル・スキーマ・CI 配線 | **不可 (functional-skip)** | 主観品質の入る余地がない |
| インフラ/運用スクリプト | **不可 (functional-skip)** | 同上 |

判定に迷う成果物 (例: 説得系ドキュメントとコード変更が混在するタスク) は、
成果物の**主目的**で判定する。主目的が「動くこと」なら functional-skip。

対象外の場合は `blind_evaluation.applicable = false`、`eligibility_reason = "functional-skip"`
とし、評価者は起動しない (DoD b)。

## 手順

1. Eligibility を確認する。対象外なら `applicable: false` で終了する。
2. Step 4 (verified_criteria 組み立て) と Step 5 (recommendation 算出) の **結果を評価者に渡さない**。
   評価者は Step 4/5 と独立に、成果物そのものだけを見て判定する。
3. 下記「渡してよいもの / 渡してはいけないもの」を厳守し、Judge Prompt Template を組み立てる。
4. Task tool で fresh sub-agent (`subagent_type: general-purpose`) を起動する。専用 agent 定義は
   持たない — 専用 agent ファイルを作ると、その agent の説明文自体が判断材料の漏れ込み経路に
   なりうるため。
5. 評価者の一次反応 (信じられるか / 役に立つか / 引っかかった箇所) を受け取る。
6. `blind_evaluation` を組み立て、divergence を判定する。

## 渡してよいもの / 渡してはいけないもの

| 渡してよいもの | 渡してはいけないもの |
|---|---|
| 依頼文 (`user_request`、Plan Brief 時と同じ文) | 採点基準 (`verified_criteria` の各項目名・acceptance_criteria そのもの) |
| 成果物そのもの (ファイル内容 / レンダリング結果) | 合格ライン (recommendation の閾値、ship/wait/reject のどれになりそうか) |
| 読者像 1 行 (下記 template の `{AUDIENCE_PURPOSE_LINE}`) | 途中経過 (Step 4 で組み立てた verified_criteria / evidence / unverified_caveats) |
| — | 過去の問題パターン (`past_issue_patterns`)、implementer の report (worker-report.v1 等) |
| — | この Acceptance Demo セッションのそれまでの会話・判定 |

評価者に渡すのは「依頼文」「成果物」「読者像 1 行」の 3 つだけ。

## Judge Prompt Template

```
あなたは初見の読者としてこの成果物を見ます。事前情報も採点基準も与えられていません。

依頼文: {USER_REQUEST}
読者像: {AUDIENCE_PURPOSE_LINE}

成果物:
{ARTIFACT_CONTENT}

この成果物を上記の読者の立場で読んで、次の3点だけ答えてください。
1. 信じられるか（信じられる / 信じられない / 迷う）
2. 役に立つか（役に立つ / 役に立たない / 迷う）
3. 引っかかった箇所があれば具体的に（無ければ「なし」）

採点基準やチェックリストはありません。あなたの第一印象をそのまま述べてください。
```

`{AUDIENCE_PURPOSE_LINE}` の例: 「初めてこのプロダクトを検討する投資家。5分で読み切れて、
投資判断に足る根拠が示されている必要がある」

## Output Contract — `blind_evaluation`

`acceptance-context.v1` の optional field。完全 schema は
[`schemas/acceptance-context.v1.schema.json`](${CLAUDE_SKILL_DIR}/schemas/acceptance-context.v1.schema.json) を参照。

```json
{
  "blind_evaluation": {
    "applicable": true,
    "eligibility_reason": "persuasive-doc",
    "audience_purpose_line": "初めてこのプロダクトを検討する投資家。5分で読み切れて...",
    "evaluator_believable": "not_believable",
    "evaluator_useful": "not_useful",
    "evaluator_friction_points": ["引っかかった箇所の具体的な引用または要約"],
    "internal_recommendation": "ship",
    "divergence": "internal_high_evaluator_low",
    "divergence_notes": "verified_criteria は 5/5 で ship 相当だが、評価者は信頼できない/役に立たないと判定"
  }
}
```

| field | 型 | 意味 |
|---|---|---|
| `applicable` | bool | Eligibility を満たし評価者を実行したか。`false` なら以下は省略可 |
| `eligibility_reason` | enum | `persuasive-doc` (適用した) / `functional-skip` (機能系のため skip) / `not_applicable` / `unavailable` (Task tool 不在) |
| `audience_purpose_line` | string | 評価者に渡した読者像 1 行 (監査用にそのまま記録) |
| `evaluator_believable` | enum | 回答 1. をそのまま writeup。3択に沿わない応答は `uncertain` |
| `evaluator_useful` | enum | 回答 2. 同上 |
| `evaluator_friction_points` | string[] | 回答 3.（「なし」なら空配列） |
| `internal_recommendation` | enum | Step 5 の pending 補正後・blind_evaluation 補正前の interim recommendation |
| `divergence` | enum | `internal_high_evaluator_low` = interim が ship で評価者が not_believable/not_useful のいずれか。`internal_low_evaluator_high` = interim が wait/reject で評価者が believable かつ useful。それ以外 `none` |
| `divergence_notes` | string | divergence がある場合、何が食い違ったかを具体的に |

## Recommendation への反映

`blind-judge.md` の advisory-only とは異なり、ここでは divergence が recommendation を補正する。
詳細アルゴリズムは `SKILL.md` の「Recommendation 算出ロジック」参照。要点:

- `divergence == "internal_high_evaluator_low"` かつ interim recommendation が `ship` の場合、
  `wait` に丸める（`reject` へはさらに丸めない — blind evaluator は参考情報であり、reject 相当の
  強い否定は verified_criteria の実測に基づかせる）。
- `divergence == "internal_low_evaluator_high"` は recommendation を**引き上げない**（安全側）。
  observation として `recommendation_evidence` に記録するのみ。
- `divergence == "none"` または `applicable == false` の場合は補正なし。

`blind_evaluation_items` (0/1 件の derived array) は `divergence != "none"` のときだけ populate し、
HTML 側の「内側スコアとの乖離」セクションに表示する。

## フォールバック

- Task tool が使えない環境: `applicable: false`、`eligibility_reason: "unavailable"` とし、
  fake の評価結果を作らない。
- 評価者の応答が3点の形式に沿わない: そのまま `evaluator_friction_points` に生の応答を格納し、
  `evaluator_believable` / `evaluator_useful` は `"uncertain"` とする。`uncertain` は
  divergence 判定上 `not_believable` / `not_useful` として扱わない（false negative で
  recommendation を不必要に下げないため）。

## Related

- `skills/harness-review/references/blind-judge.md` — 設計上の先行実装。plain fresh sub-agent の原則と Judge Prompt Template の書式を継承
- `SKILL.md` の「Recommendation 算出ロジック」— pending 補正 (Phase 134.4) の後に blind_evaluation 補正 (Phase 137.2) を適用する順序を定義
- `.claude/rules/skill-editing.md` — `context: fork` の継承漏れ実測（Issue #84）
