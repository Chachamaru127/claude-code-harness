# Migration Residue Policy

Harness の **exclusion-based verification（削除済み概念の残骸チェック）** を運用するためのポリシー。
Phase 40 (v4.1.0) で導入された `deleted-concepts.yaml` + `check-residue.sh` の
運用ルールを定義する。

## なぜこのルールが必要か

v4.0.0 "Hokage" リリース直後、TypeScript から Go への全面移行は「完了」のはずだった。
ところが、リリース後 2 日間で 13 件もの「旧時代の残骸」が次々と見つかった。
テストスクリプトの中に消えたはずのファイルパス、ドキュメントに残る旧バージョン名、
Node.js が必要と書かれた README — これらはいずれも個別のレビューや「X が含まれているか」という
確認では見つけられないものだった。

「大きな移行をした後、本当に古いものが残っていないか」を確かめるには、
「削除したものが残っていないか」という逆方向の確認（exclusion-based verification）が必要になる。
このルールを守れば、次回以降の major migration で同じ失敗は再発しない。

## 5 つのルール

### ルール 1: major version migration 時は必ず deleted-concepts.yaml を更新する

「X を削除する PR」と「X を deleted-concepts.yaml に追加する PR」は同時に
出す。遅延は禁止。

**なぜ**: 削除してから yaml 更新を後回しにすると、その間に別の PR で X への
参照が混入し、気づかないまま merge されてしまう。yaml 更新を削除 PR に
同梱することで「削除 = スキャン対象化」を不可分な 1 トランザクションにする。

### ルール 2: 更新タイミングは「削除 PR と同時」

ルール 1 の強い形。例: TypeScript guardrail engine を削除する PR を出すなら、
同じ PR で `deleted_concepts` に `"TypeScript guardrail engine"` を追加する。

「削除した」と「スキャン対象にした」は必ずセットで完了する。どちらか片方だけでは半分しか終わっていない。

### ルール 3: allowlist は 3 つの原則で運用する

deleted-concepts.yaml の `allowlist` フィールドには以下を含めてよい:

- **歴史記述**: CHANGELOG.md、`.claude/memory/archive/` は常に allowlist。
  「過去にこういうものがあった」と記録することは正当な言及であり、残骸ではない。
- **移行ガイド**: `docs/MIGRATION-*.md` のように旧 → 新の対比を書く文書。
  比較表の中で旧名称を挙げることは意図的な記述。
- **個別文脈**: ある特定の文書で旧概念への言及が**意図的に正当**な場合。
  例: `.claude/memory/archive/v3-architecture.md` は v3 アーキテクチャの歴史記録なので
  `"Harness v3"` を含んでいて当然。

allowlist は prefix match で適用される。エントリの**粒度は最小に保つ**こと。
`CHANGELOG.md` 全体を allowlist に入れるのは正当だが、
`docs/` ディレクトリ全体を入れるのは過剰であり、scanner を無意味化する。

### ルール 4: retroactive validation（過去コミットへの遡及検証）を必ず実施する

新しい deleted-concepts.yaml エントリを追加したら、**過去のコミットに遡って
scanner を走らせ、想定通りに残骸が検出されるか**を確認する:

```bash
git checkout <past-commit>
bash scripts/check-residue.sh
# → 期待件数検出（0 件以上であること）
git checkout -
```

これで「yaml が本当に問題を検出できるか」を検証できる。
検出されない場合、allowlist の書き方が広すぎるか、パターンが誤っている可能性がある。
偶然パスするような false allowlist を早期発見するのが目的。

### ルール 5: false positive ゼロ（現 HEAD は常に 0 件）を保つ

現 HEAD で scanner を実行したとき、**検出件数は常に 0** でなければならない。
検出された場合は以下のいずれかで対処する:

1. **真の残骸** なら即修正（ファイルを修正して旧参照を削除）
2. **歴史記述等で allowlist に追加すべき** なら yaml を更新
3. **誤分類**（yaml のパターンが意図せず一致している）なら yaml から削除

CI (validate-plugin.sh のセクション 9) と release preflight (harness-release の Phase 0)
の両方で自動チェックされているので、**merge 前に 0 件であることが保証される**。

## 付録: 今セッション (v4.0.0 → v4.0.1) の 13 件の v3 残骸事例

Phase 40 の動機となった事例。**この機能がなぜ生まれたかのストーリー。**

### 発見経緯

v4.0.0 "Hokage" リリース (2026-04-09) は TypeScript 実装から Go ネイティブ実装への
全面移行だった。移行そのものは完遂したが、**テストスクリプト、ドキュメント、SKILL.md の
あちこちに TypeScript 時代の参照が残骸として残っていた**。
これらは以下の経路で偶然発見された:

1. テスト実行で失敗 → validate-plugin.sh / check-consistency.sh が落ちる
2. ユーザーがスラッシュパレットで気づく → SKILL.md frontmatter の "Harness v3"
3. コードレビューで発見 → agents/*.md の v3 narrative
4. ドキュメントレビュー → README.md の core/ engine 言及

「偶然見つかった」ことが問題だ。仕組みがなければ次のリリースでも同じことが起きる。

### 13 件の分類

| カテゴリ | 件数 | 代表例 |
|---------|------|--------|
| 削除済みパス参照 | 2 | `core/src/guardrails/rules.ts` |
| 削除済み概念語 | 3 | "TypeScript guardrail engine" |
| SKILL.md バージョンサフィックス | 2 | `# Harness Work (v3)` |
| 旧ランタイム要件 | 1 | "Node.js 18+ is installed" |
| 歴史テーブル | 1 | README ファイルツリーの `core/` |
| その他（個別書式バグ） | 4 | README 重複行、日本語/英語 drift |

### 教訓

この 13 件は全て **inclusion-based verification**（「X が含まれるか」という確認）では
検出不可能だった。なぜなら「X が残っていない」という確認は、
あらかじめ「X は削除した」という知識がなければ行えないからだ。

**exclusion-based verification**（「削除済みの X が残っていないか」という逆方向の確認）の
視点が必要。Phase 40 はその視点を Harness の検証層に組み込むために生まれた。

## 関連ファイル

- `.claude/rules/deleted-concepts.yaml` — 削除済みパス/概念の SSOT カタログ
- `scripts/check-residue.sh` — scanner 実装（false positive は即 0 に保つ）
- `go/cmd/harness/doctor.go` — `bin/harness doctor --residue` フラグ
- `tests/validate-plugin.sh` — Section 9: Migration residue check（CI ゲート）
- `skills/harness-release/SKILL.md` — Phase 0 preflight step 2（リリースゲート）
