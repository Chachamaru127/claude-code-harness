# create サブコマンド — 計画作成フロー

アイデア・要件をヒアリングし、実行可能な Plans.md を生成する。

## Step 0: 会話コンテキスト確認

直前の会話から要件を抽出できる場合は確認する:

> 計画の作り方を選んでください:
> 1. 直前の会話から — ブレスト内容をベースに計画を作成
> 2. ゼロから — ヒアリングから開始

「直前の会話から」の場合: 要件・アイデア・決定事項を抽出してユーザーに確認。
確認後、Step 3（技術調査）にスキップ。

## Step 1: 何を作るか聞く

ユーザー入力がなければ質問する:

> 何を作りますか？
>
> 例: 予約管理システム / ブログサイト / タスク管理アプリ / APIサーバー
>
> ラフなアイデアで OK！

## Step 2: 解像度を上げる（最大3問）

> もう少し教えてください:
>
> 1. 誰が使いますか？（自分だけ？チーム？一般公開？）
> 2. 参考にしたいサービスはありますか？
> 3. どこまで作りますか？（MVP？フル機能？）

## Step 3: 計画品質チェック

詳細: `references/planning-quality.md`

ユーザーが渡した情報をそのまま Plans.md に落とさない。
外部プロダクト、競合、仕様案、改善案、比較材料が含まれる場合は、最新情報・既存仕様・記憶・TeamAgent / サブエージェント複数視点レビューで確認し、取り入れるべき要素だけを task contract にする。
単発・軽微ではない planning は、TeamAgent またはサブエージェント前提で扱う。

最低限の確認:

- 最新情報: WebSearch / 公式 docs / 一次情報を優先し、重要点は複数ソースで確認する
- 既存仕様: Plans.md、README、docs、CLAUDE.md、関連 skill、tests を確認する
- 記憶: harness-mem / harness-recall / `.claude/agent-memory/` / `.claude/state/` が使える場合は project-scoped で確認し、車輪の再発明を避ける
- 議論: Product / Architecture / Security / QA / Skeptic の視点で採用価値とリスクを分ける
- 品質土台: source code changes を含む plan では `formatter_baseline` を確認し、lint / formatter が未設定なら setup task を先行させる
- 実装プラン検証: product fit、security fit、works in practice を確認し、test / smoke / CI / review / release gate を DoD に落とす
- 採点: Product Fit、Evidence Strength、User Value、Implementation Feasibility、Regression Safety、Strategic Leverage、Security Safety、Works In Practice を 5 点満点で見る

`harness-mem` の DB は直接読まない。検索や documented memory surface が使えない場合は「記憶未確認」と明示する。
Task tool が使えない場合は `サブエージェント未使用` と明示し、同じ観点を単独で分けて評価する。
`team_validation_mode` は `not_required_lightweight` / `native` / `subagent` / `manual-pass` / `unavailable` のいずれかを出す。
non-trivial planning では `native` / `subagent` / `manual-pass` のいずれかを使い、`unavailable` のまま Required にしない。
Product / Architecture / Security / QA / Skeptic は perspective 名であり agent_type 名ではない。
Security gate は `.env` や secret の実読取を要求しない。

小さな typo、format、README/CHANGELOG、marker 更新だけならこの step は軽く済ませてよい。

## Step 4: 技術調査（WebSearch）

ユーザーには聞かず、Claude Code が調査・提案する。

```
WebSearch:
- "{{プロジェクトタイプ}} tech stack 2025"
- "{{類似サービス}} architecture"
```

## Step 4.4: spec.md / Plans.md 二正本チェック

Plans.md は「やるべきこと」を固定する task contract。
root `spec.md` は「何が正しいか」を固定する product contract。
この 2 つを混ぜない。`/harness-plan create` は Plans.md 生成コマンドではなく、spec.md product contract and Plans.md task contract の co-required planning output を返す surface として扱う。
precedence は `spec.md > sub-spec > Plans.md` のまま維持する。

`/harness-plan create` の出力は必ず次の 2 点セット:

1. `Spec delta` または `Spec skip reason`
2. `Plans.md` task 生成

root `spec.md` を毎回読む。実装判断がぶれそうな場合は、Plans.md を作る前に root `spec.md` を更新する。
ユーザーに spec を一から書かせない。`Spec delta` / `Spec skip reason` は Harness が生成し、consumer は承認・修正だけ行う。
agent が既存 spec、repo evidence、記憶、テスト、入力要件から最小の delta を draft し、判断が割れる時だけ選択肢を出す。

### 仕様正本を作る/更新する条件

