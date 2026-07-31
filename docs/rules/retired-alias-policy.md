# Retired Alias Policy

Harness の **exclusion-based verification（削除済み alias の残骸チェック）** を運用するための SSOT。
Phase 97 で `templates/registry/retired-aliases.v1.yaml` + `bin/harness retired-alias scan` として再導入した。

## なぜこのルールが必要か

major migration 後は「新機能が動くか」の inclusion-based 検証だけでは、
削除済みパス・旧概念・退役コマンド名の**偶発残骸**を見逃しやすい。
v4.0.0 Hokage 直後に 13 件の v3 残骸が偶然発見された教訓から、
「削除したものが残っていないか」を逆方向に確認するゲートが必要になる。

## 5 つのルール

### ルール 1: 退役時は registry を同時更新する

「X を削除・改名・退役する PR」と「`retired-aliases.v1.yaml` への entry 追加」は
**同一 PR** で行う。削除だけ先に merge して registry 更新を後回しにしない。

### ルール 2: entry は schema 準拠 + reason 必須

`templates/schemas/retired-alias.v1.json` に従い、`id` / `kind` / `pattern` を必須とする。
`reason` には「なぜ退役したか」を書く。allowlist は prefix match で最小粒度に保つ。

### ルール 3: allowlist は 3 原則

- **歴史記述**: `CHANGELOG.md`、`.claude/memory/archive/` は常に allowlist 対象
- **移行ガイド**: `docs/MIGRATION-*.md` など旧→新の対比文書
- **個別文脈**: 特定ファイルでの意図的言及のみ prefix で追加（ディレクトリ丸ごと禁止）

### ルール 4: retroactive validation を実施する

新 entry 追加後、過去コミットで `harness retired-alias scan` を走らせ、
期待どおり残骸が検出されることを確認する。0 件しか出ない場合は
allowlist が広すぎるか pattern が弱い可能性がある。

### ルール 5: false positive ゼロ（HEAD は常に 0 件）

現 HEAD で scan したとき **ヒット 0 件** を維持する。
ヒットした場合は (1) 真の残骸を修正、(2) 正当な歴史記述なら allowlist 追加、
(3) pattern 誤りなら entry を修正、のいずれかで解消する。

## exclusion-based verification の運用

| 操作 | コマンド / ゲート |
|------|-------------------|
| ローカル確認 | `bin/harness retired-alias scan` |
| CI | `scripts/ci/check-consistency.sh` retired-alias section |
| 正本 registry | `templates/registry/retired-aliases.v1.yaml` |
| schema | `templates/schemas/retired-alias.v1.json` |

scanner は固定文字列（grep -F 相当）で repo を走査し、
entry ごとの allowlist（+ グローバル allowlist）で prefix 除外する。
1 件でもヒットすれば exit 1。

## 更新手順

1. 退役対象を特定し `kind`（`path` / `concept` / `command` / `skill`）を選ぶ
2. `templates/registry/retired-aliases.v1.yaml` に entry を追加
3. `cd go && go test ./internal/retiredalias/...` で schema / HeadZeroHits を確認
4. `bin/harness retired-alias scan` が 0 件であることを確認
5. PR に Before/After（削除理由 + 代替）を CHANGELOG `[Unreleased]` に追記

旧 `deleted-concepts.yaml` + `check-residue.sh`（Phase 40、Phase 91.7 で撤去）の
思想を Go selfaudit 層へ最小スコープで再導入した現行版である。
