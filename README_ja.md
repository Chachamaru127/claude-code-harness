# Claude Code Harness

<p align="center">
  <img src="docs/images/claude-harness-logo-with-text.png" alt="Claude Harness" width="400">
</p>

<p align="center">
  <strong>Plan. Work. Review. Ship.</strong><br>
  <em>Claude Code の作業を、計画・実装・レビュー・出荷まで崩れにくくする Harness。</em>
</p>

<p align="center">
  <a href="https://github.com/Chachamaru127/claude-code-harness/releases/latest"><img src="https://img.shields.io/github/v/release/Chachamaru127/claude-code-harness?display_name=tag&sort=semver" alt="Latest Release"></a>
  <a href="LICENSE.md"><img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License"></a>
  <a href="docs/CLAUDE_CODE_COMPATIBILITY.md"><img src="https://img.shields.io/badge/Claude_Code-v2.1+-purple.svg" alt="Claude Code"></a>
  <img src="https://img.shields.io/badge/Skills-5_Verbs-orange.svg" alt="Skills">
  <img src="https://img.shields.io/badge/Core-Go_Native-00ADD8.svg" alt="Go Core">
</p>

<p align="center">
  <a href="README.md">English</a> | 日本語
</p>

<p align="center">
  <img src="docs/images/readme/hero-operating-loop-ja.png" alt="Claude Code Harness の作業ループ: 仕様、計画、実装、レビュー、出荷" width="900">
</p>

Claude Code は強力ですが、そのままだと計画が会話に埋もれ、検証が後回しに
なり、レビューとリリース判断が毎回やり直しになりがちです。Harness はその
流れを、最初から「確認できる作業手順」に変えます。

導入後の標準は、ただ「AI に実装して」と頼むことではありません。

1. 仕様と計画を作る。
2. 承認した範囲だけ実装する。
3. 結果を検証する。
4. 実装者とは別の視点でレビューする。
5. PR やリリースに必要な根拠をまとめる。

## 最短導入

新規ユーザーは、今使っている tool から始めます。既存ユーザーは、削除や
再インストールの前に migration report を出します。