- ユーザーに見える振る舞いが増える、または変わる
- API、データモデル、権限、課金、外部連携、tenant boundary を決める
- 複数の実装案があり、選び方で product behavior が変わる
- 過去または今回の会話で、仕様の曖昧さによる実装 drift が見えている
- Plans.md には task があるが、project としての正解条件が文書化されていない

### スキップしてよい条件

- typo / format / lint のみ
- dependency bump のみ
- README / CHANGELOG のみ
- docs-only / mechanical task
- 動作変更なしの狭い refactor
- 既存 spec とテストで正解が明確

スキップ時も `Spec skip reason` を省略しない。
docs-only / mechanical task でも task context / sprint contract に skip reason を残す。

### 保存先

最優先は root `spec.md`。
consumer repo に root `spec.md` がない時だけ、既存の project-level spec を fallback として更新する。
root `spec.md` も既存 project spec もなければ次を作る:

```text
docs/spec/00-project-spec.md
```

最初の spec は短くてよい。最低限、Purpose、Users And Workflows、Core Rules、Data And Contracts、Non-Goals、Open Decisions、Links を置く。

詳細: `docs/plans/spec-ssot.md`

## Step 4.6: lint / formatter baseline チェック

source code changes を含む plan では、実装 task を作る前に lint / formatter baseline を確認する。
これは「綺麗にする作業」ではなく、実装後に Yes/No で品質確認できる土台を先に作るための gate である。

確認するもの:

- JavaScript / TypeScript: `package.json` の `lint` / `format` scripts、ESLint / Prettier / Biome / Oxlint / dprint の config または dependency
- Python: `pyproject.toml` の Ruff / Black / isort / mypy などの config
- Go: `gofmt` / `go test` / `go vet` / lint 相当の CI command
- Rust: `cargo fmt` / `cargo clippy` / `cargo test`
- 既存 CI: `.github/workflows`、`scripts/ci/*`、`Makefile` などの品質 command

出力には `formatter_baseline` を残す:

```text
formatter_baseline: configured | missing | not_applicable | unknown
formatter_baseline_evidence: [見た file / command]
formatter_baseline_action: none | add_setup_task | skip_with_reason | spike
```

未設定かつ source code changes を含む場合は、Plans.md の実装 task より前に setup task を追加する。
setup task の DoD は「config / script / validation command が揃い、広範囲の一括 reformat は明示 scope 外にする」こと。
planning では package install しない。導入作業は harness-work が setup task として実行する。

スキップしてよい条件:

- docs-only / markdown-only / changelog-only
- 既存 lint / formatter / CI command があり、今回の変更で触る言語を十分に覆っている
- consumer repo の制約で導入不可の場合。ただし `formatter_baseline_action: spike` または skip reason を残す

## Step 5: 機能リスト抽出

要件から具体的な機能リストを抽出する。

例: 予約管理システムの場合
- ユーザー登録/ログイン
- 予約カレンダー表示
- 予約の作成/編集/キャンセル
- 管理者ダッシュボード
- メール通知
- 決済機能

## Step 5.5: optional brief 生成

必要なときだけ brief を添える。brief は Plans.md を置き換えず、実装の前提を短く固定する補助資料。

- UI を含むタスクでは `design brief`
- API を含むタスクでは `contract brief`
- UI と API が混在する場合は brief を分ける

### design brief

UI タスク向けの brief には、最低限次を入れる:

- 何を達成したいか
- 誰が使うか
- 重要な画面状態
- 見た目や操作感の制約
- 完了条件

### contract brief

API タスク向けの brief には、最低限次を入れる:

- 何を受け取るか / 返すか
- 入力検証の条件
- 失敗時の振る舞い
- 外部依存
- 完了条件

## Step 6: 優先度マトリクス作成（2 軸評価）

各機能を **Impact（影響度）× Risk（リスク/不確実性）** の 2 軸で評価する:

- **Impact**: ユーザー価値 × 対象ユーザー数（高/低）
- **Risk**: 技術的未知 × 外部依存（高/低）

| Impact＼Risk | 低リスク | 高リスク |
|-------------|---------|---------|
| **高 Impact** | ★ **Required** — 最優先（確実に価値が出る） | ▲ **Required + [needs-spike]** — 早期検証が必要 |
| **低 Impact** | ○ **Recommended** — 余力で対応 | ✕ **Optional** — 見送り or スコープ縮小 |

### `[needs-spike]` マーカー

高 Impact × 高 Risk のタスクには `[needs-spike]` マーカーを自動付与する。
`[needs-spike]` が付いたタスクには、**spike（技術検証）タスク** を自動生成して先行させる:

```markdown
| N.X-spike | [spike] {{タスク名}} の技術検証 | 検証結果レポート作成 | - | cc:TODO |
| N.X       | {{タスク名}} [needs-spike] | {{DoD}} | N.X-spike | cc:TODO |
```

