# Plugin and Managed Settings Policy

最終更新: 2026-05-03

この文書は Claude Code `2.1.117-2.1.126` で増えた plugin / managed settings / managed sandbox まわりの運用判断を、Harness の setup guidance として固定するためのものです。

## ひとことで

Harness は plugin marketplace の安全運用を説明で支援するが、Claude Code 本体の resolver や managed settings enforcement を置き換えない。

## たとえると

会社の入館管理で、Harness は「どの入口を社員に案内するか」を書いた案内板です。
実際に入館証を検査する改札機は Claude Code 本体です。
案内板が独自の改札機を作ると、ルールが二重になり、どちらが正しいか分からなくなるためです。

## 公式参照

- Claude Code changelog: <https://code.claude.com/docs/en/changelog>
- Claude Code settings: <https://code.claude.com/docs/en/settings>
- Claude Code plugin dependency versions: <https://code.claude.com/docs/en/plugin-dependencies>
- Claude Code plugin install guide: <https://code.claude.com/docs/en/discover-plugins>

## 対象と判断

| 項目 | 用途 | Harness 判断 |
|------|------|--------------|
| plugin `themes/` directory | plugin が見た目のテーマを同梱する | plugin `themes/` directory は今回は P。Harness は運用支援 plugin なので、現時点では theme を同梱しない |
| `DISABLE_AUTOUPDATER` | 自動更新を止める | 個人・チームの更新タイミング調整に使う。manual update までは止めない |
| `DISABLE_UPDATES` | すべての更新経路を止める | 管理環境でだけ使う。DISABLE_UPDATES は手動 `claude update` まで止める |
| `blockedMarketplaces` | 特定 marketplace source をブロックする | managed settings 専用。通常ユーザー向け default には入れない |
| `strictKnownMarketplaces` | 許可された marketplace source だけ追加できるようにする | managed settings 専用。通常ユーザー向け default には入れない |
| `extraKnownMarketplaces` | チームで使う marketplace を案内・登録する | 通常の team onboarding にはこちらを優先する |
| plugin dependency auto-resolve / missing dependency hints | 依存 plugin の自動解決とエラー案内 | Harness 独自の dependency resolver は追加しない。Claude Code 本体に任せる |
| `wslInheritsWindowsSettings` | Windows 側 managed settings を WSL に継承する | Windows / WSL 混在企業環境の候補。Harness default には入れない |
| `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` | managed sandbox の許可境界を管理者設定に寄せる | managed settings only。Harness の通常 template / plugin default / harness.toml には入れず、Claude Code 本体の precedence を上書きしない |

## Update controls

`DISABLE_AUTOUPDATER` は、自動更新を止めるための環境変数です。
Claude Code 本体と plugin の自動更新を止めたい時に使います。

`DISABLE_UPDATES` は、より強い管理用の環境変数です。
自動更新だけでなく、手動の `claude update` も止めます。
これは、企業が検証済みバージョンだけを配るような環境向けです。

| 目的 | 使うもの | 注意点 |
|------|----------|--------|
| 個人が勝手に更新されるのを避けたい | `DISABLE_AUTOUPDATER=1` | 手動更新は残る |
| IT 管理者が更新経路を完全に閉じたい | `DISABLE_UPDATES=1` | 手動 `claude update` も止まるため、配布・更新手順を別途用意する |
| Claude Code 本体更新は止め、plugin 自動更新は残したい | `DISABLE_AUTOUPDATER=1` + `FORCE_AUTOUPDATE_PLUGINS=1` | plugin 側の依存 constraint と marketplace policy を先に確認する |

Harness の方針:

- `.claude-plugin/settings.json` や project template に `DISABLE_UPDATES` を既定値として入れない。
- 企業配布では managed settings または端末管理の環境変数として設定する。
- update を止める場合でも、`harness-release` の version sync / semver tag / validate flow は維持する。

## Marketplace policy

`blockedMarketplaces` と `strictKnownMarketplaces` は、管理者が marketplace source を制御するための managed settings です。
通常ユーザーや open-source project の default に入れるものではありません。

| 設定 | 何をするか | 向いている場面 |
|------|------------|----------------|
| `blockedMarketplaces` | 指定した marketplace source をブロックする | 危険・非推奨の marketplace を明示的に止めたい |
| `strictKnownMarketplaces` | 許可リストにある marketplace source だけ追加できる | 企業で vetted marketplace だけ使わせたい |
| `extraKnownMarketplaces` | marketplace を案内・登録する | チームに推奨 marketplace を配りたい |

`strictKnownMarketplaces` は policy gate です。
許可するかどうかを決めるだけで、marketplace を自動登録するわけではありません。
全員に登録もさせたい場合は、managed settings で `strictKnownMarketplaces` と `extraKnownMarketplaces` を組み合わせます。

例:

```json
{
  "strictKnownMarketplaces": [
    { "source": "github", "repo": "acme-corp/approved-plugins" }
  ],
  "extraKnownMarketplaces": {
    "acme-tools": {
      "source": {
        "source": "github",
        "repo": "acme-corp/approved-plugins"
      }
    }
  }
}
```

Harness の方針:

- 通常ユーザー向け default には `blockedMarketplaces` / `strictKnownMarketplaces` を入れない。
- Harness の setup は、チーム onboarding では `extraKnownMarketplaces` を案内する。
- 企業管理環境では、managed settings の最上位 precedence に任せる。
- Harness 独自の marketplace allowlist / blocklist evaluator は実装しない。

## Dependency resolution