| 導線 | 開始場所 |
|---|---|
| 新規ユーザー | [Tool-first onboarding](docs/onboarding/index.md) |
| 既存ユーザー | [Migration check](docs/onboarding/migration.md) |
| Claude Code 30秒導入 | [30秒でインストール](#30秒でインストール) |
| Trigger 確認 | [Skill trigger gate](docs/onboarding/skill-trigger-acceptance.md) |

## 30秒でインストール

```bash
claude
/plugin marketplace add Chachamaru127/claude-code-harness
/plugin install claude-code-harness@claude-code-harness-marketplace
/harness-setup
```

次に実行するのは、小さな要望を渡す `/harness-plan` です。

```bash
/harness-plan README の導入説明を改善したい
```

## 最初の15分

1. 使う tool の導線で導入する。
2. `/harness-setup` または同等の setup script を実行する。
3. `/harness-plan` に小さな要望を渡す。Harness が `spec.md` と
   `Plans.md` の draft を作るので差分を確認する。typo、docs、status 更新
   のような軽量作業は軽い導線のままです。
4. 生成された正本を承認するか、直したい点を返す。
5. 承認済みの最小 task を、たとえば `/harness-work 1.1.1` のように実行する。
6. `/harness-review` を走らせ、検証出力を残す。

あなたが一から手で plan を書く前提ではありません。役割は、生成された
正本の差分を承認するか、直すべき点を返すことです。

## 中で何が起きるか

Harness は agent 作業の前後に、正本と検証の loop を置きます。
基本は plan、work、review、sync、release の 5動詞スキルで動かす 5動詞ワークフローです。

1. あなたは作りたい結果を普通に伝える。
2. `/harness-plan` が `spec.md` と `Plans.md` を作成・更新し、範囲、
   受入条件、未確認事項、止める条件を書き出す。
3. 単発・軽微でない計画では `team_validation_mode` を残し、TeamAgent /
   サブエージェント、または manual-pass の視点で、spec/Plans 整合、memory
   再利用、product fit、security fit、works-in-practice を確認する。
4. Harness はその2ファイルを正本として読み、AI が見ていない情報は
   勝手に補わず `unknown` のまま扱う。
5. `/harness-work` が承認された範囲だけを TDD と検証つきで実装する。
6. `/harness-review` が実装とレビューを分離する。
7. `/harness-release` が検証済み evidence だけを出荷用にまとめる。

## コマンド

| コマンド | 中でやること |
|----------|--------------|
| `/harness-setup` | プロジェクトのガイド、コマンド面、フック、基本チェックを揃え、同じ前提で作業を始められるようにする。 |
| `/harness-plan` | 要望を `spec.md` と `Plans.md` に落とし、範囲、受入条件、依存、未確認事項、止める条件、非軽量計画の validation を明示する。 |
| `/harness-work` | 承認済みの1タスクまたは範囲だけを実行し、必要なテストと検証を残す。 |
| `/harness-work all` | 承認済み計画を実装・レビューの流れに通す。計画と repo baseline が見えてから使う。 |
| `/harness-review` | 実装とは別の立場で結果を確認し、重大な指摘を完了前の blocker として扱う。 |
| `/harness-release` | 実装とレビューの後に、release readiness、CHANGELOG、tag、evidence package を確認する。 |
| `bin/harness doctor --migration-report` | 古い plugin cache、Codex skills、OpenCode files、symlink、memory state を削除なしで棚卸しする。 |

## 基本フロー

| 段階 | 出力 | 合格条件 |
|------|------|----------|
| 調査 | 根拠と unknown | 見ていない情報を claim にしない。 |
| 計画 | `spec.md` + `Plans.md` | 生成された正本をユーザーが承認または修正する。 |
| 実装 | code と tests | task が要求する場合は TDD。 |
| レビュー | 独立 verdict | major finding は完了前に止める。 |
| PR | evidence pack | PR ready と release ready を混同しない。 |
| Release | tag / release artifact | release path の preflight を通す。 |

## ツール別の導入

| Tool | Tier | Route |
|---|---|---|
| Claude Code | `supported` | Claude plugin marketplace から導入し、`/harness-setup`。 |
| Codex CLI | `internal-compatible` | `scripts/setup-codex.sh --user`; direct plugin smoke は別 gate。 |
| Codex app | `candidate` | candidate smoke のみ。Codex CLI proof を流用しない。 |
| OpenCode | `internal-compatible` | `scripts/setup-opencode.sh`; runtime parity は主張しない。 |
| Cursor | `candidate` | PM handoff または adapter research のみ。 |
| GitHub Copilot CLI | `candidate` | manual profile research のみ。 |
| Antigravity CLI | `future/unsupported` | この phase では end-user install route なし。 |

## 既存ユーザーの移行

既存環境では `bin/harness doctor --migration-report` を先に実行します。
古い Claude plugin cache、重複 Codex skills、旧 symlink、OpenCode backup
path、harness-mem state を削除なしで棚卸しします。

## サポート境界

Harness は候補 host の導線を説明できますが、Superpowers や Hermes Agent
など他プロジェクトの実績を自分のサポート実績としては扱いません。各 host は、
Harness 自身の bootstrap、trigger、runtime、release evidence が揃った時だけ
tier を上げます。

`not_observed != absent`: この環境で未観測なら「未証明」です。「存在しない」
でも「証明済み」でもありません。

## 動作要件

- supported な Claude 導線では Claude Code v2.1+。
- local setup を行うための書き込み可能な project repo。
- 配布時の既定言語は English。日本語 UI を明示する場合は `CLAUDE_CODE_HARNESS_LANG=ja claude` で起動。
- Go ネイティブガードレールエンジンは Node.js 不要。
- 任意で [harness-mem](https://github.com/Chachamaru127/harness-mem) を使うと、
  healthy に設定されている時だけセッション横断の記憶を扱える。

## 高度な使い方

基本の trigger path が見えてから使います。

| 機能 | 何が増えるか | 境界 |
|------|--------------|------|
| Breezing | 大きめの task list に Planner / Critic / Worker 型のチーム実行を足す。 | 計画品質と review gate は残る。 |
| Codex companion review | `scripts/codex-companion.sh` 経由で schema-backed な Codex second opinion を得る。 | raw `codex exec` は Harness companion path ではない。 |
| OpenCode bootstrap | Harness guidance を OpenCode 互換の面へ mirror する。 | real runtime parity は主張しない。 |
| harness-mem | project-scoped memory と session 間 recall を足す。 | 任意 companion。purge は必ず明示操作。 |

## ドキュメント

| リソース | 説明 |
|----------|------|
| [Tool-first onboarding](docs/onboarding/index.md) | 使う tool 別の開始地点。 |
| [Install routes](docs/onboarding/install.md) | tool 別 setup と support tier の境界。 |
| [Migration check](docs/onboarding/migration.md) | 既存ユーザーへの影響、互換性、rollback。 |
| [Skill trigger gate](docs/onboarding/skill-trigger-acceptance.md) | 導入後に skill / workflow が使えるかの確認。 |
| [Capability matrix](docs/tool-capability-matrix.md) | supported / internal-compatible / candidate / unsupported の根拠。 |
| [Claude Code Compatibility](docs/CLAUDE_CODE_COMPATIBILITY.md) | Claude Code 要件と互換性メモ。 |
| [Cursor Integration](docs/CURSOR_INTEGRATION.md) | Cursor handoff 境界と candidate route メモ。 |
| [Distribution Scope](docs/distribution-scope.md) | 配布対象 / 互換維持 / 開発専用の境界。 |
| [Hardening parity](docs/hardening-parity.md) | Claude hooks と Codex gates の安全境界の違い。 |
| [Work All Evidence Pack](docs/evidence/work-all.md) | full-plan 実行の成功系/失敗系検証契約。 |
| [Changelog](CHANGELOG.md) | ユーザー向け変更履歴。 |

## コントリビュート

Issue と PR を歓迎します。[CONTRIBUTING.md](CONTRIBUTING.md) を参照。

## 謝辞

- [AI Masao](https://note.com/masa_wunder) - 階層的スキル設計
- [Beagle](https://github.com/beagleworks) - テスト改ざん防止パターン

## ライセンス

MIT License。[LICENSE.md](LICENSE.md) を参照。