spike タスクの完了条件は「検証結果レポート（実現可能/不可能/要設計変更）を残す」こと。

## Step 6.5: TDD スキップ判断（デフォルト有効）

TDD はデフォルトで有効。以下のいずれかに該当するタスクのみ `[skip:tdd]` マーカーを付与してスキップ:

| スキップ条件 | 理由 |
|-------------|------|
| ドキュメント/コメントのみ | 実行コードに影響しない |
| 設定ファイルのみ（JSON, YAML, .env） | テスト対象のロジックがない |
| 1行以下の単純修正（typo） | テストコストが効果を上回る |
| スタイル/フォーマット変更のみ | 動作に影響しない |
| 依存関係更新のみ | 実装ロジック変更なし |
| README/CHANGELOG 更新 | ドキュメントのみ |
| リファクタリング（動作変更なし） | 既存テストでカバー済み |

上記に該当しないタスクは TDD が自動適用される（テスト先行を推奨）。

## Step 6.7: Plans.md v3 フォーマット仕様

Plans.md v3 は以下のフォーマット拡張を含む:

### Phase ヘッダーの Purpose 行（任意）

各 Phase のヘッダーに、1 行の Purpose（目的）を記載できる。入力がない場合は省略する:

```markdown
### Phase N.X: [フェーズ名] [Px]

Purpose: [このフェーズが解く課題を 1 行で]
```

- **デフォルト**: 入力を求めない（空欄で省略）
- **記載時の効果**: breezing Phase 0 のスコープ確認で表示される
- **生成ルール**: ユーザーがフェーズの目的を明示的に述べた場合のみ自動記載

### Artifact 表記（Status カラム）

タスク完了時に commit hash を Status に付与する:

```markdown
| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1.1  | ... | ... | - | cc:完了 [a1b2c3d] |
| 1.2  | ... | ... | 1.1 | cc:TODO |
```

- **形式**: `cc:完了 [7文字hash]`
- **付与タイミング**: `harness-work` Solo Step 7 で自動付与
- **後方互換**: hash なし `cc:完了` も引き続き有効

### 影響ファイル一覧

v3 フォーマットに関連するファイル:

| ファイル | 影響 |
|---------|------|
| `skills/harness-plan/references/create.md` | Step 6 テンプレートに Purpose 行を追加 |
| `skills/harness-plan/references/sync.md` | 差分検出で `cc:完了 [hash]` 形式を認識 |
| `skills/harness-work/SKILL.md` | Solo Step 7 で hash 付与、失敗時再チケット化 |
| `skills/harness-sync/SKILL.md` | --snapshot でスナップショット保存 |
| `skills/breezing/SKILL.md` | Progress Feed で進捗表示 |

## Step 7: Plans.md 生成

先に `Spec delta` または `Spec skip reason` を出し、その後に品質マーカー + DoD + Depends を自動生成して Plans.md を生成する。

### Spec result 出力

`Spec delta` / `Spec skip reason` は Harness が生成し、consumer は承認・修正だけ行う。

```markdown
Spec delta:
- path: spec.md
- change: [追加/変更する product rule]
- why: [この task contract の前提として必要な理由]

Plans.md:
| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
```

```markdown
Spec skip reason:
- path checked: spec.md
- reason: [docs-only / mechanical task / 既存 spec とテストで正解が固定済み]
- preserve in: task context or sprint contract

Plans.md:
| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
```

### 品質マーカー付与ロジック
```
タスク内容を分析
    ↓
├── "auth" "login" "API" → [feature:security]
├── "component" "UI" "screen" → [feature:a11y]
├── "fix" "bug" → [bugfix:reproduce-first]
├── "docs" "comment" "README" "CHANGELOG" → [skip:tdd]
├── "config" "json" "yaml" "env" → [skip:tdd]
├── "style" "format" "lint" → [skip:tdd]
├── "refactor" (動作変更なし) → [skip:tdd]
├── "payment" "billing" → [feature:security]
└── その他 → マーカーなし（TDD はデフォルト有効）
```

### DoD 自動推論ロジック

タスクの「内容」からキーワードベースで DoD を推論し、自動埋めする:

| タスク内容のキーワード | DoD 推論 |
|---------------------|---------|
| "作成" "新規" "追加" | ファイルが存在し、期待する構造を持つ |
| "テスト" "test" | テスト通過（`npm test` / `pytest` 等） |
| "修正" "fix" "bug" | 問題が再現しなくなる |
| "UI" "画面" "コンポーネント" | 表示確認（スクリーンショット or ブラウザ） |
| "API" "エンドポイント" | curl/httpie でレスポンス確認 |
| "設定" "config" | 設定値が反映される |
| "ドキュメント" "docs" | ファイルが存在し、リンク切れなし |
| "マイグレーション" "DB" | マイグレーション実行可能 |
| "リファクタリング" | 既存テスト全通過 + lint エラー 0 |

