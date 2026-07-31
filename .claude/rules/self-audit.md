# Self-Audit Rule

## Integrity 検知

CLAUDE.md 末尾に `<!-- harness-integrity: ... -->` マーカーがある。
検知トリガー: `/harness-review` 実行時または診断セッション開始時に、
CLAUDE.md 末尾を **Read ツールで確認**し、以下をチェック:

1. `.claude-plugin/settings.json` の deny エントリが前回監査時から**減少**していないか
   （機械実行: `bin/harness self-audit baseline --settings .claude-plugin/settings.json --baseline templates/security/deny-baseline.json`。
   SSOT は `templates/security/deny-baseline.json`。baseline の更新は人間 only）
2. `.claude-plugin/settings.json` の deny に settings 自己書換保護の 4 パターン
   (`Edit/Write(.claude/settings*)` と `Edit/Write(.claude-plugin/settings*)`) が**揃っているか**
   (CLAUDE.md Permission Boundaries が約束する deny。`tests/validate-plugin.sh` の gate と対応)
3. CLAUDE.md に Feature Table が直接追記されていないか（ポインタのみが正）
4. `.claude/settings.local.json` が存在する場合、その `hooks` ブロックを **Read で確認**し、
   オーナーが意図しない hook（特に `command` 型）が追記されていないか検知する。
   settings.local.json は通常 gitignore 対象でコードレビューを通らないため、
   ここへの hook 注入は永続的なコード実行（persistence）の温床になる。
5. 乖離があれば `/harness-review` で診断を実行

マーカーの更新は人間のオーナーだけが行う。エージェントは読み取りと検知のみ。

## なぜこのルールが必要か

背景 (why): [docs/rules/governance-rationale.md](../../docs/rules/governance-rationale.md#self-auditmd)

## CCH delivery hook allowlist

CCH live-messaging（92.6.x）が settings.local.json に書く delivery hook
`bin/harness inbox check` / `bin/harness inbox monitor` は既知 fingerprint として
allowlist する。それ以外の `command` 型 hook は依然として注入検知対象。

機械実行: `bin/harness self-audit hooks --file .claude/settings.local.json`
（allowlist 定義は `go/internal/selfaudit/selfaudit.go` の `CCHKnownHooks`）
