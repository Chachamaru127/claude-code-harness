# Hardening Parity

最終更新: 2026-03-25

この文書は、Harness が **Claude Code** と **Codex CLI** の両方でどこまで同じ安全性を提供するかを整理するための共通ポリシーです。

ポイントは次の 2 つです。

- 共通化するのは「何を危険とみなすか」という**ポリシー**
- 実装はプラットフォーム差に合わせて分ける

Claude Code は hook によって実行の直前・直後で止められます。  
Codex CLI は同じ hook を持たないため、実行前の instructions 注入、実行後の quality gate、merge 前の検証で近い効果を出します。

## Policy Matrix

| Policy | 例 | Severity | Claude Code | Codex CLI |
|--------|----|----------|-------------|-----------|
| No verification bypass | `git commit --no-verify`, `git commit --no-gpg-sign` | Deny | PreToolUse deny | instructions で禁止 + quality gate fail |
| Protected branch destructive reset | `git reset --hard origin/main`, `git reset --hard main` | Deny | PreToolUse deny | instructions で禁止 + quality gate fail |
| Direct push to protected branch | `git push origin main` | Confirm | PreToolUse ask（設定で deny / allow 可） | instructions で確認、merge gate 経由を推奨 |
| Force push | `git push --force`, `git push -f` | Deny | PreToolUse deny | instructions で禁止、merge gate 経由を必須化 |
| Protected files editing | `package.json`, `Dockerfile`, `.github/workflows/*`, `schema.prisma` など | Warn | PreToolUse approve + warning | quality gate fail（Claude より厳格） |
| Pre-push secrets scan | hardcoded secret, DB URL, private IP, token-like string | Deny | push 相当 Bash の前で deny または fail | quality gate fail |

## Protected Files Profile

既定の protected files は「壊れると影響が広いが、通常の実装では毎回は触らない」ものに絞ります。

- `package.json`
- `Dockerfile`
- `docker-compose.yml`
- `.github/workflows/*.yml`
- `.github/workflows/*.yaml`
- `schema.prisma`
- `wrangler.toml`
- `index.html`

設計意図:

- **deny ではなく warn を基本**にする  
  正当な変更はあるため、まずは意図確認を優先する
- `.env` や秘密鍵のような**明確な機密・危険ファイルは別ルールで deny**する  
  これは protected files ではなく既存の protected path ルールの責務
- **Codex CLI の merge gate は現状 fail 扱い**  
  Codex 側は実行前に対話で確認できないため、protected files は事後検査で強めに止める

## Runtime Mapping

### Claude Code

Claude Code では runtime enforcement を優先します。

- **PreToolUse**
  実行前に危険コマンドを deny / ask / warn
- **PostToolUse**
  書き込み後の改ざん・セキュリティパターンを警告
- **PermissionRequest**
  安全な read-only / test 系コマンドだけ自動許可

### Codex CLI

Codex CLI では runtime hook がないため、次の 3 層で近似 enforcement を行います。

1. **実行前 contract 注入**  
   `codex exec` に渡す instructions に禁止事項を明示し、state artifact にも同じ contract を保存する
2. **post-exec quality gate**  
   Worker の成果物を diff / file / content ベースで検査する
3. **merge gate**  
   quality gate を通らない成果物は main に取り込まない

## Known Asymmetry

これは重要です。両者は完全には同じではありません。

| 項目 | Claude Code | Codex CLI |
|------|-------------|-----------|
| 実行前中断 | 可能 | 直接は不可 |
| 実行後警告 | 可能 | quality gate で近似 |
| コマンド単位の deny | 強い | instructions 依存 + post-check |
| main 取り込み前の阻止 | 可能 | 可能 |
| protected files | warn 中心 | fail 中心 |
| direct push / force push | runtime で検出可能 | runtime 検出は不可、merge gate 運用で代替 |

要するに:

- **Claude Code はその場で止めるのが得意**
- **Codex CLI は出力を通さないことで守る**

## Operator Guidance

- 安全性を最優先する作業は Claude Code 経路を優先する
- Codex CLI は実装・レビュー補助として使い、main 取り込み前に必ず quality gate を通す
- protected files や release 周辺を触る作業では、Codex 側では warning ではなく fail になる前提で使う

## Validation Surface

最低限、次の 4 点が揃っていることを `validate-plugin` 系で検査できる状態を目指します。

- 共通ポリシー文書が存在する
- Claude Code guardrail が対象ルールを持つ
- Codex wrapper が hardening contract を注入する
- Codex quality gate が parity 用の検査を持つ