推論結果はあくまでデフォルト値。ユーザーが具体的な受入条件を指定した場合はそちらを優先する。

### Depends 自動推論ロジック

フェーズ内のタスク間の依存関係を以下のルールで推論する:

1. **DB/スキーマ系タスク** → 他の実装タスクから依存される（先行タスク）
2. **UI タスク** → API/ロジック タスクに依存（後行タスク）
3. **テスト/検証タスク** → 実装タスクに依存（最後尾）
4. **設定/環境タスク** → 他タスクから依存される（先行タスク）
5. **明確な依存がないタスク** → `-`（並列実行可能）

推論に自信がない場合は `-` にして、ユーザーに確認を求める。

**生成テンプレート**:

```markdown
# [プロジェクト名] Plans.md

作成日: YYYY-MM-DD

---

## Phase 1: [フェーズ名]

Purpose: [フェーズの目的（省略可）]

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1.1  | [タスク説明] [feature:security] | [検証可能な完了条件] | - | cc:TODO |
| 1.2  | [タスク説明] | [検証可能な完了条件] | 1.1 | cc:TODO |
```

**Purpose 行**:
- ユーザーがフェーズの目的を述べた場合のみ自動記載
- 入力がなければ Purpose 行ごと省略（空行にしない）
- 1 行で完結させる（複数行禁止）

**DoD（Definition of Done）記法**:
- 検証可能な1行で書く（例: 「テスト通過」「マイグレーション実行可能」「lint エラー 0」）
- 「いい感じ」「ちゃんと動く」は禁止。Yes/No で判定できる形にする

**Depends 記法**:
- 依存なし: `-`
- 単一依存: タスク番号（例: `1.1`）
- 複数依存: カンマ区切り（例: `1.1, 1.2`）
- フェーズ依存: フェーズ番号（例: `Phase 1`）

### Team mode output

ユーザーが team mode を明示した場合だけ、Plans.md と別に issue bridge の dry-run も案内する。

- tracking issue は 1 つだけ
- task ごとの sub-issue payload を並べる
- Plans.md は正本のまま維持する
- `scripts/plans-issue-bridge.sh --team-mode` の dry-run をそのまま使える形で案内する

## Step 8: セッション起動コマンドと最初の入力を必ず案内する

Plans.md を出した直後に、ユーザーが次の一歩で迷わないよう、
**新しいセッションの起動コマンド** と
**起動後にそのまま入れる最初の入力** をセットで案内する。

### 出し方のルール

1. 少なくとも 1 組は具体的な起動コマンド + 最初の入力を書く
2. 可能なら「最有力 1 組 + 代替 1 組」までに絞る
3. コマンドだけでなく、なぜその組み合わせなのかを 1 行で添える
4. 長時間タスクなら `bash scripts/claude-longrun.sh` を先に案内する

### 推奨マッピング

| 状況 | 起動コマンド | 最初の入力 |
|------|--------------|------------|
| 最初の 1 タスクから始める | `claude` | `/harness-work 1.1` のような単一 task 実行 |
| 複数 task をまとめて進める | `claude` | `/breezing all` |
| 直列で全部進めたい | `claude` | `/harness-work all` |
| 長時間・再入前提 | `bash scripts/claude-longrun.sh` | `/harness-loop all` |

### 出力例

```text
次の一歩:
- 新しいセッションの起動コマンド: claude
- 起動後の最初の入力: /breezing all
- 向いている場面: 今回の Plans.md は複数 task をまとめて進める構成なので、チーム実行が一番自然です
```

```text
次の一歩:
- 新しいセッションの起動コマンド: bash scripts/claude-longrun.sh
- 起動後の最初の入力: /harness-loop all
- 向いている場面: 長時間タスクで、5 分を超える待機や再開が起こりやすいためです
```

## Step 9: 次のアクション案内

> Plans.md 完成！
>
> 次のステップ:
> - `harness-work` で実装開始
> - または「Phase 1 から始めて」と言う
> - 機能の追加は `harness-plan add [機能名]`
> - 機能の後回しは `harness-plan update [タスク] blocked`

## CI モード（--ci）

ヒアリングなし。既存の Plans.md をそのまま利用してタスク分解のみ行う。

1. Plans.md を読み込む
2. cc:TODO タスクを優先度順にリスト化
3. 並列可能なタスクに `[P]` マークを付与
4. 次の実行タスクを提案