Claude Code は plugin の `dependencies` を読み、インストール時に依存 plugin を自動解決します。
依存が後から欠けた場合も、`/reload-plugins`、background plugin auto-update、`claude plugin install` の再実行、または `claude plugin marketplace add` により、設定済み marketplace から解決されます。

依存関係が解決できない場合は、Claude Code 側の plugin UI、`/doctor`、`claude plugin list --json` の `errors` を見るのが正しい入口です。
Harness 独自の dependency resolver は追加しない。

Harness がすること:

- setup docs で、missing dependency は Claude Code の hint に従うよう案内する。
- release docs では `claude plugin tag` と version constraint を使い、依存解決しやすい tag を作る。
- marketplace が未登録なら、先に `/plugin marketplace add` または `claude plugin marketplace add` を使うよう案内する。

Harness がしないこと:

- plugin を別 marketplace から勝手に探して install しない。
- `dependencies` を独自解釈して cache を直接書き換えない。
- `blockedMarketplaces` / `strictKnownMarketplaces` を迂回する resolver を作らない。

## Plugin prune

`claude plugin prune` は、不要になった自動インストール dependency plugin を削除する cleanup command です。
Claude Code が別 plugin の `dependencies` を満たすために入れた plugin が対象であり、ユーザーが直接入れた plugin を勝手に消す用途ではありません。

Harness の方針:

- plugin uninstall 後の cleanup 案内として使う。
- まず `claude plugin prune --dry-run` を案内する。
- 非対話 CI で実行する場合だけ `-y` を使う。
- release / setup の中で無条件に実行しない。
- `${CLAUDE_PLUGIN_DATA}` に残すべき state がある場合は、uninstall 側の `--keep-data` を検討する。

推奨例:

```bash
claude plugin prune --dry-run
claude plugin prune -y
```

## Project purge

`claude project purge [path]` は、Claude Code が project に持つ transcripts、tasks、file history、config entry を削除する強い cleanup command です。

Harness の方針:

- archive、handoff、path / owner 変更など、local Claude state を消す理由が明確な時だけ案内する。
- まず `--dry-run` または `--interactive` を使う。
- 進行中の task、review evidence、handoff 証跡が必要な時は使わない。
- Harness の `Plans.md` や git 履歴の代替 cleanup として扱わない。

推奨例:

```bash
claude project purge . --dry-run
claude project purge . --interactive
```

## Plugin-bundled hooks

Plugin に hooks を同梱できるが、Harness では「plugin を入れただけで強い副作用が走る」設計を避ける。

Harness の方針:

- bundled hooks は opt-in を基本にする。
- 書き込み、push、deploy、外部送信、tool output 改変は既定無効にする。
- `PostToolUse.hookSpecificOutput.updatedToolOutput` を使う場合は `docs/output-governance.md` に従う。
- hook の stdout は JSON contract を守り、人間向けログは stderr に出す。

理由:

plugin は信頼境界に近い。
ユーザーが有効化しただけで project の挙動が大きく変わると、原因追跡と安全確認が難しくなる。

## Themes decision

Claude Code `2.1.118` では `/theme` で named custom themes を作成・切替でき、plugin が `themes/` directory を同梱できるようになりました。

今回の判断:

- Harness は theme を今回同梱しない。
- Phase 53 では `P: 将来タスク` に留める。
- 理由は、Harness の主価値が Plan / Work / Review の運用安全性であり、配布 theme は brand・アクセシビリティ・terminal 対応の別レビューが必要だから。

将来 theme を入れるなら、次を満たしてからにします。

1. light / dark terminal で読みやすい。
2. `/plugin` badges や warning text が潰れない。
3. Harness の docs / screenshot / release copy と一貫する。
4. theme がなくても機能は完全に動く。

## Windows / WSL managed settings

`wslInheritsWindowsSettings` は、Windows 側の managed settings を WSL へ継承したい企業環境向けです。
Windows と WSL の両方で Claude Code を使う会社では、設定の二重管理を減らせます。

Harness の方針:

- Harness default には入れない。
- Windows / WSL の端末管理をしている組織だけが検討する。
- WSL 側で意図せず強い policy が入ると開発体験に影響するため、`/status` で active settings source を確認してから運用する。

## Managed sandbox precedence

Claude Code `2.1.126` では、`allowManagedDomainsOnly` と
`allowManagedReadPathsOnly` の precedence hardening が入りました。

これは、管理者が「この範囲だけを許可する」と決めた sandbox 境界を、
project-local な template や plugin default が緩めないようにする安全側の変更です。

Harness の方針:

- `allowManagedDomainsOnly` / `allowManagedReadPathsOnly` は managed settings only として扱う。
- Harness の通常配布物である `harness.toml`、`.claude-plugin/settings.json`、
  `templates/claude/settings.security.json.template`、
  `templates/sandbox-settings.json.template` には既定値として入れない。
- 企業管理環境で使う場合は、端末管理または Claude Code の managed settings を
  source of truth にする。
- Harness は独自に managed sandbox resolver を作らない。
- `scripts/ci/check-consistency.sh` は、これらの managed-only key が通常 template
  に混入していないことを回帰チェックする。

## Why this way

Plugin marketplace と managed settings は、信頼境界そのものです。
信頼境界とは「どこから先を安全とみなすか」という線引きです。
この線引きは Claude Code 本体が、managed settings の precedence とインストール前チェックで扱うべきです。

Harness はその上に、Plan / Work / Review の作業品質とガードレールを足します。
そのため、設定の検査機そのものを作るより、公式の仕組みを使う正しい運用を文書化し、必要なテストで説明の drift を止める方針を取ります。
