# バージョニングルール

Harness のバージョン管理基準。SemVer（Semantic Versioning）に準拠する。

## バージョン判定基準

| 変更の種類 | バージョン | 例 |
|-----------|----------|-----|
| スキル定義（SKILL.md）の文言修正・追記 | **patch** (x.y.Z) | テンプレート微修正、説明文改善 |
| ドキュメント・ルールファイルの更新 | **patch** (x.y.Z) | CHANGELOG 書き換え、rules/ 追加 |
| hooks/scripts のバグ修正 | **patch** (x.y.Z) | task-completed.sh のエスケープ修正 |
| 既存スキルに新しいフラグ/サブコマンド追加 | **minor** (x.Y.0) | `--snapshot`、`--auto-mode` |
| 新しいスキル/エージェント/hooks 追加 | **minor** (x.Y.0) | 新スキル `harness-foo` |
| TypeScript ガードレールエンジンの変更 | **minor** (x.Y.0) | 新ルール追加、既存ルール変更 |
| Claude Code 新バージョン互換対応 | **minor** (x.Y.0) | CC v2.1.72 対応 |
| 破壊的変更（旧スキル廃止、フォーマット非互換） | **major** (X.0.0) | Plans.md v1 サポート削除 |

## 判断フローチャート

```
既存の動作が壊れる？
├─ Yes → major
└─ No → ユーザーが新しいことをできるようになる？
    ├─ Yes → minor
    └─ No → patch
```

## バッチリリースの推奨

- **同日に複数 Phase を完了した場合**: 1つの minor リリースにまとめる
- **Phase の完了 + ドキュメント修正**: Phase 分を minor、ドキュメント修正は同梱（別リリースにしない）
- **CC 互換対応 + 機能追加**: 1つの minor にまとめてよい

### 悪い例

```
v3.6.0 (03/08 AM) — Phase 25
v3.7.0 (03/08 PM) — Phase 26    ← 同日に 2 minor は避ける
v3.7.1 (03/09)    — Auto Mode
```

### 良い例

```
v3.6.0 (03/08) — Phase 25 + Phase 26    ← まとめて 1 minor
v3.6.1 (03/09) — Auto Mode 準備         ← prep は patch
```

## リリース前チェック

1. **前回リリースからの変更を一覧化**
2. **判定基準に照らしてバージョン種別を決定**
3. **同日の複数変更はバッチ化を検討**
4. **version 面の同期を確認** — 正本は `./scripts/sync-version.sh`（2026-07-16 現在: VERSION / .claude-plugin/plugin.json / .codex-plugin/plugin.json / .cursor-plugin/plugin.json / .grok-plugin/plugin.json / marketplace.json×2 / harness.toml の 7 文字列 6 ファイル + CHANGELOG compare link。対象が増えたら script 側を更新し、この行は数を数え直さない）
5. **git tag が欠番なく連続していることを確認**

## 禁止事項

- タグの削除・巻き戻し（公開済みバージョンは不変）
- 同日に 2 回以上の minor バンプ
- patch レベルの変更での minor バンプ

## Release Train Proposal

リリースは「コミット / PR ごと」ではなく、`CHANGELOG.md` の `[Unreleased]` に変更を溜め、
基準を満たしたら**候補を提案**し、人間が GO と言ったときだけ出す（細粒度リリースを避ける）。

- 蓄積層は `[Unreleased]` のみを触り、VERSION / plugin.json / harness.toml は bump しない。
- 提案器 `harness-release --check` は read-only。トリガー発火時に `RELEASE_CANDIDATE`
  （推定 bump 付）を表示するだけで、version 面を一切書き換えない。
- v1 トリガー（まず 1 ルールで始める）: 最終 tag から **7 日経過** OR `### Breaking` が
  `[Unreleased]` に存在。`### Security` があるときは **2 日**に短縮。N 件カウント等の
  多閾値マトリクスは、運用で cadence が問題化するまで足さない。
- 見出し照合は `### Breaking` の **prefix match**（`skills/harness-release/references/bump-detection.md`
  の正記法 `### Breaking Changes` も同一トリガーとして扱う）。実装正本は
  `go/internal/releasetrain`（`harness release --check`）。対象 tag は `v[0-9]` 始まりの
  semver tag のみ（`claude-code-harness--v*` の plugin tag は対象外）。
- これは gate ではなく**提案**。無視はノーコスト、次の閾値で再提案される。Session Monitor
  に tri-state（Candidate / None / NotApplicable）で受動表示し、
  `active-watching-test-policy.md` の 3 状態命名に従う（候補なしは silent）。
- 人間が GO したら既存 `harness-release` がそのまま走る（bump 検出 → sync-version.sh による全 version 面同期 →
  CHANGELOG promote → PR → main → tag → GitHub Release）。バッチ化は version 面同期を
  1 リリース 1 回に集約し、「同日 2 minor」違反を構造的に防ぐ。

## Plan B Stage B Release Trigger

Plan B 工程表の **stage b 完成** は minor リリース候補。

- 達成条件: Phase 92.x（base 衛生 + 実行時フロア + 集約硬化 + Producer 階層 + Mode 2 live-messaging）+
  Phase 93.x（/breezing MVP + 契約修正ラウンド）+ Phase 95.x（Bridge Daemon + Decision Card 本格版 + mem 読出層）+
  Phase 96.1.1-96.1.4（Risk Gate Export + 3 CLI hook parity + auto-approve opt-in + deny baseline hardening）が
  すべて `cc:done`、かつ 93.3.6 / 95.5.1 / 96.1.5 の検証セクションで evidence 付き完走判定。
- リリース判定: stage b 完成 = minor リリース候補のシグナル。実 GO 判断は `harness-release` 提案器の通常フローと統合する。
- Release Train v1 trigger（7 日経過 / Breaking / Security）との関係: stage b 完成は **追加の候補シグナル**であり、
  既存 v1 trigger を上書きしない。stage b 完成 + 既存 trigger が同時に成立すれば 1 minor バッチに集約する。
- Phase 94 (Release Train Proposal 実装) の本体実装は本 trigger の上に乗る — stage b は判断材料、Phase 94 は判定機構。
