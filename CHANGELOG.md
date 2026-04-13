# Changelog

Change history for claude-code-harness.

> **📝 Writing Guidelines**: Focus on user-facing changes. Keep internal fixes brief.

## [Unreleased]

## [4.0.3] - 2026-04-13

### テーマ: プラグイン配布時の skill ロード失敗を修正

**`claude plugin install` や `--plugin-dir` 経由で harness を読み込んだ際、skill が 1 件もロードされない致命的なバグを修正。開発環境ではフォールバックが効いていて見逃されていた。**

---

### Fixed

#### plugin.json の skills パス誤りでプラグイン配布時に skill が 0 件ロードされる問題

**今まで**: `.claude-plugin/plugin.json` の `skills` フィールドが `["./"]` と誤って設定されており、
プラグインルート直下を skills ディレクトリとして扱っていました。実際の `SKILL.md` は
`skills/` サブディレクトリ配下にあるため、`claude plugin install` や
`claude --plugin-dir /path/to/claude-code-harness` で読み込んだ場合に**プラグインの skill が 1 件も検出されない**状態でした。
開発環境（リポジトリ直下で `claude` を起動）では `.claude/skills/` 経由のプロジェクト skill 自動検出が
フォールバックとして働いていたため、サイレントに見逃されていました。

**今後**: `skills` フィールドを `"./skills/"` に修正し、配布経路でも `/claude-code-harness:harness-work` などが
正しく呼び出せるようになります。既にインストール済みのユーザーは `claude plugin update claude-code-harness` で
修正版に切り替えてください。

## [4.0.2] - 2026-04-12

### テーマ: 大規模移行後の「見えない残骸」を自動検出する仕組み

**v4.0.0 の TS→Go 全面移行後、テスト・ドキュメント・スキル定義に残った 13 件の「旧世界の参照」が偶然発見されるまで気づけなかった。今後はこの種の問題を Harness が自動的に発見し、リリース前にブロックします。**

---

#### 1. Migration Residue Scanner の導入

**今まで**: 大きな migration (v3→v4 など) の後、「削除したはずのファイルやコンセプトへの参照」がコードのあちこちに残ります。テストスクリプトが消えたファイルを grep し続ける、README が「Node.js 18+ が必要」と書いたまま、スキルの見出しに `(v3)` が残る — これらは**テストを通過し、レビューをすり抜け、ユーザーの目に触れて初めて気づく**種類のバグでした。v4.0.0 リリース後の 2 日間で 13 件がこのパターンで偶然発見されました。

**今後**: `.claude/rules/deleted-concepts.yaml` に「削除済みのパスと概念」を登録し、`scripts/check-residue.sh` がリポジトリ全体をスキャンして残骸を検出します。歴史記述 (CHANGELOG 等) は allowlist で除外されるので、false positive はゼロです。

3 つの検証ポイントで自動実行されます:
- **開発中**: `bin/harness doctor --residue` で手動チェック
- **PR ごと**: `validate-plugin.sh` のセクション 9 で自動チェック
- **リリース前**: `harness-release` の preflight で自動ブロック

```
$ bin/harness doctor --residue
✓ No migration residue detected
```

#### 2. v3 残骸の最終クリーンアップ

**今まで**: Scanner 導入時に発見された追加の v3 残骸 5 件 — `harness-release` SKILL.md のガードレール参照が旧 TypeScript パスのまま (3 mirror)、TS↔Go クロスバリデーションテストが TS 削除後も存続 (374 行)、Codex スキルの H1 に `(v3)` サフィックスが残存。

**今後**: Scanner が検出した全件を修正。`tests/cross-validate-guardrails.sh` (TS engine 必須の dead test) を完全削除。Scanner clean state (0 件) を達成し、今後の残骸混入を自動ブロックする体制が整いました。

#### 3. 運用ルールの文書化 (migration-policy.md)

次回の major migration で同じ失敗を繰り返さないための 5 つのルール:
1. 削除 PR と deleted-concepts.yaml 更新を同時に出す (遅延禁止)
2. allowlist は歴史記述・移行ガイド・個別文脈の 3 原則で運用
3. retroactive validation (過去 commit に遡って検出力を検証)
4. HEAD での false positive は常にゼロを保つ
5. CI + release preflight で merge 前に 0 件を保証

---

## [4.0.1] - 2026-04-11

### テーマ: CC 2.1.89-2.1.100 追従 — Go v4 セキュリティハードニング

**CC 2.1.98 で本体が塞いだ 2 つの Bash permission bypass 脆弱性 (backslash-escape, env-var prefix) を Harness 二層目ガードレール (`go/internal/guardrail/`) にも反映。加えて CC 2.1.89 DecisionDefer ワイヤリング、CC 2.1.89 symlink 解決、CC 2.1.90 .husky 保護、CC 2.1.98 wildcard whitespace 正規化、CC 2.1.94 plugin skills field 明示化、CC 2.1.98 Monitor ツール取込を統合。24 本のセキュリティテスト追加、Go v4.0.0 リリース前の品質ゲート完了。**

---

#### 1. Claude Code 2.1.98 統合 — セキュリティ脆弱性追従 (permission.go)

CC 2.1.98 で本体が塞いだ 2 つの Bash permission bypass 脆弱性を Harness 二層目ガードレールにも反映。Harness は CC 本体のチェックをすり抜けた場合のセーフティネットとして動作するため、上流が塞いだ穴を Harness でも塞ぐことで defense-in-depth を保つ。

##### 1-1. Backslash-escaped フラグ bypass の緩和

**CC のアプデ**: `git\ push\ --force` のようにバックスラッシュでスペースやフラグをエスケープされたコマンドが、auto-allow 経路で read-only コマンドと誤認されて任意コード実行につながる bypass を CC 2.1.98 が修正。

**Harness での活用**: `permission.go` に `hasBackslashEscape()` 関数を追加し、正規表現 `\\[\-\s]` でエスケープパターンを検出。`isSafeCommand()` の先頭で呼び出し、検出時は即 reject。`git\ status`, `git\ push\ --force`, `rm\ -rf\ /` の 3 攻撃ベクタをテストで捕捉。

##### 1-2. 環境変数 prefix の allowlist

**CC のアプデ**: `EVIL=x git status` のように未知の環境変数を前置して read-only コマンドを auto-allow させる bypass を CC 2.1.98 が修正。`LANG`, `TZ`, `NO_COLOR` 等のみ許可。

**Harness での活用**: `permission.go` に `knownSafeEnvVars` map (LANG, LANGUAGE, TZ, NO_COLOR, FORCE_COLOR) と `stripSafeEnvPrefix()` 関数を追加。`LC_*` prefix は locale 系変数として許可。未知の変数を 1 つでも含むコマンドは safe 判定から除外。`LANG=C git status` は通し、`EVIL=x git status` や `LANG=C EVIL=x git status` は reject。

---

#### 2. Claude Code 2.1.89 統合 — hook 機能とパス解決

##### 2-1. DecisionDefer の正しいワイヤリング

**CC のアプデ**: CC 2.1.89 で PreToolUse hook に `"defer"` permission decision が追加。ヘッドレスセッションで判断困難な操作に遭遇した時、セッションを保留して `-p --resume` で再評価する escape hatch。

**Harness での活用**: `go/pkg/hookproto/types.go` には `DecisionDefer` 定数が定義されていたが、`go/internal/guardrail/pre_tool.go` の `PreToolToOutput()` switch case で拾われておらず、返しても CC に伝わらない既知ギャップがあった。`case hookproto.DecisionDefer:` を追加し、`PermissionDecision: "defer"` と `Reason` を出力するよう修正。Breezing ヘッドレスモードでの安全性が向上。

##### 2-2. Symlink target の解決

**CC のアプデ**: CC 2.1.89 で許可ルールが symlink の target を解決してチェックするよう修正。`.env` を指す symlink 経由でのアクセス bypass を塞ぐ。

**Harness での活用**: `helpers.go` の `isProtectedPath()` 内部で `filepath.EvalSymlinks()` を呼び、解決後の実パスに対しても protected patterns をチェック。symlink loop や broken link で `EvalSymlinks` がエラーを返した場合は fail-safe として deny、ただし `os.IsNotExist` での「存在しないパス」は例外扱いで approve (新規ファイル作成を妨げないため)。`link-env → .env`、`link1 → link2 → .env` の 2 段 chain、symlink loop の 3 パターンをテスト。

---

#### 3. Claude Code 2.1.90 統合 — .husky 保護

##### 3-1. .husky/ protected path 追加

**CC のアプデ**: CC 2.1.90 で `.husky/` ディレクトリが acceptEdits モードの protected directories に追加。git hooks の書き換えを防ぐ。

**Harness での活用**: `helpers.go` の `protectedPathPatterns` に `(?:^|/)\.husky(?:/|$)` パターンを追加。Worker が bypassPermissions で動く場合も Harness 二層目で `.husky/pre-commit` 等の書き換えをブロック。

---

#### 4. Claude Code 2.1.98 統合 — wildcard whitespace 正規化

##### 4-1. 連続 whitespace の単一スペース化 (defense-in-depth)

**CC のアプデ**: CC 2.1.98 で `Bash(git push -f:*)` のような wildcard 許可ルールが、実行コマンドに複数スペースやタブが含まれる場合にマッチしない問題を修正。

**Harness での活用**: `helpers.go` に `normalizeCommand()` 関数を追加し、`\s+` を単一スペースに正規化 + TrimSpace。`hasForcePush`, `hasDangerousRmRf`, `hasSudo`, `hasDangerousGitBypassFlag`, `hasProtectedBranchResetHard`, `hasDirectPushToProtectedBranch` の 6 ルールヘルパー全てで呼び出し、仕様より厚い defense-in-depth を実現。`git  push  --force` (複数スペース) と `git\tpush\t-f` (タブ) も確実にブロック。

---

#### 5. Claude Code 2.1.94 統合 — plugin skills field 明示化

##### 5-1. plugin.json の skills field 宣言

**CC のアプデ**: CC 2.1.94 で plugin skill の invocation name が frontmatter `name` 基準になる仕様変更。`"skills": ["./"]` で宣言することで、インストール方法を跨いで安定した名前を持つ。

**Harness での活用**: `.claude-plugin/plugin.json` に `"skills": ["./"]` フィールドを追加。CC は以前から skills ディレクトリを auto-discover していたが、この明示宣言により CC 2.1.94 以降の spec に完全準拠。既存 32 スキル全ての invocation 名は変わらず後方互換。

---

#### 6. Claude Code 2.1.98 統合 — Monitor ツール取込

##### 6-1. 長時間プロセスの stdout ストリーミング監視

**CC のアプデ**: CC 2.1.98 で Monitor ツールが追加。バックグラウンド実行中のシェルプロセスの stdout 各行を逐次通知として Claude に届ける仕組み。ポーリング型より低レイテンシ・低トークン消費。

**Harness での活用**: `breezing`, `harness-work`, `ci`, `deploy`, `harness-review` の 5 スキルの `allowed-tools` に `Monitor` を追加。`breezing` SKILL.md に「Monitor ツール活用ガイド」節を新設し、Worker 監視 (Agent 層が完了通知するため不要) vs シェルプロセス監視 (Monitor 推奨) の使い分けを明記。具体例として `gh run watch`, `go test ./... -v`, `codex-companion.sh watch <job-id>` を列挙。`docs/CLAUDE-feature-table.md` に Monitor 行を追加し付加価値列に "A: 実装あり" と記載 (`.claude/rules/cc-update-policy.md` の「書いただけ検出」対象外)。mirror スキル (codex/.codex/skills/, opencode/skills/) も同期。

---

#### 7. セキュリティテスト強化 + R12 test assertion 同期

**今まで**: ガードレールテストは R01-R13 の基本ケース中心で、backslash escape や env-var prefix のような attack vector を具体的に表現するテストは無かった。また `c101efc8` で R12 を warn → deny にアップグレードした際、Go 側のテスト assertion が warn を期待したまま残存しており、Phase 38 開始時点でベースラインが既に 2 件 failing。

**今後**: Phase 38 で以下の 24 本のテストを追加し、R12 test assertion も同期:
- `permission_test.go`: 8 本 (backslash escape 3 + env-var allowlist 5)
- `pre_tool_test.go`: 8 本 (DecisionDefer 出力検証、新規ファイル)
- `helpers_test.go`: 13 本 (.husky + symlink 解決 + loop fail-safe、新規ファイル)
- `rules_test.go`: 3 本 (whitespace 変種での force-push) + R12 assertion 3 件更新

攻撃者視点のテスト (実際に試されうる入力) を表現することで、将来的なリファクタリングで退行を即座に検知可能に。`go test ./...` 全 12 パッケージ PASS。

---

### テーマ: Phase 39 — レビュー体験改善 + インフラ根本修正

**Phase 38 完了後の独立レビューで発見した改善機会を全て解消。`/harness-review` の出力を非専門家にも読めるよう再設計、`harness sync` の plugin.json auto-revert を根本修正、v3 時代のテスト参照を v4 Go 実装に同期、v3 cleanup 残骸を除去。12 件の改善が事後的に追加され、v4.0.1 リリース前の品質ゲートを完遂。**

---

#### 8. `/harness-review` を非専門家にも読めるレビュー体験に再設計

**今まで**: `/harness-review` の出力は英語混じりの JSON 中心で、結論や主要指摘が JSON の奥深くに埋もれていました。非専門家が読むと「APPROVE って何?」「結局どうすればいいの?」で止まってしまい、技術者向けのツールという印象でした。引数なしの `/harness-review` bare 呼び出しも「タスクが不明です、指示を待ちます」で止まっていました。

**今後**: レビュー出力を **情報粒度 MID / 認知負荷 MIN** を軸に全面再設計しました。

- **判定を冒頭に 1 行で**: `✅ 合格 (APPROVE) — 10 commits 全てがテストを通過し、リリース可能な品質です` のように、判定+理由を最上段に配置
- **「✨ 良かったところ」セクション必須化**: 2-3 件の具体的な評価点を平易な日本語で。非専門家への安心材料として機能(技術者レビューにはない観点)
- **「⚠️ 気になったところ」は 4 段構造**: 日本語タイトル → 問題(平易な説明) → 対応(具体的なアクション) → 重要度(🔴 致命的 / 🟠 重要 / 🟡 軽微 / 🟢 推奨、日本語+絵文字) → 技術的位置(開発者向け、隔離)
- **JSON は「📦 詳細データ」セクションに降格**: 「非専門家は読み飛ばし可」と明記
- **bare 呼び出し対応**: 引数なし `/harness-review` で自動的に Code Review が開始する Step 0 を追加。`git describe --tags` → `main` → `HEAD~10` の fallback chain で BASE_REF を自動決定
- **スコープ上限フォールバック**: 最後のタグから 10 commits 超えている場合、自動で HEAD~10 に絞り込み(bare レビューが暴走しない)
- **日本語出力必須化**: `context: fork` サブエージェントは親セッションの言語文脈を継承しないため、SKILL.md で明示的に CLAUDE.md ルールを引用して徹底

```
レビュー実行例:
/harness-review    ← 引数なしで OK
  ↓
結果: ✅ 合格 (APPROVE) — ...
  ↓
✨ 良かったところ:
  - プラグイン設定の auto-revert バグが根本解決した
  - ...
⚠️ 気になったところ (1 件):
  1. 変更履歴が未記載
    → 対応: CHANGELOG を更新する
    → 重要度: 🟡 軽微
  ...
```

#### 9. `harness sync` の plugin.json 自動上書きバグを根本修正

**今まで**: `.claude-plugin/plugin.json` に手動で `"skills": ["./"]` を追加しても、次に `harness sync` が実行されるたびに消える謎の現象がありました。現象を追跡すると、`harness sync` コマンド (Go 実装) が plugin.json を harness.toml から再生成する際に、`pluginJSON` 構造体に `Skills` フィールド自体が存在せず、skills field が毎回 silently drop されていたのが原因でした。Phase 38.2.1 で手動追加した設定が、その後のセッションで `harness sync` が呼ばれた瞬間に消えるので、設定が揮発する状態が続いていました。

**今後**: `go/cmd/harness/sync.go` の `pluginJSON` 構造体に `Skills []string` フィールドを追加し、`generatePluginJSON()` で常に `[]string{"./"}` を出力するようハードコード。これにより `harness sync` が何度実行されても skills 設定が保持されます。`TestSync_GeneratesPluginJSON` に `skills == ["./"]` のアサーションを追加して、将来の regression を防ぎます。CC 2.1.94+ の「frontmatter name 駆動」機能が安定動作するインフラ基盤が整いました。

#### 10. テスト assertion の厳密化 — 偽陽性 pass を防ぐ pipe-token 正規表現

**今まで**: `tests/test-memory-hook-wiring.sh` の SessionStart matcher チェックが `contains("startup")` という **ゆるい substring 判定**に緩和されていました。現在の hooks.json (`matcher: "startup|resume"`) ではたまたま機能していましたが、将来誰かが `matcher: "startup-only"` のようなタイポを書いても「startup が含まれている」として silently pass してしまう偽陽性リスクを抱えていました。

**今後**: jq クエリを pipe-token 正規表現 `test("(^|\\|)startup($|\\|)")` に厳格化。「パイプ区切りで独立したトークンとして startup が存在する」ことを要求します。6 エッジケースで検証済み:
- `startup`, `startup|resume`, `resume|startup` → マッチ ✅
- `startup-only`, `startup_special`, `resume|startup-only` → reject ✗

これで将来のタイポが即座に test 失敗として浮上します。

#### 11. 名前整合性の回復 — `HAR:*` → `harness-*` revert

**今まで**: 一度 frontmatter `name` を `HAR:plan`, `HAR:review` 等の短い形式に変更しましたが、directory 名(`harness-plan/`, `harness-review/`)との不一致が原因で、レビュー出力の内部テキストが "harness-review" のまま残ったり、`skill-editing.md` の SSOT ルール (「name はディレクトリ名と一致させる」) 違反が発生する 3-way split 状態になっていました。

**今後**: 18 ファイル (6 skills × 3 mirror locations) の frontmatter `name:` を `harness-*` に revert し、directory 名と一致させました。description 先頭の `HAR:` ブランド表記は維持(54 箇所、3 description fields × 18 files)しているので、スラッシュパレットで視覚的な識別性は失われません。呼び出し名・内部テキスト・ファイルパス・palette 表示が全て `harness-review` のように統一された状態に戻りました。

#### 12. v3 cleanup 残骸の最終除去 + テストスクリプトの v4 migration

**今まで**: v4.0.0 リリース時に削除された `core/src/guardrails/rules.ts` や README の "TypeScript guardrail engine" 記述への参照が、複数のテストスクリプトや検証ツールに残ったままでした。`validate-plugin.sh` は deleted 対象を grep してエラー、`check-consistency.sh` は README の旧文字列を期待して失敗、テストスクリプトは v3 時代の shell 呼び出しパターン (`hook-handlers/memory-bridge`) を厳密一致で検証していて v4 の Go バイナリ呼び出し (`bin/harness hook memory-bridge`) を認識できず、合計 **8 件の false negative 失敗**を抱えていました。またルート直下に Agent tool の isolation エラーの副産物である 2 つの JSON 名 ghost directory、`core/` の掃除残り (node_modules + package-lock.json)、`infographic-check.png` (debug screenshot)、`.orphaned_at` (旧 session marker) が残存していました。

**今後**: 以下を一括で対応:

- `validate-plugin.sh`: RULES_FILE パスを `core/src/guardrails/rules.ts` から `go/internal/guardrail/rules.go` に変更、R12 expected pattern を `warn-direct-push-protected-branch` から `deny-direct-push-protected-branch` に同期 (c101efc8 で R12 が deny に格上げされた際の取り込み漏れを解消)
- `check-consistency.sh`: README 期待文字列を `"TypeScript guardrail engine"` → `"Go-native guardrail engine"` に同期 (README 本文は v4 で既に更新済みだが、checker が古いまま)
- `test-memory-hook-wiring.sh`: jq クエリを v3 shell パス厳密一致から v4 Go binary 形式の contains match に migrate、agent-type hook の null `.command` 対応も追加
- `test-claude-upstream-integration.sh`: PermissionDenied wiring check を `permission-denied-handler` から `permission-denied` に同期 (v4 Go binary は `bin/harness hook permission-denied` 形式)
- ルート直下から 5 件の ghost file / directory を削除

結果: `validate-plugin.sh` は **36 合格 / 6 失敗 → 42 合格 / 0 失敗** に改善、`check-consistency.sh` は **2 問題 → 0 問題** に改善、ルート直下がクリーンな状態に整理されました。

---

## [4.0.0] - 2026-04-09

### テーマ: "Hokage" — Go ネイティブフックエンジンへの全面移行

**フック実行パスを bash → Node.js → TypeScript の3段ロケットから Go バイナリ直接呼び出しに統一。Node.js ランタイム依存を完全排除し、コールドスタートを ~300ms → ~10ms に短縮。全37シェルハンドラを Go に移植完了。**

---

#### 1. Go ネイティブフックエンジン

**今まで**: フック実行は `bash shim → node → TypeScript guardrail engine` の3段階で動作していた。
各フック呼び出しごとに Node.js プロセスが起動し、コールドスタートに ~300ms かかっていた。
`better-sqlite3` の Node.js バージョン依存問題（Node 24 で壊れる等）もあり、
`optionalDependencies` で逃げる必要があった。

**今後**: Go バイナリ `bin/harness` がフックエントリーポイントになり、
`hooks.json` から直接 Go バイナリを呼び出す。コールドスタートは ~10ms。
Node.js ランタイムは不要になり、pure-Go SQLite (`modernc.org/sqlite`) で状態管理。

```bash
# hooks.json の変更例
# Before: "command": "bash hooks/pre-tool-use.sh"
# After:  "command": "bin/harness hook pre-tool-use"

# 移行状態の確認
bin/harness doctor --migration
```

#### 2. 全37シェルハンドラの Go 移植

**今まで**: 37本のシェルスクリプト（`hooks/*.sh`、`scripts/*.sh`）がフック処理を担当していた。
各スクリプトが独自に `jq`、`curl`、`git` を呼び出し、エラーハンドリングが不統一。
Windows 環境ではパス区切りやプロセスチェックで問題が頻発していた。

**今後**: 全37ハンドラを `go/internal/hookhandler/` に Go で再実装。
共通ユーティリティ（`helpers.go`）でプロジェクトルート解決、JSON I/O、Plans.md パース等を集約。
Windows/macOS/Linux のクロスプラットフォーム対応を組み込み済み。

移植されたハンドラ（主要なもの）:
- `guardrail.go` — R01-R13 ルールエンジン（TypeScript からの移植）
- `task_completed.go` — タスク完了時の自動レビュー・Plans.md 更新
- `auto_test_runner.go` — テスト自動実行・結果解析
- `ci_status_checker.go` — CI ステータス監視・ポーリング
- `session_auto_broadcast.go` — セッション間メッセージブロードキャスト
- `pre_compact_save.go` — コンテキスト圧縮前の状態保存
- `tdd_order_check.go` — TDD 順序検証
- `breezing_signal_injector.go` — Breezing モード信号注入

#### 3. harness.toml による設定統一

**今まで**: プラグイン設定が `plugin.json`、`hooks.json`、`settings.json`、`.mcp.json` 等の
5-6ファイルに分散しており、手動で同期する必要があった。
設定の不整合（hooks.json のパスが古い、settings.json の deny が欠落等）が頻発していた。

**今後**: `harness.toml` を SSOT として、`harness sync` コマンドで
全 CC プラグインファイルを自動生成する。TOML は人間が読み書きしやすく、
コメント付きで設定意図を記録できる。

```bash
# harness.toml を編集した後
bin/harness sync

# 自動生成されるファイル:
#   .claude-plugin/plugin.json
#   .claude-plugin/settings.json
#   hooks/hooks.json
```

#### 4. SQLite 状態レイヤー

**今まで**: セッション状態やエージェントライフサイクルは JSON ファイルと環境変数で管理。
複数エージェントの並行実行時にファイルロック競合やデータ消失が発生していた。

**今後**: pure-Go SQLite (`modernc.org/sqlite`) による状態管理。
WAL モードで並行読み書きに対応し、Breezing の複数 Worker が同時にステータス更新しても安全。
`state/harness.db` にセッション・エージェント・タスク状態を一元管理。

#### 5. エージェントライフサイクル管理

**今まで**: Worker や Reviewer のライフサイクルは暗黙的で、
障害時のリカバリーは手動介入が必要だった。

**今後**: 10状態14遷移のステートマシンでエージェントライフサイクルを管理。
4段階リカバリー（SelfHeal → PeerHeal → Lead → Abort）を自動実行。
SubagentStart/Stop イベントを追跡し、`harness status` でリアルタイム監視。

#### 6. クロスコンパイル・バイナリ配布

**今まで**: TypeScript エンジンの実行には Node.js のインストールが前提だった。

**今後**: darwin-arm64、darwin-amd64、linux-amd64 向けにクロスコンパイル。
GitHub Release にバイナリを添付し、`npm postinstall` でプラットフォーム別バイナリを自動セットアップ。
Node.js なしでフックが動作する。

#### 7. ガードレールエンジンの Go 移植

**今まで**: ガードレールルール（R01-R13）は TypeScript (`core/src/guardrails/rules.ts`) で実装。
Go 側とのルール定義の乖離リスクがあった。

**今後**: Go (`go/internal/guardrail/rules.go`) にも同等のルールを実装し、
`tests/cross-validate-guardrails.sh` でTypeScript と Go の宣言的ルールテーブルが
一致していることを自動検証。R12 は warn → deny に格上げ（保護ブランチへの直接 push を完全ブロック）。

#### 8. harness doctor による移行ダッシュボード

**今まで**: 移行状態を確認する手段がなかった。

**今後**: `bin/harness doctor --migration` で、どのハンドラが Go に移行済みか、
残存するシェルスクリプトはあるか、バイナリの整合性は正常かを一覧表示。
初回実行時にはバイナリキャッシュの検証も行う。

#### 9. harness validate による構造検証

**今まで**: スキルやエージェントの frontmatter 不備は実行時まで気づけなかった。

**今後**: `bin/harness validate` でスキル SKILL.md とエージェント .md の
YAML frontmatter を静的検証。必須フィールド（name、description）の欠落、
description のトリガーフレーズ不足を検出してレポート。

---

### 破壊的変更

| Before | After | 移行方法 |
|--------|-------|---------|
| `bash hooks/pre-tool-use.sh` | `bin/harness hook pre-tool-use` | `harness sync` で自動更新 |
| Node.js ランタイム必須 | Go バイナリのみ | バイナリは GitHub Release に添付 |
| `core/` TypeScript エンジン | `go/` Go エンジン | TypeScript は参照実装として残存 |
| `run-hook.sh` シム | 廃止 | `hooks.json` が直接 Go を呼ぶ |
| R12: warn (direct push) | R12: deny (direct push) | 保護ブランチへの直接 push が完全ブロックに |

## [3.17.1] - 2026-04-06

### テーマ: harness-mem 接続修復

**標準インストール環境で harness-mem が見つからず、SessionStart 時の resume pack 生成が動かなかった問題を修正。**

---

#### 1. harness-mem-bridge.sh の探索パス修正

**今まで**: `harness-mem` を標準セットアップ（`~/.harness-mem/runtime/harness-mem`）でインストールした環境で、
`harness-mem-bridge.sh` がリポジトリを発見できなかった。
探索パスに標準インストール先が含まれておらず、`memory-bridge.sh` → `harness-mem-bridge.sh` が
`exit 0` で無言終了していた。その結果、SessionStart 時の resume pack 生成が動作せず、
セッション再開時にコンテキストが復元されない状態になっていた。

**今後**: 探索パスの最優先位置に `~/.harness-mem/runtime/harness-mem` を追加。
標準インストール環境で harness-mem が正しく検出され、resume pack が生成される。

探索順序:
1. `$HARNESS_MEM_ROOT`（明示的オーバーライド）
2. `~/.harness-mem/runtime/harness-mem`（標準インストール）← **追加**
3. `../harness-mem`（開発用 sibling repo）
4. `~/LocalWork/Code/CC-harness/harness-mem`（レガシー開発パス）
5. `~/Desktop/Code/CC-harness/harness-mem`（レガシー開発パス）

---

#### 2. CC 2.1.91-2.1.92 Feature Table 追加

- Feature Table に CC 2.1.91〜2.1.92 の 9 エントリを追加（`disableSkillShellExecution`、Plugin `bin/`、MCP `maxResultSizeChars` 500K、subagent spawning 修正 等）
- 全て A（ドキュメント/将来活用）または C（CC 自動継承）。B（書いただけ）は 0 件

## [3.17.0] - 2026-04-04

### テーマ: Feature Table 整合性回復 + upstream 統合 + Claude/Codex parity 強化

**Feature Table の「書いてあるが動かない」を全て解消し、CC 2.1.87-2.1.90 の新機能を取り込み、Claude/Codex 両文脈で Harness の信頼性と活用度を引き上げたリリース。**

---

### harness-review に --dual フラグを追加

**Claude Reviewer と Codex Reviewer を並行実行し、異なるモデル視点でレビュー品質を向上させる `--dual` フラグを追加した。**

#### 1. --dual フラグによる dual review

**今まで**: `/harness-review` は Claude の Reviewer エージェントのみで実行しており、
単一モデルの視点に限られていた。Codex のセカンドオピニオンが欲しい場合は手動で
`scripts/codex-companion.sh review` を別途実行する必要があった。

**今後**: `harness-review --dual` を実行すると、Claude Reviewer と Codex Reviewer が並行して動き、
両方の verdict を自動マージした結果が返る。どちらかが REQUEST_CHANGES を出せば全体が REQUEST_CHANGES になる。
Codex が利用不可の環境では Claude 単独実行に自動フォールバックするため、
Codex のセットアップがないプロジェクトでも安全に使える。

```bash
# Claude + Codex 並行レビュー
harness-review --dual

# 既存の single-model フローは変わらない
harness-review
harness-review code
```

出力の `dual_review` フィールドで各モデルの判定と、判定が分かれた場合の理由を確認できる。

---

### Claude Code 2.1.87-2.1.90 / Codex 0.118 統合

（auto mode 拒否追跡と Breezing 安全弁の追加。CC 側のフック修正を活かしてガードレール信頼性を向上）

#### 1. PermissionDenied hook による auto mode 拒否追跡

**CC のアプデ**: auto mode classifier がコマンドを拒否した際に `PermissionDenied` フックが発火するようになった（v2.1.89）。
`{retry: true}` を返すとモデルにリトライ可能であることを伝えられる。

**Harness での活用**: `permission-denied-handler.sh` を新規実装し、拒否イベントを `permission-denied.jsonl` に telemetry 記録。
Breezing Worker が拒否された場合は Lead に `systemMessage` で通知し、代替アプローチの検討を促す。
`agent_id` / `agent_type` を活用して「どのエージェントが何を拒否されたか」を追跡できる。

#### 2. defer permission decision のドキュメント整備

**CC のアプデ**: PreToolUse フックから `"defer"` を返すとヘッドレスセッションが一時停止し、
`claude -p --resume` で再開時にフックが再評価される（v2.1.89）。

**Harness での活用**: hooks-editing.md に defer decision の設計指針を追記。
Breezing Worker が判断困難な操作に遭遇した際の安全弁として文書化。
具体的な defer ルール（本番 DB 書込、destructive git 等）は運用パターン蓄積後に設計予定。

#### 3. PreToolUse exit 2 修正による guardrail 信頼性向上

**CC のアプデ**: PreToolUse フックが JSON stdout + exit code 2 でブロックを返す際の動作が修正された（v2.1.90）。
以前はこのパターンでブロックが正しく機能しないバグがあった。

**Harness での活用**: `pre-tool.sh` は deny 時にこのパターンを使用しており、v2.1.90 以降でガードレールの deny がより確実に動作する。
追加の実装変更は不要（CC 自動継承＋既存コードがそのまま恩恵を受ける）。

#### 4. CC 自動継承の主要修正

- `--resume` prompt-cache miss 修正（v2.1.90）: セッション resume 高速化
- autocompact thrash loop 修正（v2.1.89）: 3 回連続で停止→actionable error
- Nested CLAUDE.md 再注入修正（v2.1.89）: コンテキスト効率向上
- SSE/transcript パフォーマンス（v2.1.90）: O(n²)→O(n) 高速化
- PostToolUse format-on-save 修正（v2.1.90）: フック後の Edit/Write 失敗解消
- Cowork Dispatch 修正（v2.1.87）: チーム通信安定化

---

### Feature Table 整合性回復 + 未活用機能の実装

#### 5. Feature Table の誇張修正（7 件）

Feature Table で「実装済み」と誤読される記載を実態に合わせて修正。HTTP hooks→テンプレートのみ、OTel→独自 JSONL、Analytics Dashboard→計画中、LSP→CC native、Auto Mode→RP Phase 1、Slack→将来対応、Desktop Scheduled Tasks→CC native。

#### 6. PostCompact WIP 復元

**今まで**: コンテキスト圧縮の前に「WIP タスクがあります」と警告するが、圧縮後に復元しない。警告だけで助けない状態。

**今後**: PostCompact が PreCompact で保存した WIP 情報を `systemMessage` として復元し、圧縮後もタスク状態を保持する。

#### 7. Webhook 通知（TaskCompleted HTTP hook）

**今まで**: Feature Table に「HTTP hooks 実装済み」と書いてあるが、hooks.json に `type: "http"` が 0 件。

**今後**: `HARNESS_WEBHOOK_URL` を設定するとタスク完了時に Slack / Discord / 任意 URL に通知が飛ぶ。未設定ならサイレントスキップ（opt-in）。

#### 8. セキュリティレビュー（--security）

**今まで**: `/security-review` が Feature Table に記載されているが独立機能がない。

**今後**: `harness-review --security` で OWASP Top 10 + 認証/認可 + データ露出に特化したレビューが起動。security-specific な verdict 判定基準で通常より厳格にチェック。

#### 9. Codex Worker への effort 伝播

**今まで**: Claude 側では Lead がタスク複雑度を計算して ultrathink を自動注入するが、Codex Worker は常に medium effort。

**今後**: `calculate-effort.sh` がファイル数・依存関係・キーワード・DoD 条件からスコアを計算し、Codex Worker に effort を伝播。複雑なタスクで自動的に高 effort が適用される。

#### 10. OTel Span 送信

**今まで**: `emit-agent-trace.js` は独自 JSONL 形式。Datadog や Grafana に直接送れない。

**今後**: `OTEL_EXPORTER_OTLP_ENDPOINT` を設定すると OTel Span JSON 形式で HTTP POST 送信。未設定なら既存 JSONL にフォールバック。

#### 11. harness-release スキル全面改訂

デグレチェックリスト、NPM 非配布の明示、日本語 i18n 対応、mirror 同期フロー、SemVer 判定基準統合、`--dry-run` / `--complete` / `--announce` モード詳細化を含む全面リライト。

## [3.16.0] - 2026-04-01

### テーマ: Long-running harness hardening + team/release planning surfaces

**長時間実行の review / handoff / browser 検証を本線へ寄せつつ、team mode の issue bridge と release preflight で「作る前・出す前」の不確実さを減らしたリリース。**

### Added

- opt-in の team mode と `scripts/plans-issue-bridge.sh` を追加し、`Plans.md` を正本のまま tracking issue / sub-issue の dry-run payload を生成できるようにした
- `scripts/release-preflight.sh` と release preflight docs / tests を追加し、`/harness-release --dry-run` でも vendor-neutral な公開前チェックを通せるようにした
- `harness-plan create` の optional brief ルールと `scripts/generate-skill-manifest.sh` を追加し、UI/API brief と skill surface の machine-readable manifest を生成できるようにした

### Changed

- `skills-v3` の planning / release skill を更新し、team mode, pre-release verification, brief/manifest の導線を既存ワークフローへ統合した
- 公開 skill mirror を同期し、Claude / Codex / OpenCode の各配布面で同じ planning / release surface を使える状態にそろえた

#### Before/After

| Before | After |
|--------|-------|
| `Plans.md` のタスクをチームで共有したいときも、Issue 化のルールや payload を毎回その場で考える必要があった | opt-in の team mode で、`Plans.md` から tracking issue / sub-issue の dry-run payload を安定生成できるようになった |
| `/harness-release --dry-run` は公開前に何を確認すべきかが人依存で、repo ごとの healthcheck や CI 状態も統一的に見づらかった | vendor-neutral な preflight script が working tree, CHANGELOG, env parity, healthcheck, CI, shipped surface residual をまとめて確認するようになった |
| UI/API タスクの brief や skill surface 一覧を機械可読で出す導線がなく、比較・監査・自動 docs 生成の入力を毎回手で作っていた | `design brief` / `contract brief` のルールと `skill-manifest.v1` の生成導線を追加し、軽量な補助資料と manifest を再利用できるようになった |

## [3.15.0] - 2026-03-28

### テーマ: Claude 2.1.80-2.1.86 統合 + Codex/OpenCode mirror 整合

**Claude からは「軽さ」と「安全性」が一段上がり、Codex からは重いワークフローの初動品質と配布 mirror の整合性が安定。アップデート追従を、そのままではなく実運用の強さに変えたリリース。**

---

#### 1. Claude の reactive hooks で、前提の変化を見失いにくくした

**今まで**: `Plans.md` を更新したあとや、別 worktree に移ったあとでも、前の前提のまま作業を続けやすい状態でした。background task が作られても、その記録や再確認のきっかけは弱く、長い作業ほど文脈ずれが起きやすくなっていました。

**今後**: Claude Code の `TaskCreated` / `FileChanged` / `CwdChanged` hooks を Harness に取り込み、`runtime-reactive.sh` が task 作成、Plans 更新、ルール変更、worktree 切替を拾って補助文脈を返します。作業の途中で前提が変わっても、次の一手で気づきやすくなります。

```json
{"hook_event_name":"FileChanged","file_path":"Plans.md"}
→ "Plans.md が更新されました。次の実装やレビュー前に最新のタスク状態を読み直してください。"
```

#### 2. Claude 側の権限フローを、速さを落とさず安全寄りに調整した

**今まで**: `PermissionRequest` は広めに hook が走りやすく、最終的には問題ない Bash でも毎回評価コストやノイズが乗りやすい状態でした。さらに sandbox 起動失敗時の継続や、subprocess への認証情報伝播は利用者が意識しないと見落としやすいポイントでした。

**今後**: Claude Code 2.1.85 の conditional `if` field を使い、`git status`、`git diff`、`pytest`、`npm run lint` など安全寄りの Bash だけに permission hook を限定しました。あわせて `Edit|Write|MultiEdit` をそろえ、`.claude-plugin/settings.json` へ `sandbox.failIfUnavailable: true` と `CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1` を追加し、軽さと安全性を両立しています。

```text
Bash(git status*) | Bash(pytest*) | Bash(npm run lint*)
→ permission hook 対象

Bash(危険コマンド)
→ 無条件に広く hook を起こさず、既存ガードレール側で扱う
```

#### 3. Codex / Claude の重いフローで、最初から深く考えやすくした

**今まで**: `harness-work`、`harness-review`、`harness-release` のような重い作業でも、最初の 1 ターンで何を優先すべきかがぶれやすく、毎回の指示の書き方によって品質が揺れやすい面がありました。

**今後**: `skills-v3/`、Codex native mirror、OpenCode mirror に `effort` frontmatter を加え、`agents-v3/worker.md`、`reviewer.md`、`scaffolder.md` に `initialPrompt` を追加しました。これにより、レビューは verdict 基準から入り、実装は DoD と検証方針から入り、setup は既存資産を壊さない前提から始めやすくなります。

```yaml
effort: high
initialPrompt: |
  最初に対象タスク・DoD・変更候補ファイル・検証方針を短く整理し…
```

#### 4. ルール適用範囲と配布 mirror を、壊れにくく保ちやすくした

**今まで**: rules の `paths:` が 1 行文字列ベースで読みにくく、複数 glob の追加時に壊れやすい形でした。また Codex/OpenCode mirror は source とずれていても、修正時の判断基準が部分的に食い違い、CI が落ちたあとに原因を追い直す必要がありました。

**今後**: rules template と `scripts/localize-rules.sh` を YAML list 形式に移し、複数 glob を構造化して扱えるようにしました。さらに OpenCode build と Codex package チェックの公開スキル方針をそろえ、内部専用スキルを distribution mirror に混ぜない形で CI が green になるよう整えています。

```yaml
paths:
  - "**/*.{test,spec}.{ts,tsx,js,jsx}"
  - "**/tests/**/*.*"
```

## [3.14.0] - 2026-03-25

### テーマ: クロスランタイム品質強化 + Marketplace 修正

**Claude Code と Codex の品質ガードレールを統一し、Marketplace インストール時のメモリフック欠損を修正。**

---

#### 1. クロスランタイム品質ガードレール統一

**今まで**: Claude Code 側のガードレール（`--no-verify` 検出、保護ブランチの `reset --hard` 警告等）が Codex 側には存在せず、ランタイムによって品質基準にばらつきがありました。

**今後**: `docs/hardening-parity.md` でポリシーマトリクスを定義し、Claude Code hooks と Codex CLI quality gate の両方で同じルールを適用。`validate-plugin.sh` / `validate-plugin-v3.sh` でクロスランタイムの検証を自動化。

- Guardrails: `--no-verify` / `--no-gpg-sign`、保護ブランチ `git reset --hard`、`main`/`master` への直接 push 警告、保護ファイル編集警告
- Codex parity: `codex exec` フローにランタイム契約を注入し、bypass フラグ・保護ファイル編集・シークレット混入をマージ前に検証

#### 2. Codex AGENTS.md ルール詳細追加

**今まで**: Codex 側の `AGENTS.md` に `.claude/rules/` の詳細が記載されておらず、CC アプデポリシーや v3 アーキテクチャへの参照が欠けていました。

**今後**: `cc-update-policy.md`、`v3-architecture.md`、`versioning.md` の内容を Codex AGENTS.md に統合。Codex ユーザーもルール詳細を直接参照可能に。

### Fixed

- Marketplace インストール時に `scripts/hook-handlers/memory-*.sh` が欠損し、SessionStart / UserPromptSubmit / PostToolUse / Stop フックがエラーになる問題を修正
- メモリライフサイクルフックを単一 `memory-bridge.sh` エントリポイントに統合し、個別ラッパーパスへの依存を解消
- `sync-plugin-cache.sh` のソース検出で `CLAUDE_PLUGIN_ROOT` がプラグインルート自体を指す場合のパス解決を修正
- メモリフック配線と Marketplace キャッシュ同期の回帰テストを追加

## [3.13.0] - 2026-03-25

### テーマ: Codex ネイティブ対応 + レビュー品質強化 + メモリ永続化

**Codex CLI からも Harness のチーム実行（breezing）が使えるようになり、AI 残骸の自動検出でレビュー品質を向上。セッション間の記憶が harness-mem に永続化され、再開時に前回の文脈を自動復元。**

---

#### 1. Codex ネイティブ版スキル（skills-v3-codex/）

**今まで**: Codex CLI で `/harness-work` や `/breezing` を使うと、Claude Code 固有の API（`Agent()`, `SendMessage()`）が擬似コードに含まれており、Codex の LLM が正しく解釈できませんでした。「Codex では読み替えてね」という注釈があるだけで、実行時にエラーになるリスクがありました。

**今後**: `skills-v3-codex/` に Codex ネイティブ版を新設。`spawn_agent` / `wait_agent` / `send_input` / `close_agent` の正しい API シグネチャで書き直し、`git worktree add` による Worker 分離、`codex exec -C/-o` による作業ディレクトリ指定と verdict 取得を実装。Codex 自身によるレビュー5ラウンドで APPROVE を取得済み。

ユーザースコープ（`~/.codex/skills/`）に展開することで、どのプロジェクトからでも利用可能です。

```
~/.codex/skills/
├── harness-work → skills-v3-codex/  [CODEX NATIVE]
├── breezing     → skills-v3-codex/  [CODEX NATIVE]
├── harness-plan → skills-v3/        [shared]
└── ...他5件     → skills-v3/        [shared]
```

**Claude Code 版との主な差分**:

| 項目 | Claude Code | Codex ネイティブ |
|------|-------------|-----------------|
| Worker spawn | `Agent(subagent_type="worker")` | `spawn_agent({message, fork_context})` |
| 修正指示 | `SendMessage(to: agentId)` | `send_input({id, message})` |
| Worktree 分離 | `isolation="worktree"` 自動 | `git worktree add` 手動 |
| レビュー | Codex exec → Reviewer agent fallback | `codex exec -o <file>` のみ |
| モード昇格 | タスク4件以上で自動 | `--breezing` 明示のみ |

#### 2. AI Residuals レビューゲート（Phase 29.0）

**今まで**: AI が生成した mockData, dummy, localhost, TODO などの残骸がレビューをすり抜け、「動くが出荷できない」状態のコードがマージされることがありました。

**今後**: `harness-review` に 5つ目の観点「AI Residuals」を追加。`scripts/review-ai-residuals.sh` が差分を静的走査し、残骸を severity（minor/major）で分類します。テスト fixture も追加済み。

```bash
# 検出対象の例
mockData, dummyUser, localhost:3000, TODO:, FIXME,
test.skip, describe.skip, hardcoded API keys
```

#### 3. harness-mem セッション記憶の永続化（Phase 27.1.4-5）

**今まで**: Claude のセッションを閉じると、そのセッションで学んだ文脈や決定事項が失われ、次のセッションでは一からやり直しでした。

**今後**: Claude の SessionStart / UserPromptSubmit / Stop フックを harness-mem runtime に接続。セッション開始時に前回の記憶から「Continuity Briefing」を自動表示し、停止時に記憶を永続化します。

- `scripts/lib/harness-mem-bridge.sh` で harness-mem API 呼び出しを抽象化
- `session-init.sh` / `session-resume.sh` に continuity briefing 統合
- memory lifecycle 回帰テスト（wiring, bridge, integration）を追加

## [3.12.0] - 2026-03-21

### テーマ: work/Breezing 一連フロー自動化

**スキル発動からコミット・報告まで、人手を介さず一気通貫で完走する自動化フローを実現。Codex exec によるレビューループと閾値基準付き判定で、品質と収束性を両立。**

---

#### 1. Plans.md 自動登録（Phase A）

**今まで**: Plans.md が存在しない場合、harness-work はエラーで停止していました。
また、会話で伝えた要件が Plans.md に載っていなくても検出されず、手動で追記する必要がありました。

**今後**: Plans.md がなければ `harness-plan create --ci` を自動呼び出しして生成。
会話からアクション動詞（「追加して」「修正して」等）を検出し、未記載タスクを v2 フォーマットで自動追記します。

#### 2. Codex exec レビューループ（Phase B）

**今まで**: Solo/Parallel モードにはレビューステージがなく、Worker のセルフレビューのみでした。
Breezing モードでは Reviewer agent が独立レビューしましたが、修正ループは手動承認が必要でした。

**今後**: 全モード共通で実装完了後に自動レビューを実行します。
Codex exec（優先）→ 内部 Reviewer agent（フォールバック）の 2 段構成。
REQUEST_CHANGES 時は自動修正→再レビュー（最大 3 回）。

#### 3. レビュー閾値基準（Phase B 追加）

**今まで**: 自由レビューのため、minor な改善提案でも REQUEST_CHANGES が返り、レビューループが収束しませんでした。

**今後**: レビュープロンプトに 4 段階の閾値基準（critical/major/minor/recommendation）を明示的に渡します。
critical/major のみ REQUEST_CHANGES、minor/recommendation は APPROVE。
スコープ外の指摘（外部ツールの制約等）も verdict に影響しない設計です。

#### 4. リッチ完了報告（Phase C）

**今まで**: タスク完了後の報告は簡素なテキスト（Progress: Task N/M 完了）のみでした。

**今後**: コミット後に視覚的サマリを自動出力します。
「何をしたか」「何が変わるか（Before/After）」「変更ファイル」「残りの課題（Plans.md 連動）」をボックス形式で表示。
Breezing モードでは全タスク完了後にまとめ報告。

#### 5. codex exec フラグ統一

**今まで**: 全スキル・スクリプトが旧フラグ `-a never`（codex-cli 0.115.0 で廃止）を使用しており、codex exec が即エラー終了していました。

**今後**: 全箇所を `--full-auto` に統一。`$TIMEOUT` 展開も `${TIMEOUT:+$TIMEOUT N}` の安全パターンに修正。
レビュー用 codex exec は `--sandbox read-only` で write 権限なし。

#### 6. platform copy 完全同期

**今まで**: primary の `skills/` と platform copy（`codex/.codex/skills/`, `opencode/skills/`, `skills-v3/`）が手動同期のため乖離していました。

**今後**: 今回の変更で全 platform copy を primary と完全同期。
`harness-review` の BASE_REF 対応、`breezing` の Review Policy も全 copy に反映済み。

#### 7. Breezing レビューループ実装（Phase F）

**今まで**: Breezing モードでは Worker が main に直接コミットしてから Reviewer がレビューしていました。
REQUEST_CHANGES が出ても既にコミット済みで、修正ループが構造的に成立しませんでした。

**今後**: Worker は worktree 内でコミットし、Lead がレビュー後に main へ cherry-pick する方式に変更。
- Worker: `mode: breezing` で worktree 内 commit → Lead に `{commit, worktreePath}` を返す
- Lead: Codex exec / Reviewer agent でレビュー → APPROVE なら `git cherry-pick`
- REQUEST_CHANGES: Lead が SendMessage で Worker に修正指示 → Worker が amend → 再レビュー（最大 3 回）
- Phase C: Lead が `git log` + Plans.md から Breezing まとめ報告を生成

Worker の出力 JSON に `worktreePath` / `summary` フィールドを追加。
Plans.md 更新は Lead が一元管理（Worker は breezing 時に Plans.md を編集しない）。

## [3.11.0] - 2026-03-20

### テーマ: Claude Code v2.1.77〜v2.1.79 統合 + 「書いただけ禁止」品質革命

**CC 最新版を統合し、セルフレビューで判明した「書いただけ問題」を構造的に解決。StopFailure ログ記録・通知の仕組みを追加し、Effort 動的注入・Sandbox 自動設定の設計方針を SKILL.md・エージェント定義に追加。**

---

#### 1. Claude Code v2.1.77〜v2.1.79 統合

21 件の新機能・修正を Feature Table に追加し、Harness での活用方法を文書化。

##### 1-1. `StopFailure` フックイベント対応

**CC のアプデ**: v2.1.78 で API エラー（レート制限 429、認証失敗 401 等）によるセッション停止失敗を捕捉する `StopFailure` イベントが追加された。

**Harness での活用**: `stop-failure.sh` ハンドラーを新設し、エラー情報をログに記録（`${CLAUDE_PLUGIN_DATA}` 設定時はプロジェクト別スコープ、未設定時は `.claude/state/stop-failures.jsonl`）。Breezing Worker のレート制限による停止失敗の事後分析に活用可能。

##### 1-2. PreToolUse `allow` / `deny` 優先順位の明文化

**CC のアプデ**: v2.1.77 で PreToolUse フックが `allow` を返しても settings.json の `deny` ルールが優先されるセキュリティ修正が入った。

**Harness での活用**: hooks-editing.md にバージョン注記を追加し、guardrail 設計時の優先順位を明文化。`deny: ["mcp__*"]` パターンが推奨に。

##### 1-3. Feature Table v2.1.77〜v2.1.79 追加（21 項目）

**CC のアプデ**: Output token 64k/128k 拡大、`allowRead` sandbox、Agent `resume` 廃止 → `SendMessage`、`/branch` リネーム、`${CLAUDE_PLUGIN_DATA}` 変数、Agent `effort` frontmatter 等。

**Harness での活用**: CLAUDE.md Feature Table と docs/CLAUDE-feature-table.md の両方に全項目を追加。各機能の Harness での活用方法・影響を詳細記載。

### Changed

- session-control スキルの description を `/fork` → `/branch` に更新（v2.1.77 リネーム対応）
- hooks-editing.md のイベント型一覧に `StopFailure`, `ConfigChange` を追加
- hooks-editing.md に v2.1.77+ PreToolUse 優先順位と v2.1.78+ StopFailure の注記を追加
- core/src/types.ts の `SignalType` に `stop_failure` を追加
- `.claude-plugin/settings.json` に `mcp__codex__*` の deny ルールを追加（v2.1.78 推奨パターン）
- `codex-cli-only.md` に settings.json deny パターンの推奨セクションを追加
- `stop-failure.sh`, `notification-handler.sh` のステート保存パスを `${CLAUDE_PLUGIN_DATA}` 対応（フォールバック付き）
- Worker/Reviewer エージェント定義に `effort: medium` フィールドを追加（v2.1.78 公式対応）
- `harness-setup/SKILL.md` に環境変数リファレンス（`CLAUDE_PLUGIN_DATA`, `ANTHROPIC_CUSTOM_MODEL_OPTION` 等）を追加

### Added

#### Phase 28.0: 「書いただけ禁止」ガードレールスキル

**今まで**: CC のアプデがあると Feature Table に転記するだけで「Harness の付加価値」にならないことがあった。3エージェント並列レビューで21項目中14項目が「書いただけ」と判明。

**今後**: `skills/cc-update-review/`（非配布・内部専用スキル）が CC アプデ統合時に全 Feature Table 項目を A/B/C に自動分類。カテゴリ B（書いただけ）が検出されると、実装案の提示を強制する。`.claude/rules/cc-update-policy.md` でルール化。

#### Phase 28.1: StopFailure 自動復旧の設計追加

**今まで**: Breezing で Worker がレート制限（429）で死ぬと、ログに記録されるだけ。Lead も人間も気づかず、Worker が静かに消えていた。

**今後**: `breezing/SKILL.md` に StopFailure 自動復旧フローの設計を追加。429 → 指数バックオフ（30s/60s/120s）+ `SendMessage` で Worker 自動再開。401 → ユーザー通知。500 → Plans.md にブロッカー記録。`stop-failure.sh` が 429 検出時に `systemMessage` で Lead に通知する仕組みを実装済み。

#### Phase 28.2: Effort 動的注入の設計追加

**今まで**: Worker/Reviewer の `effort: medium` は固定値。harness-work のスコアリング（≥3 で ultrathink）と Agent frontmatter の `effort` フィールドが接続されていなかった。

**今後**: `harness-work/SKILL.md` にスコアリング → effort 注入のフロー設計を追記。`agents-v3/worker.md` に動的 effort 受け取りと事後記録の手順を追加。Worker はタスク完了時に `effort_applied`, `effort_sufficient`, `turns_used` を agent memory に記録し、次回のスコアリング精度向上に活用する方針。

#### Phase 28.3: ログ可視化 + Sandbox テンプレート追加

**今まで**: `stop-failures.jsonl` にログが溜まるが見る手段がない。Reviewer の sandbox 設定がなく、`.env.example` すら読めない環境もあった。

**今後**: `scripts/show-failures.sh` でエラーコード別・時間帯別のサマリーを表示可能に（実装済み）。`.claude-plugin/settings.json` に `sandbox.allowRead` テンプレートを追加済み（`.env.example`, `docs/**` 等）。`harness-setup init` でプロジェクト種別に応じた sandbox 自動生成の手順を SKILL.md に追記。

---

- `scripts/hook-handlers/stop-failure.sh` — StopFailure フックハンドラー（429 時の systemMessage 通知付き）
- `skills/cc-update-review/SKILL.md` — CC アプデ統合の品質ガードレールスキル（非配布）
- `.claude/rules/cc-update-policy.md` — Feature Table 追加時の品質ポリシー
- hooks.json (両ファイル) に `StopFailure` イベント定義
- `tests/validate-plugin.sh` に `claude plugin validate` ステップ（v2.1.77+ 利用可能時のみ実行）
- `.claude-plugin/settings.json` に `sandbox.allowRead` テンプレート

## [3.10.6] - 2026-03-19

### テーマ: プラグイン利用者向け品質改善

**`claude plugin install` 後に発生する致命的エラーと UX 問題を修正。Issue #64, #65 対応。**

---

### Fixed

#### 0-1. プラグインインストール後にフックが MODULE_NOT_FOUND で全滅する問題を修正（Issue #64）

**今まで**: `core/dist/` が `.gitignore` で除外されていたため、`claude plugin install` した環境にコンパイル済み JavaScript が存在せず、全フック（PreToolUse / PostToolUse / PermissionRequest）が `MODULE_NOT_FOUND` で即座に失敗していた。ガードレールエンジン（R01-R09）が完全に無効化される致命的な問題。

**今後**: `.gitignore` から `/core/dist/` の除外を解除し、ビルド済み JS をリポジトリに含めるように変更。プラグインインストール後すぐにフックが動作する。

#### 0-2. PostToolUse HTTP hook がデフォルトでエラーを出す問題を修正（Issue #65）

**今まで**: `hooks.json` に `localhost:9090` 宛のメトリクス HTTP hook がデフォルトで有効になっていた。メトリクスサーバーを立てていないユーザーは `Write`/`Edit`/`Bash`/`Task` のたびに connection refused エラーが発生し、最大5秒の遅延も生じていた。CHANGELOG では「テンプレート」と説明されていたが、実際にはアクティブだった。

**今後**: HTTP hook エントリを `hooks.json` から削除し、`docs/examples/hooks-metrics-http.json` にテンプレートとして移動。デフォルト状態ではエラーが出ない。メトリクス連携を使いたいユーザーはテンプレートを参照して自分の hooks.json に追加する運用に変更。

#### 0-3. 壊れたシンボリックリンク `codex-review` を削除

**今まで**: `skills-v3/extensions/codex-review` が `../../skills/codex-review` を指していたが、リンク先の `skills/codex-review/` ディレクトリが存在せず、broken symlink になっていた。

**今後**: 壊れたシンボリックリンクを削除。`codex-review` 機能が実装された段階で改めて追加する。

#### 0-4. `plugin.json` と `marketplace.json` のライセンス不整合を修正

**今まで**: `plugin.json` では `"license": "MIT"` だが、`marketplace.json` では `"license": "Proprietary"` と矛盾していた。

**今後**: `marketplace.json` のライセンスを `"MIT"` に統一。

### Changed

#### 1. エージェント `disallowedTools` を公式名称に統一

**今まで**: Worker / Reviewer / Scaffolder の `disallowedTools` に旧名称 `[Task]` を使用していた。CC v2.1.63 で Task ツールは Agent にリネーム済みで、`Task` はエイリアスとして動作するものの、公式ドキュメントは一貫して `Agent` を使用している。

**今後**: 全エージェント定義の `disallowedTools` を `[Agent]` に更新。公式ドキュメントとの一貫性を確保し、将来のエイリアス廃止に備える。

### Added

#### 2. Notification ハンドラーに `elicitation_dialog` 対応を追加

**今まで**: CC v2.1.76 で追加された MCP Elicitation の通知タイプ `elicitation_dialog` が Notification ハンドラーで個別検出されていなかった。`Elicitation` フックで自動スキップは実装済みだが、Notification 側のログ検出が不足していた。

**今後**: `notification-handler.sh` に `elicitation_dialog` の検出を追加。Breezing のバックグラウンド Worker で MCP Elicitation が発生した場合、`permission_prompt` と同様にログ記録される。事後分析での Elicitation 発生状況の追跡が可能になった。

#### 3. `harness-ops` Output Style をプラグインコンポーネントとして追加

**今まで**: Feature Table で `harness-ops` 出力スタイルに言及していたが、実際のスタイルファイルが存在しなかった。また plugin.json に `outputStyles` フィールドが未設定で、プラグイン経由での配布ができなかった。

**今後**: `output-styles/harness-ops.md` を作成し、Plan/Work/Review フェーズに応じた構造化出力スタイルを定義。plugin.json に `outputStyles: "./output-styles/"` を追加し、プラグインインストール時に自動配布される。ユーザーは `/config` → Output style から `Harness Ops` を選択可能。

## [3.10.5] - 2026-03-15

### テーマ: set-locale.sh の skills-v3 対応

**`set-locale.sh` が `skills-v3/` ディレクトリを処理対象外としていた不具合を修正。**

---

### Fixed

#### 1. `set-locale.sh` が `skills-v3/` を処理しない問題

**今まで**: `scripts/i18n/set-locale.sh ja` を実行しても、`skills-v3/` ディレクトリ内の SKILL.md は `description` フィールドが英語のまま残っていた。`skills/`、`codex/.codex/skills/`、`opencode/skills/` は処理されるが、v3 アーキテクチャで導入された `skills-v3/` が処理対象リストから漏れていた。

**今後**: `process_skill_dir` の呼び出しに `skills-v3/` を追加。4 ディレクトリすべてが一括で切り替わるようになった。

### Changed

- `.gitignore`: `.superset/`、`skills/x-announce/` を追跡対象外に追加

## [3.10.4] - 2026-03-15

### テーマ: エージェント安全制限と Notification フック実装

**エージェントの暴走を防止する `maxTurns` 安全弁を全サブエージェントに導入し、ドキュメントのみだった Notification フックの実装を完了。**

---

### Added

#### 1. エージェント暴走防止の `maxTurns` 安全制限

**今まで**: Worker / Reviewer / Scaffolder の 3 エージェントにターン上限が設定されていなかった。エージェントが無限ループや過剰な探索に陥った場合、コンテキスト窓を使い切るまで停止せず、トークンコストが制御不能になる恐れがあった。

**今後**: CC 公式ドキュメントで推奨されている `maxTurns` フィールドを全エージェントの frontmatter に追加。Worker: 100（複雑な実装タスク向け）、Reviewer: 50（Read-only 分析に特化）、Scaffolder: 75（中間的な複雑度）。上限到達時は Lead が途中結果を回収して判断できる。`bypassPermissions` と組み合わせることで、暴走時の安全弁として機能する。

#### 2. `Notification` フックハンドラの実装

**今まで**: hooks-editing.md と Feature Table に `Notification` イベントが記載されていたが、hooks.json にハンドラが登録されていなかった。26 フックイベント中、唯一の「ドキュメントあり・実装なし」の乖離状態だった。

**今後**: `notification-handler.sh` を新規作成し、hooks.json の両ファイル（source + distribution）に登録。`permission_prompt` / `idle_prompt` / `auth_success` 等の通知イベントを `.claude/state/notification-events.jsonl` にログ記録。特に Breezing のバックグラウンド Worker で発生した permission_prompt の事後分析が可能に。

#### 3. `/context` コマンドを Feature Table に追加

**今まで**: CC v2.1.74 で追加された `/context` コマンド（コンテキスト消費の可視化と最適化提案）が Feature Table に未記載だった。

**今後**: CLAUDE.md の概要テーブルと docs/CLAUDE-feature-table.md の詳細セクションに追加。長時間 Breezing セッションでのコンパクション頻発の原因特定に有用。

## [3.10.3] - 2026-03-14

### Changed

- release metadata updates are now release-only: normal PRs should leave `VERSION` and `.claude-plugin/plugin.json` untouched and record changes under `[Unreleased]`
- pre-commit and CI now validate release metadata consistency without auto-bumping patch versions on ordinary code changes
- README and README_ja now use the GitHub latest release badge instead of hardcoded per-version badge URLs
- `.claude/rules/hooks-editing.md` now documents `SessionEnd` timeout guidance and `CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS` so the PR61 docs fix can be merged without carrying release metadata drift
- Codex workflow docs now standardize on `$harness-plan`, `$harness-sync`, `$harness-work`, `$breezing`, and `$harness-review`, and setup scripts archive removed legacy Harness skills from `~/.codex/skills`

### Added

#### 1. Feature Table に公式ドキュメント由来の 9 機能を追加

**今まで**: Claude Code 公式ドキュメント（60+ ページ）に記載されている `--remote` / Cloud Sessions、`/teleport`、`CLAUDE_CODE_REMOTE`、`CLAUDE_ENV_FILE`、Slack Integration、Server-managed settings、Microsoft Foundry、`PreCompact` hook、`Notification` hook event が Feature Table に未登録だった。

**今後**: `docs/CLAUDE-feature-table.md` に 9 エントリを追加（概要テーブル + 機能詳細セクション）。`CLAUDE.md` にも高インパクトな 4 項目を反映。各機能の Harness での活用方法、コード例、前提条件を詳細に記述。

#### 2. session-env-setup.sh にクラウドセッション検出を追加

**今まで**: `session-env-setup.sh` はローカル環境前提で、クラウドセッション（`--remote` 実行時）かどうかを判定する手段がなかった。

**今後**: `CLAUDE_CODE_REMOTE` 環境変数を `HARNESS_IS_REMOTE` として `CLAUDE_ENV_FILE` に永続化。他のフックハンドラがクラウド vs ローカルの条件分岐を行えるようになった。

#### 3. hooks-editing.md に PreCompact / Notification イベントを追加

**今まで**: hooks-editing.md の Event Types 一覧に `PreCompact` と `Notification` が記載されておらず、開発者が新しいフックを追加する際に参照できなかった。

**今後**: Event Types JSON ブロックに `PreCompact`（コンテキスト圧縮前の状態保存）と `Notification`（通知発火時のカスタムハンドラ）を追加。Harness では `PreCompact` はすでに実装済み（command + agent の 2 層構成）。

#### 4. Codex command surface 整理 + stale skill cleanup

**今まで**: Codex 側では `$work` / `$plan-with-agent` / `$verify` など旧 command surface が文書上に残り、`~/.codex/skills` にも update 後の legacy Harness skill が残留して一覧を汚すことがあった。

**今後**:

- **Codex docs**: 主導線を `$harness-plan`, `$harness-sync`, `$harness-work`, `$breezing`, `$harness-review` に統一
- **setup scripts**: `scripts/setup-codex.sh` / `scripts/codex-setup-local.sh` が、現在 ship されていない legacy Harness skill を backup へ退避
- **test coverage**: `tests/test-codex-package.sh` と `validate-plugin-v3.sh` で `harness-sync` surface、native multi-agent 文言、legacy skill cleanup の回帰を追加

#### 5. Claude Code 2.1.76 統合

Claude Code 2.1.76 の新機能を Harness に統合。Feature Table のバージョン表記を `2.1.74+` → `2.1.76+` に更新。

##### 5-1. MCP Elicitation への自動対応

**CC のアプデ**: MCP サーバー（GitHub, Slack 等の外部ツール接続）が、タスク実行中にユーザーへ「質問」できるようになった（Elicitation）。例えば「どのリポジトリに push しますか？」のようなフォーム入力を求められる。あわせて `Elicitation`（質問前）と `ElicitationResult`（回答後）の 2 つのフックイベントが追加された。

**Harness での活用**: Breezing の Worker はバックグラウンド実行のため、MCP からの質問フォームに応答できない。放置すると Worker がフリーズする。そこで `elicitation-handler.sh` を新規作成し、Breezing セッション中は elicitation を自動スキップ、通常セッションではそのまま通過してユーザーが回答する仕組みを実装。`elicitation-result.sh` で結果をログ記録。

##### 5-2. PostCompact によるコンテキスト再注入

**CC のアプデ**: コンテキスト圧縮（コンパクション）の**完了後**に発火する `PostCompact` フックが追加された。既存の `PreCompact`（圧縮前）と対になる。

**Harness での活用**: 長時間セッションで圧縮が起きると「今どのタスクをやっているか」が薄まる問題があった。`post-compact.sh` を新規作成し、圧縮後に Plans.md の WIP/TODO タスク状態を自動で再注入。PreCompact（状態保存）→ PostCompact（状態復元）の対称構造で、作業文脈の継続性を確保。

##### 5-3. Worktree の高速化と安定化

**CC のアプデ**: 3 つの改善が入った。(1) `worktree.sparsePaths` 設定で巨大リポジトリの worktree 作成時に必要ディレクトリだけをチェックアウト、(2) git refs 直接読取による `--worktree` 起動高速化、(3) 中断された並列実行で残った stale worktree の自動クリーンアップ。

**Harness での活用**: Breezing で複数 Worker を同時起動する際の起動時間が短縮。stale worktree の手動削除も不要に。breezing/SKILL.md と harness-work/SKILL.md にそれぞれ活用ガイドを追記。

##### 5-4. セッション命名と Effort 動的制御

**CC のアプデ**: `-n`/`--name` フラグでセッションに表示名を設定可能に。`/effort` コマンドでセッション中に思考の深さ（low/medium/high）を切替可能に。

**Harness での活用**: Breezing セッションに `breezing-{timestamp}` 形式の名前を設定してセッション識別を容易に。harness-work の多要素スコアリング（タスク複雑度に応じた自動 effort 調整）と `/effort` 手動切替の併用が可能に。

##### 5-5. バックグラウンドエージェント部分結果保持

**CC のアプデ**: バックグラウンドエージェントが kill（タイムアウトや手動停止）された場合にも、途中の作業結果がコンテキストに残るようになった。以前は全損だった。

**Harness での活用**: Breezing の Worker が途中停止しても、Lead が途中成果を引き継いで別 Worker に再割り当て可能に。「やり直し」コストが削減。

##### 5-6. 自動コンパクション circuit breaker

**CC のアプデ**: 自動コンパクションが 3 回連続失敗すると停止するサーキットブレーカーが導入。無限リトライによるトークン浪費を防止。

**Harness での活用**: Harness の「3 回ルール」（CI 失敗時の 3 回制限）と同じ設計思想。長時間 Breezing での予期せぬコスト増加を防止。

##### 5-7. `--plugin-dir` 破壊的変更

**CC のアプデ**: `--plugin-dir` が 1 パスのみ受付に変更。複数ディレクトリは `--plugin-dir path1 --plugin-dir path2` と繰り返し指定する方式に。

**Harness への影響**: Harness プラグイン単体使用では影響なし。複数プラグイン同時使用時のみ構文変更が必要。

---

## [3.10.2] - 2026-03-12

### テーマ: TaskCompleted finalize hardening + Claude Code 2.1.74 docs/README 整合

**全タスク完了時点で `harness-mem` finalize を前倒しする安全化を実装し、Claude Code 2.1.74 に合わせた feature docs / README / 互換性スナップショットを release metadata まで同期。version bump 欠落で落ちていた validate-plugin も、正しい patch release として回収しました。**

---

#### 1. TaskCompleted ベースの finalize を安全化

**今まで**: セッションの締め処理は Stop 時点に寄っており、「最後のタスクは終わったが Stop 前に落ちた」ケースで `harness-mem` 側の完了記録が取りこぼされる余地があった。

**今後**: `task-completed.sh` が「完了数 >= 総タスク数」を検出した瞬間に `work_completed` で `/v1/sessions/finalize` を一度だけ実行。`session.json` からの `session_id` / `project_name` fallback、成功 marker による idempotency、`HARNESS_MEM_BASE_URL` によるテスト可能性、API 不達時の silent skip を追加。

#### 2. finalize 回帰テストを追加

**今まで**: fix proposal 系テストはあっても、「最後のタスクだけ finalize」「重複 finalize しない」「session_id 未解決時は skip」を直接検証する fixture がなかった。

**今後**: `tests/test-task-completed-finalize.sh` を追加し、TaskCompleted フックからの finalize 発火条件と安全条件を独立して検証。既存の `tests/test-fix-proposal-flow.sh` と合わせて、進捗制御と完了確定の両方を回帰確認できる。

#### 3. Claude Code 2.1.74 docs / README / compatibility を同期

**今まで**: `docs/CLAUDE-feature-table.md` は 2.1.74 機能を取り込み始めていた一方、README の機能サマリーは `2.1.71+`、互換性ドキュメントの latest verified snapshot は `2.1.69` / plugin `3.6.0` のままだった。

**今後**: feature table を `2.1.74+` に統一し、README 英日と `docs/CLAUDE_CODE_COMPATIBILITY.md` を現行実測に合わせて更新。`modelOverrides`、`autoMemoryDirectory`、`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`、full model ID 対応など、2.1.73〜2.1.74 の主要項目をサマリーに反映。

#### 4. Release metadata を 3.10.2 へ昇格

**今まで**: `4239d542` はコード変更を含むのに `VERSION` / `plugin.json` / README badge / CHANGELOG が `3.10.1` のままで、GitHub Actions `validate-plugin` が version bump missing で失敗していた。

**今後**: `VERSION`、`.claude-plugin/plugin.json`、README 英日の version badge、CHANGELOG compare links を `3.10.2` に揃え、patch release として publish 可能な状態に修正。

---
## [3.10.1] - 2026-03-12

### テーマ: Claude Code 公式ドキュメント深層統合 — 12 機能追加 + Auto Mode rollout 整理 + SubagentStart/Stop matcher 強化

**公式ドキュメント 60 ページの精査により発見した未追跡機能 12 項目を Feature Table に追加。Auto Mode は shipped default と rollout target を分けて整理し、SubagentStart/SubagentStop hooks には agent type 別 matcher を追加して Worker/Reviewer/Scaffolder/Video Generator の起動・停止を個別にトラッキング可能に。**

---

#### 1. SubagentStart/SubagentStop matcher 強化

**今まで**: `SubagentStart`/`SubagentStop` hooks は全エージェント一律で `subagent-tracker` を起動。team-composition.md では「SubagentStart: 未実装」と誤記載。

**今後**: agent type 別の matcher（`worker`, `reviewer`, `scaffolder`, `video-scene-generator`）を追加。各エージェントの起動・停止を個別にトラッキングし、ロール別のメトリクス収集を可能に。team-composition.md の Quality Gate Hooks テーブルも実態に合わせて更新。

#### 2. Feature Table に 12 機能追加

**今まで**: Chrome Integration, LSP サーバー統合, Task Dependencies, `/btw`, Plugin CLI コマンド群等の公式ドキュメント記載機能が Feature Table に未登録。

**今後**: 以下を Feature Table（概要テーブル + 機能詳細セクション）に追加:
- Chrome Integration (`--chrome`, beta)
- LSP サーバー統合 (`.lsp.json`)
- SubagentStart/SubagentStop matcher
- Agent Teams: Task Dependencies
- `--teammate-mode` CLI フラグ
- `CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`
- `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`
- `cleanupPeriodDays` 設定
- `/btw` サイドクエスチョン
- Plugin CLI コマンド群
- Remote Control 強化
- `skills` フィールド in agent frontmatter

#### 3. CLAUDE.md Feature Table サマリー更新

**今まで**: CLAUDE.md の要約テーブルに Chrome Integration, LSP, matcher, Task Dependencies 等が含まれていなかった。

**今後**: 最もインパクトの大きい 6 機能を CLAUDE.md の要約テーブルに追加。

#### 4. Breezing の Auto Mode rollout を整理

**今まで**: Auto Mode の説明が実装より先行し、Breezing で既定化済みのように読める状態だった。

**今後**: shipped default は `bypassPermissions` のまま維持し、`--auto-mode` は互換な親セッションでのみ試す opt-in rollout として文書化する。project template / frontmatter には公式 docs に載っている `bypassPermissions` を残す。

---

## [3.10.0] - 2026-03-11

### テーマ: Claude Code ドキュメント機能 10 項目の Harness 統合 + Status Line 実装

**Claude Code の公式ドキュメントに記載された新機能（Sandboxing, Model Configuration, Checkpointing, Code Review, Status Line 等）を Feature Table に統合し、Harness 専用ステータスラインスクリプトを新規追加。**

---

#### 1. Sandboxing (`/sandbox`) 統合

**今まで**: Worker の Bash コマンドは `bypassPermissions` + hooks で制御していた。OS レベルのファイルシステム/ネットワーク隔離は Harness の運用ガイドに含まれていなかった。

**今後**: Claude Code のネイティブ Sandboxing（macOS Seatbelt / Linux bubblewrap）を `bypassPermissions` の**補完レイヤー**として位置づけ。段階導入計画（Phase 0→1→2）を `team-composition.md` に追加。Worker の Bash に OS レベルの安全境界を段階的に導入する方針。

#### 2. Model Configuration 3 機能

**今まで**: Worker/Reviewer のモデルはエージェント定義の `model: sonnet` で固定。Lead も単一モデルで Plan と Execute を実行していた。

**今後**:
- **`opusplan` エイリアス**: Lead セッションで Plan 時に Opus、Execute 時に Sonnet を自動切替
- **`CLAUDE_CODE_SUBAGENT_MODEL`**: 全サブエージェントのモデルを環境変数で一括指定（CI でのコスト削減に有用）
- **`availableModels`**: エンタープライズ環境でのモデルガバナンス

#### 3. Checkpointing (`/rewind`) 対応

**今まで**: セッション中にファイル編集が期待通りでなかった場合、手動で git revert するか、最初からやり直す必要があった。

**今後**: `Esc+Esc` または `/rewind` でセッション内の任意のポイントに巻き戻し可能。「ここから要約」で冗長なデバッグセッションのコンテキスト窓を選択的に回収。`harness-work` のセルフレビューフェーズでの安全な探索に活用。

#### 4. Code Review (managed service) 対応

**今まで**: Harness の `harness-review` はローカルエージェントによるコードレビューのみ。

**今後**: Anthropic インフラ上のマルチエージェント PR レビュー（Teams/Enterprise 向け Research Preview）を Feature Table に追加。`REVIEW.md` によるレビュー固有ガイダンスの仕組みを文書化。ローカルレビュー（`harness-review`）と managed レビューは補完的な二重検査として位置づけ。

#### 5. Harness Status Line スクリプト新規追加

**今まで**: Claude Code の `/statusline` 機能は存在していたが、Harness 固有のステータス表示がなかった。

**今後**: `scripts/statusline-harness.sh` を新規追加。以下を 2 行で常時表示:
- Line 1: モデル名 + git ブランチ + staged/modified ファイル数 + エージェント名/ワークツリー名
- Line 2: コンテキスト使用率バー（70% 黄、90% 赤）+ セッションコスト + 経過時間 + 出力スタイル名

```bash
# 設定方法
/statusline use scripts/statusline-harness.sh
```

#### 6. Feature Table 拡充（10 項目追加）

`docs/CLAUDE-feature-table.md` と `CLAUDE.md` サマリーに以下を追加:
- Sandboxing (`/sandbox`)
- `opusplan` モデルエイリアス
- `CLAUDE_CODE_SUBAGENT_MODEL` 環境変数
- `availableModels` 設定
- Checkpointing (`/rewind`)
- Code Review (managed service)
- Status Line (`/statusline`)
- 1M Context Window (`sonnet[1m]`)
- Per-model Prompt Caching Control
- `CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`

---

## [3.9.0] - 2026-03-11

### テーマ: Output Styles 統合 + Agent 定義強化 + Agent Teams 公式ベストプラクティス整合

**Claude Code 公式ドキュメントの Output Styles / Agent Teams / エージェント frontmatter の最新仕様を Harness に反映し、運用体験を向上。**

> **Release note**: 下書きとして積み上がっていた `v3.7.3` / `v3.8.0` 相当の変更は、この `v3.9.0` 正式リリースに統合した。

---

#### 1. Harness Output Style 新規追加

**今まで**: Plan/Work/Review の進捗報告や Quality Gate 結果のフォーマットが統一されておらず、各スキル・エージェントが独自の出力形式で報告していた。

**今後**: `.claude/output-styles/harness-ops.md` を新設。`/output-style harness-ops` で有効化すると、以下が構造化されて出力される:
- 進捗報告（実施/現在地/次アクション形式）
- Quality Gate 結果（Build/Test/Lint の表形式）
- Review 判定（APPROVE/REQUEST_CHANGES の構造化フォーマット）
- エスカレーション（3回ルール違反時の標準出力形式）
- 判断ポイント（最大3選択肢、推奨先頭）

```bash
/output-style harness-ops
```

#### 2. エージェント定義に `permissionMode` を明示追加

**今まで**: Worker/Reviewer/Scaffolder の権限モードは spawn 時に `mode: "bypassPermissions"` として指定。エージェント定義自体には権限情報がなく、Lead の spawn コードに依存していた。

**今後**: Claude Code 公式ドキュメントで `permissionMode` がエージェント frontmatter の正式フィールドとして文書化されたことを受け、3エージェント全ての frontmatter に `permissionMode: bypassPermissions` を追加。定義レベルでの宣言的権限管理を実現。

```yaml
# agents-v3/worker.md
permissionMode: bypassPermissions  # 新規追加
```

#### 3. Agent Teams 公式ベストプラクティス整合

**今まで**: Harness のチーム運用は独自のパターンに基づいていた。Claude Code の Agent Teams は「実験的」というステータスのみで、公式ガイダンスが限定的だった。

**今後**: `agent-teams.md` が独立した公式ドキュメントに昇格。`agents-v3/team-composition.md` に以下を反映:
- **タスク粒度ガイドライン**: 5-6 tasks/teammate の公式推奨値
- **`teammateMode` 設定**: `"auto"` / `"in-process"` / `"tmux"` の3モード
- **Plan Approval パターン**: Worker に plan mode を要求する公式フロー
- **Quality Gate Hooks**: `TeammateIdle`/`TaskCompleted` の exit 2 フィードバックパターン
- **チームサイズ**: 3-5 teammates の公式推奨（Harness の Worker 1-3 + Reviewer 1 と整合確認）

#### 4. Feature Table 拡充（3項目追加）

`docs/CLAUDE-feature-table.md` に以下を追加:
- Output Styles 統合
- `permissionMode` in agent frontmatter
- Agent Teams 公式ベストプラクティス整合

#### 5. Pre-merge 整合修正

**今まで**: README のバージョンバッジ、compare link、Auto Mode の段階表記、`validate-plugin` の core dependency step、opencode mirror が一部不整合で、required checks を安定して通せない状態だった。

**今後**: 版表記と compare link を同期し、Auto Mode は「staged rollout / RP 開始後に検証」へ表現を是正。`validate-plugin` は `core/package.json` をキャッシュキーにして `npm install` を使う構成へ修正し、opencode mirror も再生成前提で整える。

---

### Included: Claude Code v2.1.72 互換対応

**Claude Code v2.1.72 の全新機能・修正を Harness に反映。Effort レベル簡素化、ExitWorktree ツール、Agent tool model パラメータ復活、並列ツール呼び出し修正など、12 項目の機能を Feature Table とエージェント定義に追記。**

---

#### 1. ExitWorktree ツール対応

**今まで**: worktree セッションからの離脱はセッション終了時のプロンプトに依存。Worker エージェントが実装完了後にプログラム的に worktree を閉じる手段がなかった。

**今後**: CC v2.1.72 の `ExitWorktree` ツールにより、Worker が実装完了後に明示的に worktree を離脱可能。`agents-v3/worker.md` に「Worktree 操作」セクションを追加し、`ExitWorktree` の活用方法を文書化。

#### 2. Effort レベル簡素化（`max` 廃止）

**今まで**: effort レベルに `max` が存在していたが、Harness のドキュメントでは `ultrathink` → high effort の対応のみ使用。

**今後**: CC v2.1.72 で `max` が廃止、3段階 `low(○)/medium(◐)/high(●)` に統一。Harness のドキュメントをシンボル付きで更新。影響ファイル:
- `skills-v3/harness-work/SKILL.md` + 3 ミラー
- `agents-v3/worker.md`
- `agents-v3/reviewer.md`
- `agents-v3/team-composition.md`

#### 3. Agent tool `model` パラメータ復活

**今まで**: per-invocation model override が利用不可だった期間があり、エージェント定義の `model` フィールドのみで運用。

**今後**: CC v2.1.72 で Agent tool の `model` パラメータが復活。タスク特性に応じた動的モデル選択が再び可能に。`agents-v3/team-composition.md` に Phase 2 検討項目として記載。

#### 4. Feature Table 拡充（12 項目追加）

`CLAUDE.md` と `docs/CLAUDE-feature-table.md` に以下を追加:
- `ExitWorktree` ツール
- Effort levels 簡素化
- Agent tool `model` パラメータ復活
- `/plan` description 引数
- 並列ツール呼び出し修正
- Worktree isolation 修正
- `/clear` バックグラウンドエージェント保持
- Hooks 修正群（4 件）
- HTML コメント非表示
- Bash auto-approval 追加
- プロンプトキャッシュ修正

各機能の詳細セクションも `docs/CLAUDE-feature-table.md` に追記。

#### 5. バージョンヘッダー更新

`CLAUDE.md` と `docs/CLAUDE-feature-table.md` のヘッダーを `2.1.71+` → `2.1.72+` に更新。

---

### Included: Claude Code 公式ドキュメント整合

**Claude Code v2.1.71+ の公式ドキュメントに追加された新機能・フィールドを Harness のドキュメントに反映し、Auto Mode Phase 1 移行マーカーを更新。**

---

#### 1. Feature Table 拡充（9 項目追加）

**今まで**: v2.1.71 リリース時点の機能のみ記載。公式ドキュメントで追加されたサブエージェントの新フィールドや Agent Teams の実験フラグが未反映。

**今後**: 以下の機能を Feature Table に追加:
- Subagent `background` フィールド
- Subagent `local` メモリスコープ
- Agent Teams 実験フラグ (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`)
- `/agents` コマンド（対話的管理 UI）
- Desktop Scheduled Tasks
- `CronCreate/CronList/CronDelete` ツール
- `CLAUDE_CODE_DISABLE_CRON` 環境変数
- `--agents` CLI フラグ

各機能の詳細セクションも `docs/CLAUDE-feature-table.md` に追記。

#### 2. Auto Mode Phase 1 開始予定表記へ更新

**今まで**: 「Phase 0 (現在)」「Phase 1 (RP 開始)」と記載。RP 開始日 2026-03-12 以前の表記。

**今後**: 「Phase 0 (pre-RP)」「Phase 1 (RP 開始後)」に更新。影響ファイル:
- `docs/CLAUDE-feature-table.md`
- `CLAUDE.md` Feature Table
- `agents-v3/team-composition.md`

#### 3. Agent Teams 公式ドキュメント対応

**今まで**: Harness の breezing が Agent Teams を使用しているが、公式の有効化手順が未記載。

**今後**: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 環境変数の設定方法と `teammateMode` 設定を `agents-v3/team-composition.md` に追記。

---

## [3.7.2] - 2026-03-10

### Fixed
- **Hook stdout purity**: `session-init` and usage tracking hooks now discard telemetry output so hook consumers receive the JSON payload only.
- **Quiet session summary output**: `session-init` / `session-resume` no longer leak standalone `0` lines when Plans counts are zero matches.

### Changed
- **Regression coverage**: Added direct-execution tests for snapshot summary output and quiet usage tracking hooks to keep hook output stable.

---

## [3.7.1] - 2026-03-09

### テーマ: チーム実行の安全性向上

**Breezing（Agent Teams）の実行基盤を3つの観点から強化: エージェント型名の統一、Auto Mode への段階的移行準備、Worker の Worktree 隔離。**

---

#### 1. エージェント定義の統一

**今まで**: Worker や Reviewer のエージェント型名がファイルごとにバラバラでした。`breezing/SKILL.md` では `general-purpose`、`team-composition.md` では `claude-code-harness:worker` と書かれており、per-agent hooks（エージェント種別ごとのガードレール）が正しく発火しない問題がありました。

**今後**: 全ファイルで `claude-code-harness:worker` / `claude-code-harness:reviewer` に統一。Worker 専用の PreToolUse ガード（Write/Edit 時のチェック）と Reviewer 専用の Stop ログ（完了時の記録）が確実に適用されます。

#### 2. Auto Mode への準備（`--auto-mode`）

**今まで**: Breezing では Worker がバックグラウンド実行のため許可プロンプトを表示できず、`bypassPermissions`（全権限スキップ）を使っていました。動くけれど「全権限をスキップ」するため、意図しないファイル書き換えや危険なコマンドも素通りするリスクがありました。

**今後**: Claude Code 2.1.71+ の Auto Mode に対応する `--auto-mode` フラグを追加。Auto Mode は許可リスト方式で「定義済みの安全な操作だけを自動承認」し、危険な操作（`rm -rf`、`git push --force` 等）はブロックします。3段階で移行します:

- Phase 0（現在）: `--auto-mode` はオプトイン
- Phase 1（検証後）: `--auto-mode` をデフォルトに
- Phase 2（安定後）: `bypassPermissions` を廃止

```bash
/breezing --auto-mode              # Auto Mode で実行
/harness-work --breezing --auto-mode
```

#### 3. Worker の Worktree 隔離

**今まで**: 複数の Worker を並列実行したとき、同じファイルを2つの Worker が同時に編集すると競合が発生していました。Lead が「同じファイルを触るタスクは同じ Worker に割り当てる」ルールで回避していましたが、完璧ではありませんでした。

**今後**: Worker エージェント定義に `isolation: worktree` を追加。各 Worker は自動的に git worktree（独立した作業ディレクトリ）で動作するため、同じファイルを編集しても物理的に別ディレクトリなので衝突しません。完了後に Lead がマージします。

---

## [3.7.0] - 2026-03-08

### テーマ: 状態中心アーキテクチャへの転換

**まさお理論（マクロハーネス・ミクロハーネス・Project OS）を適用し、「会話が切れても作業が途切れない」仕組みを5つの機能で構築しました。**

---

#### 1. 失敗タスクの自動再チケット化

**今まで**: タスク実装後にテスト/CI が失敗すると、最大3回リトライして止まるだけでした。止まった後は「何が原因だったか」を自分で調べ、Plans.md に手動で修正タスクを追加し、再度 `/work` を実行する必要がありました。

**今後**: 3回失敗で止まるとき、Harness が失敗原因を分類（`assertion_error`、`import_error` 等）し、修正タスク案を state に保存します。`approve fix <task_id>` で承認すると Plans.md に `.fix` タスクとして追加されます。

```
失敗原因分析:
  カテゴリ: assertion_error
  修正タスク案: 26.1.1.fix — getByStatus の戻り値を修正
  DoD: npm test が全パスすること

承認: approve fix 26.1.1
却下: reject fix 26.1.1
```

将来的には、提案採用率80%以上で全自動化に昇格する計画です（D30）。

#### 2. セッションスナップショット（`/harness-sync --snapshot`）

**今まで**: セッションが切れた後の再開時、Plans.md を読み、git log を見て、自分で状況を把握する必要がありました。この「状況把握」に毎回時間がかかり、WIP タスクの進捗は Plans.md からは読み取れませんでした。

**今後**: `/harness-sync --snapshot` で、その瞬間の進捗を JSON に保存できます。次の SessionStart または `/resume` で最新スナップショット要約と前回比が自動表示されます。

```
スナップショット差分:

| 指標       | 前回 (03/08 22:00) | 今回       | 変化     |
|-----------|-------------------|-----------|---------|
| 完了タスク  | 8/16              | 13/16     | +5      |
| WIP タスク  | 2                 | 0         | -2      |
| TODO タスク | 6                 | 3         | -3      |
```

作業の「セーブポイント」のようなものです。

#### 3. Artifact Hash（タスクとコミットの紐付け）

**今まで**: Plans.md のタスクが `cc:完了` になっても、どのコミットで完了したか追跡できませんでした。「このタスクで何を変えたか」を知るには git log を手作業でたどる必要がありました。

**今後**: タスク完了時に、直近のコミットハッシュ（7文字短縮形）が Status に自動付与されます。

```markdown
| Task | 内容              | Status              |
|------|-------------------|---------------------|
| 26.1 | snapshot 機能追加  | cc:完了 [a1b2c3d]  |  ← 自動付与
```

`git show a1b2c3d` で、そのタスクの変更内容をいつでも確認できます。hash なしの `cc:完了` も引き続き有効（後方互換）。

#### 4. Progress Feed（Breezing 中の進捗表示）

**今まで**: `/breezing` で全タスクを並列実行するとき、完了するまでターミナルに進捗が表示されませんでした。10個以上のタスクがある場合、「今何個目が終わったか」がまったく見えず不安でした。

**今後**: Worker がタスクを完了するたびに、Lead が1行のプログレスサマリーを出力します。

```
📊 Progress: Task 1/16 完了 — "harness-work に失敗再チケット化を追加"
📊 Progress: Task 2/16 完了 — "harness-sync に --snapshot を追加"
📊 Progress: Task 3/16 完了 — "breezing にプログレスフィードを追加"
```

TaskCompleted hook の `systemMessage` も連動して進捗情報を出力します。

#### 5. Plans.md の Purpose 行

**今まで**: Phase ヘッダーには名前とタグだけ。「このフェーズの目的は何か」は本文を読まないと分かりませんでした。

**今後**: Phase ヘッダーの直後に、任意で `Purpose:` 行を1行追加できます。書かなくてもOK（強制ではありません）。ユーザーがフェーズの目的を述べた場合にのみ自動記載されます。

```markdown
### Phase 26.0: 失敗→再チケット化フロー [P0]

Purpose: 自己修正ループ失敗時に「止まるだけ」から「次の一手を提案」へ転換
```

---

## [3.6.0] - 2026-03-08

### 🎯 What's Changed for You

**Solo mode PM framework: structured self-questioning built into every skill. Impact×Risk planning, DoD/Depends columns, Value-axis reviews, and retrospectives — no new commands, just smarter existing ones.**

| Before | After |
|--------|-------|
| Plans.md had 3 columns (Task, Content, Status) | Plans.md has 5 columns (+DoD, +Depends); v1 format dropped |
| Priority was 1-axis (Required/Recommended/Optional) | 2-axis Impact×Risk matrix with automatic `[needs-spike]` for high-risk items |
| Plan Review checked 4 axes (Clarity/Feasibility/Dependencies/Acceptance) | 5 axes (+Value: user problem fit, alternative analysis, Elephant detection) |
| No retrospective capability | `sync` auto-runs retro when completed tasks exist (`--no-retro` to skip) |
| Breezing Phase 0 was undefined | Structured 3-question pre-flight check (scope, dependencies, risk flags) |
| Solo mode jumped straight to implementation | Step 1.5 background confirmation (purpose + impact scope inference) |
| Task dependencies were implicit in Japanese text | Explicit `Depends` column enables dependency-graph-based task assignment |

---

### Added
- **Plans.md v2 format**: 5-column table with DoD (Definition of Done) and Depends columns
- **DoD auto-inference**: `harness-plan create` generates testable completion criteria from task keywords
- **Depends auto-inference**: Automatic dependency detection (DB→API→UI→Test ordering)
- **`[needs-spike]` marker**: High Impact × High Risk tasks get auto-generated spike (tech validation) tasks
- **Plan Review Value axis**: 5th review axis checking user problem fit, alternatives, and Elephant detection
- **DoD/Depends quality checks**: Empty DoD warnings, untestable DoD suggestions, circular dependency detection
- **Retrospective (default ON)**: `sync` auto-runs retro when `cc:完了` tasks ≥ 1; `--no-retro` to skip
- **Breezing Phase 0 structured check**: 3-question pre-flight (scope confirmation, dependency validation, risk flags)
- **Solo Step 1.5**: 30-second background confirmation inferring task purpose and impact scope
- **Dependency-graph task assignment**: Breezing assigns Depends=`-` tasks first, chains dependents on completion

### Changed
- **harness-plan create Step 5**: Upgraded from 1-axis to Impact×Risk 2-axis priority matrix
- **harness-plan SKILL.md**: Plans.md format specification updated to v2 with DoD/Depends guide
- **harness-plan sync**: v1 (3-column) format support removed; Plans.md is always 5-column
- **harness-review Plan Review**: Expanded from 4-axis to 5-axis evaluation
- **harness-work Solo flow**: Added Step 1.5 between task identification and WIP marking
- **breezing Flow Summary**: Phase 0 now has concrete check items instead of undefined discussion

---

## [3.5.0] - 2026-03-07

### 🎯 What's Changed for You

**Claude Code v2.1.70–v2.1.71 features fully integrated: `/loop` scheduling for active monitoring, `PostToolUseFailure` auto-escalation, safe background agents, and Marketplace `@ref` installs.**

| Before | After |
|--------|-------|
| Feature Table covered up to v2.1.69 | Feature Table now covers v2.1.70–v2.1.71 (12 new items) |
| No automatic escalation on repeated tool failures | `PostToolUseFailure` hook escalates after 3 consecutive failures within 60s |
| Breezing relied solely on passive TeammateIdle monitoring | `/loop 5m /sync-status` enables active polling alongside passive hooks |
| Background agents risked losing output after compaction | v2.1.71 fix documented; `run_in_background` usage guide added |
| Plugin install used plain `owner/repo` | `owner/repo@vX.X.X` ref pinning recommended (v2.1.71 parser fix) |

---

### Added
- **`PostToolUseFailure` hook handler**: 60秒ウィンドウの連続失敗カウンターと 3 回失敗時の自動エスカレーションを追加
- **Feature Table v2.1.70–v2.1.71**: `docs/CLAUDE-feature-table.md` に 12 項目を追加
- **Breezing `/loop` guide**: `TeammateIdle` と `/loop` の役割分担を説明する active monitoring ガイドを追加
- **Breezing Background Agent guide**: v2.1.71 の出力パス修正を踏まえた `run_in_background` 運用ガイドを追加
- **Marketplace `@ref` install guidance**: `owner/repo@vX.X.X` を推奨するセットアップ手順を追加

### Changed
- **CLAUDE.md Feature Table**: `/loop`、`PostToolUseFailure`、Background Agent 出力修正、Compaction 画像保持を反映
- **Feature adoption notes**: Plugin hooks 修正、`--print` hang 修正、並列 plugin install 修正、`--resume` スキル再注入廃止を Feature Table に整理
- **README version badges**: `3.5.0` に同期
- **Compatibility doc**: plugin version を `3.5.0` に更新

### Fixed
- Windows checkout with `core.symlinks=false` no longer hides `harness-*` command skills before SessionStart runs

### Security
- **Symlink-safe failure counter writes**: `post-tool-failure.sh` は `.claude` 親ディレクトリ、`.claude/state`、`tool-failure-counter.txt` の symlink を検出した場合に state 書き込みをスキップ

---

## [3.4.2] - 2026-03-06

### 🎯 What's Changed for You

**README now explains Claude Harness as a steadier operating model, not just a feature list, and `/harness-work all` now ships with rerunnable success and failure evidence that matches the real exit status.**

| Before | After |
|--------|-------|
| README mixed feature descriptions, comparison copy, and duplicate visual explanations | README now leads with clearer "what changes after install" messaging and SVG-driven comparisons |
| `/harness-work all` evidence existed, but the full runner could misread a failing test exit code | success / failure evidence runners now record the real command status, so the artifact contract matches what actually happened |

### Changed
- **README refresh (EN/JA)**: Reworked the hero and comparison sections around the default operating path after install, added new SVG cards, and removed duplicated explanation blocks.
- **Competitive positioning docs**: Added a dated harness comparison matrix, compatibility notes, distribution scope, claims audit, positioning notes, and release checklist docs so public claims stay grounded.
- **Codex package surface**: Clarified `harness-*` workflow surfaces in Codex docs and aligned setup scripts with path-based skill loading.

### Added
- **`/harness-work all` evidence pack**: Added success / failure fixtures, smoke/full runners, replay-aware success artifacts, and public docs for rerunnable verification.
- **README visual assets**: Added `why-harness-pillars` and default-flow comparison SVGs in both English and Japanese.

### Fixed
- **Evidence runner exit status capture**: Full success / failure runners now preserve the real `claude` and `npm test` exit codes instead of the inverted `!` status.
- **Claim drift checks**: Expanded `check-consistency.sh` to catch README badge drift, missing docs, stale positioning claims, and distribution-scope mismatches before release.

---

## [3.4.1] - 2026-03-06

### 🎯 What's Changed for You

**Fixed stale skill labels in the Claude Code 2.1.69+ feature tables (EN/JA), so the docs now match the actual harness skill set.**

| Before | After |
|--------|-------|
| `task-worker`, `code-reviewer`, `work`, `all skills` labels remained in README feature tables | Unified to current names: `harness-work`, `harness-review`, `all harness-* skills` |

### Changed
- **README (EN/JA) feature table cleanup**: Updated the "Skills" column under "Claude Code 2.1.69+ Features" to current harness naming.

### Fixed
- **Documentation drift**: Removed legacy skill aliases that could mislead users during `/breezing` and `/harness-work` onboarding.

---

## [3.4.0] - 2026-03-06

### 🎯 What's Changed for You

**Claude Code v2.1.69 対応を完了。teammate event 制御、skill reference 解決、開発フロー文書を一気に更新し、チーム実行の停止判定と互換性を強化しました。**

| Before | After |
|--------|-------|
| Teammate hooks were session_id-centric and always approve-only | `agent_id`/`agent_type` を活用し、`{"continue": false, "stopReason": "..."}` で停止を返せる |
| `InstructionsLoaded` event was not handled | Dedicated handler added and wired in both hooks.json files |
| SKILL references used relative `references/` paths | `${CLAUDE_SKILL_DIR}/references/...` に統一し、実行環境依存を削減 |
| Docs were centered on 2.1.68+ | Feature docs/README/command docs updated to 2.1.69+ |

### Added
- **InstructionsLoaded handler**: `scripts/hook-handlers/instructions-loaded.sh` を新規追加
- **Teammate stop response support**: `teammate-idle.sh` / `task-completed.sh` に `continue:false` 応答ロジックを追加
- **2.1.69 feature docs**: `${CLAUDE_SKILL_DIR}`, `agent_id/agent_type`, `/reload-plugins`, `includeGitInstructions: false`, `git-subdir` 運用方針を明文化

### Changed
- **PreToolUse breezing role guard**: role lookup を `agent_id` 優先・`session_id` fallback に拡張
- **SKILL reference path policy**: skills/codex/opencode の SKILL.md で references 参照を `${CLAUDE_SKILL_DIR}` ベースへ更新
- **check-consistency**: project template の `defaultMode` baseline を検証し、未文書化の値を配布しない方針を明記
- **Feature docs**: CLAUDE.md / README / README_ja / docs/CLAUDE-feature-table.md / docs/CLAUDE-commands.md 更新

### Fixed
- **Plans drift**: Phase 17/19 の未同期タスクマーカーを現実状態へ同期
- **continue:false parsing**: boolean `false` が落ちるケースを修正し、stopReason を確実に反映

---

## [3.3.1] - 2026-03-05

### 🎯 What's Changed for You

**All README visuals unified to brand-orange palette, logo regenerated with Nano Banana Pro, and duplicate content sections removed for a cleaner reading experience.**

| Before | After |
|--------|-------|
| Mixed indigo/blue/teal/purple SVGs | Unified orange palette (#F7931A hierarchy) |
| Hero comparison shown twice (SVG + table) | Single SVG visualization |
| /work all flow shown twice (mermaid + SVG) | Single SVG visualization |
| Review section had no visual | 4-perspective review card SVG added |
| 47KB logo (old design) | 53KB Nano Banana Pro logo with "Plan → Work → Review" tagline |

### Changed
- **8 SVGs recolored** (EN/JA): Unified orange brand palette across all README visuals
- **Logo regenerated**: Nano Banana Pro interlocking-loops icon + "Plan → Work → Review" tagline
- **README cleanup**: Removed duplicate mermaid/SVG and SVG/table sections in both EN/JA

### Added
- **Review perspectives SVG** (EN/JA): 4-angle code review visualization (Security, Performance, Quality, Accessibility)
- **3 JA generated SVGs**: hero-comparison, core-loop, safety-guardrails (Japanese localized versions)
- **Alternative logo**: `docs/images/claude-harness-logo-alt.png` (carabiner icon + color-split text)

---

## [3.3.0] - 2026-03-05

### 🎯 What's Changed for You

**Claude Code v2.1.68 introduced effort levels, agent hooks, and more. Harness v3.3.0 puts all of them to work — so you get smarter task execution, LLM-powered code guards, and fully automated worktree lifecycle out of the box.**

> Claude Code got new superpowers. Harness makes sure you actually use them.

| What Claude Code added | How Harness uses it |
|------------------------|---------------------|
| **Opus 4.6 medium effort default** — Claude now thinks less deeply by default | Harness auto-detects complex tasks (security, architecture, multi-file changes) and injects `ultrathink` to restore full thinking depth exactly when it matters |
| **Agent hooks (`type: "agent"`)** — hooks can now use LLM intelligence | 3 smart guards deployed: catches hardcoded secrets before commit, blocks session exit with unfinished tasks, runs lightweight code review after every write |
| **WorktreeCreate/Remove hooks** — lifecycle events for git worktrees | Breezing parallel workers now auto-initialize their workspace and clean up temp files when done. No more orphaned `/tmp` clutter |
| **`CLAUDE_ENV_FILE`** — session environment persistence | Harness version, effort defaults, and Breezing session IDs persist across hooks. Workers know who they are |
| **Prompt hooks expanded to all events** — no longer Stop-only | Every hook event can now use LLM judgment (was incorrectly documented as Stop-only) |

### Added
- **Effort level auto-tuning**: Multi-element scoring system (file count + directory criticality + task keywords + past failure history). Score ≥ 3 triggers `ultrathink` — meaning complex tasks get deep thinking, simple tasks stay fast
- **Agent hooks (3 deployments)**:
  - *PreToolUse quality guard*: LLM reviews every Write/Edit for secrets, TODO stubs, and security issues before they land
  - *Stop WIP guard*: Reads Plans.md and warns you if you're about to close a session with unfinished `cc:WIP` tasks
  - *PostToolUse code review*: Lightweight haiku-powered review runs after every file write
- **Worktree lifecycle automation**: `worktree-create.sh` sets up `.claude/state/worktree-info.json` with worker identity; `worktree-remove.sh` cleans Codex temp files and logs
- **Session environment persistence**: `session-env-setup.sh` writes `HARNESS_VERSION`, `HARNESS_EFFORT_DEFAULT=medium`, and `HARNESS_BREEZING_SESSION_ID` to `CLAUDE_ENV_FILE`
- **PreCompact agent hook**: Catches WIP tasks before context compaction — so important context isn't lost mid-task
- **HTTP hook template**: Ready-to-use PostToolUse metrics hook for external dashboards (localhost:9090)

### Changed
- **4-type hook system**: Harness now supports all 4 hook types — `command`, `prompt` (all events), `http`, and `agent`
- **Feature Table**: Updated from v2.1.63+ to v2.1.68+ with 30 tracked features
- **Worker/Reviewer/Team agents**: Now understand effort levels and when to request deeper thinking
- **PM templates**: All handoff templates include `ultrathink` with clear intent comments

### Fixed
- **Prompt hook documentation**: Removed incorrect "Stop/SubagentStop only" restriction (prompt hooks work on all events since v2.1.63)
- **Dead reference cleanup**: Removed link to deleted `guardrails-inheritance.md` in Feature Table

---

## [3.2.0] - 2026-03-04

### 🎯 What's Changed for You

**TDD is now enabled by default for all tasks, and Windows users get automatic symlink repair on session start.**

| Before | After |
|--------|-------|
| TDD only active with `[feature:tdd]` marker (opt-in) | TDD active by default; skip with `[skip:tdd]` (opt-out) |
| Windows users: v3 skills not recognized (broken symlinks) | Auto-detected and repaired on session start |
| Worker had no TDD phase in execution flow | TDD phase (Red→Green) integrated into Worker and Solo mode |

### Added
- **TDD-by-default**: TDD is now opt-out (`[skip:tdd]`) instead of opt-in (`[feature:tdd]`). All WIP tasks get TDD reminders unless explicitly skipped
- **`--no-tdd` option**: Skip TDD phase in `/harness-work` execution
- **Windows symlink auto-repair**: `fix-symlinks.sh` detects broken symlinks from Windows git clone and replaces them with directory copies
- **Session-init Step 1.5**: Symlink health check runs automatically before skill discovery

### Changed
- **tdd-order-check.sh**: `has_tdd_wip_task()` split into `has_active_wip_task()` + `is_tdd_skipped()` for clearer logic
- **harness-plan create.md**: Step 5.5 inverted from "TDD adoption criteria" to "TDD skip criteria"
- **worker.md**: Execution flow expanded from 10 to 12 steps with TDD judgment and Red phase
- **harness-work SKILL.md**: Solo mode expanded from 6 to 7 steps with TDD phase

---

## [3.1.0] - 2026-03-03

### 🎯 What's Changed for You

**Codex CLI 0.107.0 full compatibility, 15 deprecated skill stubs removed (−40,000 lines), and `/harness-work` now auto-selects the best execution mode based on task count.**

| Before | After |
|--------|-------|
| 15 deprecated redirect stubs cluttering skill listings | Clean 5-verb structure only |
| `/harness-work` always defaulted to Solo mode | Auto-detection: 1→Solo, 2-3→Parallel, 4+→Breezing |
| `--codex` could be confusing for users without Codex CLI | `--codex` is explicit-only, never auto-selected |
| MCP server references in Codex config | All MCP remnants removed, pure CLI integration |
| `--approval-policy` (non-official flag) in docs | Correct `-a never -s workspace-write` flags |

### Added
- **Auto Mode Detection**: `/harness-work` auto-selects Solo/Parallel/Breezing based on task count (1/2-3/4+)
- **Breezing backward-compatible alias**: `/breezing` delegates to `/harness-work --breezing`
- **Codex 環境フォールバック**: harness-review に Task ツール非対応時の Plans.md 直接操作パターン追加
- **Codex 環境注記**: team-composition.md, worker.md に Codex CLI 固有の制約と代替手段を記載
- **config.toml 拡充**: [notify] セクション（after_agent メモリブリッジ）、reviewer Read-only sandbox
- **.codexignore**: CLAUDE.md ノイズ化防止パターン追加
- **README visual improvement**: hero-comparison, core-loop, safety-guardrails images

### Changed
- **MCP 残骸除去**: config.toml, setup-codex.sh, codex-setup-local.sh から MCP サーバー参照を完全削除
- **codex exec フラグ正規化**: --approval-policy → -a (--ask-for-approval)、--sandbox → -s に統一
- **プロンプト渡し方式改善**: "$(cat file)" → stdin パイプ (`cat file | codex exec -`) に変更（ARG_MAX 対策）
- **codex-worker-engine.sh**: mcp-params.json → codex-exec-params.json にリネーム

### Fixed
- **/tmp/codex-prompt.md 固定パス**: mktemp 一意パスに変更（並列実行時の競合防止）
- **2>/dev/null エラー握りつぶし**: ログファイルリダイレクトに変更（デバッグ可能に）
- **Skill description quality**: gogcli-ops YAML fix, session-memory invalid tool removal, session-state non-standard fields cleanup

### Removed
- **15 DEPRECATED redirect stubs**: breezing(old), codex-review, handoff, harness-init, harness-update, impl, maintenance, parallel-workflows, planning, plans-management, release-har, setup, sync-status, troubleshoot, verify, work — all consolidated into 5-verb skills
- **Old -harness suffix stubs**: plan-harness, release-harness, review-harness, setup-harness, work-harness from skills-v3/
- **x-release-harness**: consolidated into harness-release

---

## [3.0.0] - 2026-03-02

### 🎯 What's Changed for You

**Harness v3: Full architectural rewrite — 42 skills unified to 5 verbs, 11 agents consolidated to 3, TypeScript engine replaces Bash guardrails, SQLite replaces scattered JSON state files.**

| Before | After |
|--------|-------|
| 42 skills spread across multiple dirs | 5 verb skills: `plan` / `execute` / `review` / `release` / `setup` |
| 11 agents with overlapping responsibilities | 3 agents: `worker` / `reviewer` / `scaffolder` |
| Bash scripts for guardrails (pretooluse-guard.sh etc.) | TypeScript engine in `core/` (strict, ESM, NodeNext) |
| JSON/JSONL state files scattered across dirs | SQLite single-file state via `better-sqlite3` |
| rsync-based mirror sync for codex/opencode | Symlink-based mirror (zero sync overhead) |
| No session lifecycle management | `core/engine/lifecycle.ts` unifies session-init/control/state/memory |

### Added

- **`core/` TypeScript engine**: Strict ESM module (`exactOptionalPropertyTypes`, `noUncheckedIndexedAccess`, `NodeNext`). Includes guardrails, state, and engine subsystems
- **`core/src/guardrails/`**: Rules engine (R01-R09), pre-tool/post-tool/permission/tampering detection — all ported from Bash to TypeScript
- **`core/src/state/`**: SQLite state management via `better-sqlite3` with schema, store, and JSON→SQLite migration
- **`core/src/engine/lifecycle.ts`**: Session lifecycle — `initSession`, `transitionSession`, `finalizeSession`, `forkSession`, `resumeSession`
- **`skills-v3/`**: 5 verb skills with unified SKILL.md + references/
- **`agents-v3/`**: 3 consolidated agent definitions + team-composition.md
- **`tests/validate-plugin-v3.sh`**: v3 structural validator (6 checks, 34 assertions)
- **Symlink mirrors**: `codex/.codex/skills/` and `opencode/skills/` 5-verb dirs now symlinks to `skills-v3/`
- **`skills-v3/routing-rules.md`**: Trigger/exclusion keywords per skill verb

### Changed

- **Skills**: 42 → 5 (plan/execute/review/release/setup). Legacy `skills/` retained for backwards compatibility
- **Agents**: 11 → 3 (worker/reviewer/scaffolder). Legacy `agents/` retained for backwards compatibility
- **Hooks shims**: `hooks/pre-tool.sh`, `hooks/post-tool.sh`, `hooks/permission.sh` now delegate to `core/src/index.ts`
- **PermissionRequest**: Switched from v2 `run-script.js permission-request` to v3 TypeScript core (`hooks/permission.sh`)
- **`check-consistency.sh`**: Mirror check updated from rsync diff to symlink validation
- **CLAUDE.md**: Compact v3 version; architecture details moved to `.claude/rules/v3-architecture.md`
- **README.md / README_ja.md**: Updated for v3 (5 verb skills, 3 agents, TypeScript core, architecture diagram)

### Fixed

- **`core/src/state/store.ts`**: Fixed `better-sqlite3` type import — `typeof import("better-sqlite3").default` → `import type DatabaseConstructor from "better-sqlite3"` (ESM/CJS compatibility)
- **Duplicate `posttooluse-tampering-detector`**: Removed v2 script from PostToolUse `Write|Edit|Task` block (v3 `post-tool.ts` already handles tampering detection)

### Removed

- rsync-based mirror sync (replaced by symlinks)
- Standalone Bash guardrail scripts (replaced by `core/src/guardrails/`)
- Scattered JSON/JSONL state files (replaced by SQLite)
- Duplicate `posttooluse-tampering-detector` hook (consolidated into v3 post-tool engine)

---

## [2.26.1] - 2026-03-02

### Added

- **12 section-specific SVG illustrations**: 6 EN + 6 JA hand-crafted visuals embedded in both READMEs (before-after, /work all flow, parallel workers, safety shield, skills ecosystem, breezing agents)

### Fixed

- **review-loop.md APPROVE flow inconsistency**: Phase 3.5 Auto-Refinement step was missing from the APPROVE judgment table, causing inconsistency with SKILL.md and execution-flow.md

## [2.26.0] - 2026-03-02

### 🎯 What's Changed for You

**Claude Code v2.1.63 integration: `/work` now auto-simplifies code after review, `/breezing` can delegate horizontal tasks to `/batch`, and HTTP hooks enable external service notifications.**

| Before | After |
|--------|-------|
| `/work` flow: implement → review → commit | `/work` flow: implement → review → **auto-simplify** → commit |
| Horizontal migration tasks handled manually | `/breezing` auto-detects and delegates to `/batch` |
| Feature table covers up to v2.1.51 | Feature table covers up to v2.1.63 (27 features) |
| Hooks only support `command` and `prompt` types | Hooks now support `http` type (POST to external services) |

### Added

- **Phase 3.5 Auto-Refinement in `/work`**: After review APPROVE, `/simplify` runs automatically to clean up code. `--deep-simplify` adds `code-simplifier` plugin. `--no-simplify` skips
- **`/batch` delegation in `/breezing`**: Horizontal pattern detection (migrate/replace-all/add-to-all) auto-proposes `/batch` delegation for bulk changes
- **HTTP hooks documentation** (`.claude/rules/hooks-editing.md`): `type: "http"` spec with field reference, response behavior, command-vs-http comparison table, and 3 sample templates (Slack, metrics, dashboard)
- **7 new feature-table entries** (`docs/CLAUDE-feature-table.md`): `/simplify`, `/batch`, `code-simplifier` plugin, HTTP hooks, auto-memory worktree sharing, `/clear` skill cache reset, `ENABLE_CLAUDEAI_MCP_SERVERS`

### Changed

- **Version references**: `2.1.49+` → `2.1.63+` across CLAUDE.md and feature table
- **Feature count**: 20 → 27 in CLAUDE.md and feature table
- **`/breezing` guardrails**: Added auto-memory worktree sharing (v2.1.63) to inheritance table
- **`troubleshoot` skill**: Added `/clear` cache reset to CC v2.1.63+ diagnostics
- **`work-active.json` schema**: Added `simplify_mode: "default" | "deep" | "skip"` field

## [2.25.0] - 2026-02-24

### 🎯 What's Changed for You

**`CLAUDE_CODE_SIMPLE` モード（CC v2.1.50+）の影響を自動検出し、無効化される機能をユーザーに明示。サイレント障害を防止。**

| Before | After |
|--------|-------|
| SIMPLE モードで 37 スキル・11 エージェントがサイレントに無効化 | SessionStart/Setup フックが自動検出し、ターミナル + additionalContext で警告表示 |
| SIMPLE モードの影響範囲が不明（互換性マトリクスに 1 行のみ） | 専用ドキュメント `docs/SIMPLE_MODE_COMPATIBILITY.md` で全影響を網羅（スキル・エージェント・メモリ・ワークフロー） |
| 防御コード・検出ロジックがゼロ | `scripts/check-simple-mode.sh` ユーティリティで一貫した検出・多言語警告メッセージ |
| `/work`, `/breezing` 等が理由不明で動作しない | 「スキル無効」「エージェント無効」「フックのみ動作」の 3 分類で即座に状況把握可能 |

### Added

- **SIMPLE モード検出ユーティリティ** (`scripts/check-simple-mode.sh`): `is_simple_mode()` 関数と `simple_mode_warning()` 多言語メッセージ生成。全フック・スクリプトから source して使用可能
- **SessionStart SIMPLE モード警告**: `scripts/session-init.sh` がセッション開始時に `CLAUDE_CODE_SIMPLE` 環境変数を検出し、stderr バナー + additionalContext で詳細警告を出力
- **Setup hook SIMPLE モード警告**: `scripts/setup-hook.sh` が init/maintenance 時に SIMPLE モードを検出し、出力メッセージに警告を追加
- **`docs/SIMPLE_MODE_COMPATIBILITY.md`**: SIMPLE モード完全ガイド — 影響サマリ表、動作/非動作の全リスト、37 スキル・11 エージェントの影響度分類、検出方法、ワークアラウンド、開発者向け拡張ガイド

### Changed

- **互換性マトリクス強化** (`docs/CLAUDE_CODE_COMPATIBILITY.md`):
  - v2.1.50 SIMPLE モード行のステータスを「要注意」→「**対応済み**」に更新
  - 非互換セクションに SIMPLE モードの詳細影響（37 スキル・11 エージェント・メモリ無効化）と検出方法を追記
  - `SIMPLE_MODE_COMPATIBILITY.md` へのクロスリファレンスリンク追加

---

## [2.24.0] - 2026-02-24

### 🎯 What's Changed for You

**Claude Code v2.1.50〜v2.1.51 の新機能に対応。互換性マトリクス更新、メモリ安定性改善の恩恵、新 CLI コマンド活用。**

| Before | After |
|--------|-------|
| 互換性マトリクスが v2.1.49 で止まっていた | v2.1.50〜v2.1.51 の全機能を文書化、推奨バージョンを v2.1.51+ に引き上げ |
| WorktreeCreate/Remove hook が未知 | Breezing guardrails に将来対応として文書化 |
| エージェント spawn 失敗時の診断手段が限定的 | `claude agents list` (CC 2.1.50+) を troubleshoot スキルに追加 |
| バックグラウンドエージェント停止方法が未記載 | `Ctrl+F`（CC 2.1.49+）を breezing guardrails に追記、ESC 非推奨を明記 |

### Added

- **CC v2.1.50/v2.1.51 互換性マトリクス**: `docs/CLAUDE_CODE_COMPATIBILITY.md` に 17 項目追加（メモリリーク修正、完了タスク GC、WorktreeCreate/Remove hook、`claude agents` CLI、宣言的 worktree isolation、SIMPLE モード注意、remote-control 等）
- **`claude agents` CLI 診断**: `skills/troubleshoot/SKILL.md` にエージェント診断セクション追加（CC 2.1.50+）
- **WorktreeCreate/WorktreeRemove hook**: `skills/breezing/references/guardrails-inheritance.md` に将来対応として追記
- **Ctrl+F キーバインド**: breezing guardrails にバックグラウンドエージェント停止方法を追記（CC 2.1.49+、ESC 非推奨）
- **Feature Table 拡張**: `docs/CLAUDE-feature-table.md` に v2.1.50/v2.1.51 の 4 機能追加（メモリリーク修正、claude agents CLI、WorktreeCreate/Remove、remote-control）

### Changed

- **推奨 CC バージョン**: v2.1.49+ → **v2.1.51+** に引き上げ
- **Feature Table タイトル**: 2.1.49+ → 2.1.51+ に更新

---

## [2.23.6] - 2026-02-24

### Added

- **Auto-release workflow** (`release.yml`): Safety-net GitHub Release creation on `v*` tag push — prevents orphan tags if `release-har` is interrupted
- **CHANGELOG format validation in CI**: ISO 8601 date format, `[Unreleased]` section presence, non-standard heading warnings
- **Codex mirror sync check in CI**: `codex/.codex/skills/` ↔ `skills/` consistency validated in both `check-consistency.sh` and `opencode-compat.yml`
- **Branch Policy in release-har**: Explicitly documents that main direct push is allowed for solo projects (force push remains prohibited)

### Changed

- **CHANGELOG link definitions repaired**: All version compare links supplemented
- **CHANGELOG_ja.md translation gaps filled**: 5 versions added (2.20.1, 2.17.6, 2.17.1, 2.17.0, 2.16.21)
- **README version and count updated**: Badge version, skill count (41), agent count (11) updated to reflect reality
- **CHANGELOG non-standard headings normalized**: `### Internal` → `### Changed` (Keep a Changelog compliant)
- **Mirror compat workflow renamed**: `OpenCode Compatibility Check` → `Mirror Compatibility Check` (now covers both opencode and codex mirrors)
- **AGENTS.md template updated**: Removed `main` direct push prohibition for solo projects; force push remains prohibited
- **Tamper detection expanded** (`codex-worker-quality-gate.sh`): Python skip patterns, catch-all assertions, config relaxation detection

---

## [2.23.5] - 2026-02-23

### 🎯 What's Changed for You

**Phase 13: Breezing quality automation and Codex rule injection — tamper detection, auto-test runner, CI signal handling, AGENTS.md rule sync, and APPROVE fast-path.**

| Before | After |
|--------|-------|
| Test tampering detection covered skip patterns and assertion deletion only | 12+ patterns: weakening (`toBe → toBeTruthy`), timeout inflation, catch-all assertions, Python skip decorators |
| Auto-test runner only recommended tests without running them | `HARNESS_AUTO_TEST=run` actually runs tests and feeds results back via `additionalContext` |
| CI failures required manual detection | PostToolUse hook detects CI failures after `git push` and injects `ci-cd-fixer` recommendation signals |
| `.claude/rules/` existed only for Claude Code; Codex had no rule awareness | `sync-rules-to-agents.sh` auto-syncs rules to `codex/AGENTS.md`; Codex reads full project rules on startup |
| `codex exec` called bare without pre/post processing | `codex-exec-wrapper.sh` handles rule sync, `[HARNESS-LEARNING]` extraction, and secret filtering |
| Breezing Phase C required manual APPROVE confirmation | `review-result.json` + commit hash check enables instant fast-path to integration tests |
| Implementer count fixed at `min(独立タスク数, 3)` | Auto-calculated as `max(1, min(独立タスク数, --parallel, planner_max_parallel, 5))` |

### Added

- **Tamper detection (12+ patterns)**: assertion weakening, timeout inflation, catch-all assertions, Python skip decorators — `scripts/posttooluse-tampering-detector.sh`
- **`HARNESS_AUTO_TEST=run` mode**: `scripts/auto-test-runner.sh` actually runs tests and returns pass/fail via `additionalContext` JSON
- **CI signal injection**: `scripts/hook-handlers/ci-status-checker.sh` detects CI failures post-push and writes to `breezing-signals.jsonl`; `scripts/hook-handlers/breezing-signal-injector.sh` injects unconsumed signals via UserPromptSubmit hook
- **`sync-rules-to-agents.sh`**: Auto-converts `.claude/rules/*.md` to `codex/AGENTS.md` Rules section with hash-based drift detection
- **`codex-exec-wrapper.sh`**: Pre/post wrapper for `codex exec` — rule sync, `[HARNESS-LEARNING]` marker extraction, secret filtering, atomic write-back to `codex-learnings.md`
- **APPROVE fast-path (Phase C)**: Checks `.claude/state/review-result.json` + HEAD commit hash; skips manual confirmation when APPROVE is already recorded
- **`review-result.json` auto-record**: Reviewer reports `review_result_json` in SendMessage; Lead writes `.claude/state/review-result.json` for fast-path reference
- **Docs reorganization**: `docs/CLAUDE-feature-table.md`, `docs/CLAUDE-skill-catalog.md`, `docs/CLAUDE-commands.md` — detailed references extracted from CLAUDE.md
- **`harness.rules` — execpolicy guard rules**: `npm test`/`yarn test`/`pnpm test` auto-allowed; `git push --force`, `git reset --hard`, `rm -rf`, `git clean -f`, SQL destructive statements (`DROP TABLE`, `DELETE FROM`) require user confirmation via `codex execpolicy`; 20 patterns verified with `codex execpolicy check`

### Changed

- **CLAUDE.md compressed to 120 lines**: Feature Table (5 items), skill category table (5 categories); full details moved to `docs/`
- **Implementer count auto-determination**: `max(1, min(独立タスク数, --parallel N, planner_max_parallel, 5))` — starvation prevention + hard cap at 5
- **`review-retake-loop.md`**: Added `review-result.json` write spec with JSON format, Reviewer→Lead delegation flow, and file lifecycle
- **`execution-flow.md` Phase C**: APPROVE fast-path check added as step 2; phase processing renumbered
- **`team-composition.md`**: Extended configuration (5 Implementers) cost estimate table added
- **`release-har` skill redesigned (Phase 14)**: Full redesign with Pre-flight checks, structured git log, Conventional Commits classification, Claude diff summarization (Highlights + Before/After), SemVer auto-detection, dry-run preview, 4-section Release Notes, Compare link auto-generation, `--announce` option, and `--dry-run` default gate; `references/release-notes-template.md` and `references/changelog-format.md` added

---

## [2.23.3] - 2026-02-22

### 🎯 What's Changed for You

**Codex integration is now explicitly CLI-first (`codex exec`) outside breezing, and Codex package parity includes the new `generate-slide` skill.**

| Before | After |
|--------|-------|
| `work`/`harness-review`/`codex-review` docs mixed Codex MCP wording with CLI execution examples | Non-breezing Codex flows are documented as CLI-only (`codex exec`) with consistent setup and troubleshooting |
| `codex-worker-setup.sh` checked MCP registration state | Setup now checks `codex exec` readiness directly (`codex_exec_ready`) |
| Codex package parity test did not block non-breezing MCP vocabulary regressions | New CLI-only regression checks added to `tests/test-codex-package.sh` |
| `generate-slide` existed in source/opencode but not in Codex package | `codex/.codex/skills/generate-slide/` is now included and parity tests pass |

### Added

- **Codex package skill parity**: Added `generate-slide` skill files to `codex/.codex/skills/`
- **CLI-only regression guard**: Added non-breezing Codex vocabulary checks to `tests/test-codex-package.sh`
- **README updates (EN/JA)**: Added `/generate-slide` command docs and slide-generation feature section

### Changed

- **Codex docs (non-breezing)**: Updated `work`, `harness-review`, `codex-review`, routing/setup references to CLI-first terminology and behavior (`codex exec`)
- **Codex setup reference**: Reworked `codex-mcp-setup.md` content into Codex CLI setup flow (legacy filename retained for compatibility)
- **README Codex review section (EN/JA)**: Clarified Codex second-opinion execution path as Codex CLI-based

### Fixed

- **Setup behavior mismatch**: Replaced MCP registration check in `scripts/codex-worker-setup.sh` with actual CLI execution readiness check
- **Codex mirror consistency**: Synced updated non-breezing Codex skill docs between `skills/` and `codex/.codex/skills/`

---

## [2.23.2] - 2026-02-22

### 🎯 What's Changed for You

**Codex skills now use fully native multi-agent vocabulary — CI checks pass, and `--claude` review routing is explicitly documented.**

| Before | After |
|--------|-------|
| Codex breezing/work skills contained Claude Code-specific terms (`delegate mode`, `TaskCreate`, `subagent_type`, etc.) | All 82+ occurrences replaced with Codex native API equivalents (`Phase B`, `spawn_agent`, `role`, etc.) |
| No `review_engine` matrix in Codex breezing/work SKILL.md | `review_engine` comparison table added with `codex` / `claude` columns |
| `--claude + --codex-review` conflict undocumented | Explicit conflict rule: mutually exclusive, fails before execution |
| State files referenced `.claude/state/` paths | State files use `${CODEX_HOME:-~/.codex}/state/harness/` paths |
| `opencode/` contained stale breezing files | Rebuilt `opencode/` — breezing removed (dev-only skill) |

### Fixed

- **Codex vocabulary migration**: replaced 82+ legacy Claude Code terms across 13 files in `codex/.codex/skills/breezing/` and `codex/.codex/skills/work/` — `delegate mode` → `Phase B`, `TaskCreate` → `spawn_agent`, `subagent_type` → `role:`/`spawn_agent()`, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` → `config.toml [features] multi_agent`, `.claude/state/` → `${CODEX_HOME}/state/harness/`
- **`--claude` review routing**: added `review_engine` matrix table and `--claude + --codex-review` conflict rule to both `breezing/SKILL.md` and `work/SKILL.md`
- **OpenCode sync**: rebuilt `opencode/` to remove stale breezing files and routing-rules.md

---

## [2.23.1] - 2026-02-22

### 🎯 What's Changed for You

**Codex CLI setup now merges files instead of overwriting, and README setup instructions are clearer with a collapsible quick-start.**

| Before | After |
|--------|-------|
| `setup-codex.sh` overwrote all destination files on every sync | Merge strategy: new files added, existing files updated, user-created files preserved |
| Codex CLI Setup was a top-level README section | Moved to collapsible `<details>` block with step-by-step quick-start |
| `config.toml` had 4 agent definitions | 9 agents: added `task_worker`, `code_reviewer`, `codex_implementer`, `plan_analyst`, `plan_critic` |

### Changed

- **README (EN/JA)**: Codex CLI Setup section moved from top-level to collapsible `<details>` block with prerequisites, 3-step quick-start, and flag reference table
- **`setup-codex.sh`**: `sync_named_children()` rewritten with 3-way merge strategy — new files are copied, existing files are backed up and updated, destination-only files are preserved; log output now shows `(N new, N updated, N preserved, N skipped)`
- **`codex-setup-local.sh`**: same merge strategy applied to project-local setup script

### Added

- **`merge_dir_recursive()`** helper in both setup scripts for recursive directory merging with backup
- **5 new Codex agent definitions** in `setup-codex.sh` `config.toml` generation: `task_worker`, `code_reviewer`, `codex_implementer`, `plan_analyst`, `plan_critic` (Breezing roles)
- Idempotent agent injection: existing `config.toml` files receive missing agent entries without duplicating existing ones

---

## [2.23.0] - 2026-02-21

### 🎯 What's Changed for You

**Codex breezing now has its own Phase 0 (Planning Discussion) using Codex's native multi-agent API — Planner and Critic agents analyze your plan before implementation begins.**

| Before | After |
|--------|-------|
| Codex breezing Phase 0 was dead code (referenced Claude-only APIs) | Phase 0 uses `spawn_agent`/`send_input`/`wait`/`close_agent` natively |
| `config.toml` had 4 agent definitions | 9 agents defined including `plan_analyst`, `plan_critic`, `task_worker`, `code_reviewer`, `codex_implementer` |
| All breezing reference files were identical between Claude and Codex | 3 files now intentionally diverge with platform-native implementations |

### Added

- **Codex Phase 0 (Planning Discussion)**: ported from Claude Agent Teams to Codex native multi-agent API (`spawn_agent`/`send_input`/`wait`/`close_agent`)
- **5 new Codex agent definitions** in `config.toml`: `plan_analyst`, `plan_critic`, `task_worker`, `code_reviewer`, `codex_implementer`
- **Mirror sync divergence management** (D24, P20): 3 breezing files (`planning-discussion.md`, `execution-flow.md`, `team-composition.md`) now excluded from rsync to preserve Codex-native implementations

### Changed

- **Codex `planning-discussion.md`**: fully rewritten with Codex native API — Planner ↔ Critic dialogue via Lead relay pattern using `send_input` + `wait` loops
- **Codex `execution-flow.md`**: Phase 0 + Phase A spawn logic updated to `spawn_agent()` format; environment check now references `config.toml [features] multi_agent = true`
- **Codex `team-composition.md`**: all role definitions updated — `subagent_type` removed, `spawn_agent()` format, `SendMessage` → `send_input()`, `shutdown_request` → `close_agent()`

---

## [2.22.0] - 2026-02-21

### 🎯 What's Changed for You

**Security guardrails now apply automatically from the moment you install Harness — no `/harness-init` required. Permission policy hardened with least-privilege defaults and privacy-safe session logging.**

| Before | After |
|--------|-------|
| Security settings (deny/ask rules) required running `/harness-init` | Plugin settings applied automatically on install (CC 2.1.49+) |
| Plugin settings had a broad `allow` rule; no DB CLI protection | Least-privilege: removed blanket `allow`; added deny for `psql`/`mysql`/`mongo` |
| `stop-session-evaluator.sh` always returned `{"ok":true}` without reading input | Hook reads `last_assistant_message`, stores length+hash only (privacy-safe) with atomic writes |
| No hook for configuration file changes | New `ConfigChange` hook records config changes to breezing timeline when active |
| `npm install` / `bun install` ran without confirmation | Package manager installs now require user confirmation (`ask` rule) |

### Added

- **Plugin settings.json** (`.claude-plugin/settings.json`): default security permissions distributed with the plugin — active from install (CC 2.1.49+)
  - **Deny**: `.env`, secrets, SSH keys (`id_rsa`, `id_ed25519`), `.aws/`, `.ssh/`, `.npmrc`, `sudo`, `rm -rf/-fr`, DB CLIs (`psql`, `mysql`, `mongo`)
  - **Ask**: destructive git (`push --force`, `reset --hard`, `clean -f`, `rebase`, `merge`), package installs (`npm/bun/pnpm install`), `npx`/`npm exec`
- **`ConfigChange` hook** (`scripts/hook-handlers/config-change.sh`): records configuration file changes to `breezing-timeline.jsonl` when breezing is active; always non-blocking
  - Normalizes `file_path` to repo-relative paths in timeline logs
  - Portable timeout detection (`timeout`/`gtimeout`/`dd` fallback)
- **`last_assistant_message` support** in `stop-session-evaluator.sh`: reads CC 2.1.47+ Stop payload
  - Stores message length + SHA-256 hash only (no plaintext — privacy by design)
  - Atomic writes via `mktemp` (TOCTOU fix)
  - Portable hash detection (`shasum`/`sha256sum`)
- **CC 2.1.49 compatibility matrix** (`docs/CLAUDE_CODE_COMPATIBILITY.md`): added v2.1.43-v2.1.49 entries covering Plugin settings.json, Worktree isolation, Background agents, ConfigChange hook, Sonnet 4.6, WASM memory fix

### Changed

- **Breezing: Worktree isolation support** (CC 2.1.49+): documented `isolation: "worktree"` in `guardrails-inheritance.md` — parallel Implementers can now work on the same files without conflicts via git worktree isolation
- **Breezing: Agent model field fix** (CC 2.1.47+): documented model field behavior change in guardrails for correct agent spawning
- **Breezing: Background agents** (`background: true`): `video-scene-generator` agent now supports non-blocking background execution
- **Breezing: opencode mirror full sync**: all 10 breezing reference files (execution-flow, team-composition, review-retake-loop, session-resilience, planning-discussion, plans-to-tasklist, codex-engine, codex-review-integration, guardrails-inheritance, SKILL.md) synced to `opencode/skills/breezing/` for the first time
- **Breezing: Codex mirror updates**: all breezing reference files in `codex/.codex/skills/breezing/` updated to latest
- **Work skill**: major Codex mirror updates for auto-commit, auto-iteration, codex-engine, error-handling, execution-flow, parallel-execution, review-loop, scope-dialog, session-management
- **`quick-install.sh`**: added note that default security permissions apply automatically — no manual configuration needed
- **`claude-settings.md` skill**: added note that CC 2.1.49+ auto-applies plugin settings; manual `settings.json` generation only needed for project-specific additions
- **`settings.security.json.template`**: updated `_harness_version` and added `_harness_note` clarifying role separation from plugin settings; unified `rm -rf/-fr` deny variants
- **Version references**: updated from CC 2.1.38 to 2.1.49 across 16+ skill and agent files

### Security

- **Least-privilege enforcement**: removed overly broad `allow` from plugin settings.json; all permissions now explicit deny or ask
- **DB CLI deny rules**: `psql`, `mysql`, `mongod`, `mongo` blocked by default to prevent accidental data operations
- **Secret path expansion**: added `id_ed25519`, recursive `.ssh/`, `.aws/`, `.npmrc` to deny patterns
- **Privacy-safe session logging**: `last_assistant_message` stored as length+hash, not plaintext
- **Atomic file writes**: `session.json` updates use `mktemp` + `mv` to prevent TOCTOU race conditions
- All 3 Codex experts (Security/Quality/Architect) scored A on hardening review

---

## [2.21.0] - 2026-02-20

### 🎯 What's Changed for You

**Breezing now reviews your plan before coding starts. Phase 0 (Planning Discussion) runs by default—skip with `--no-discuss`.**

| Before | After |
|--------|-------|
| `/breezing` jumps straight into coding | Plan reviewed by Planner + Critic before implementation |
| No task validation before execution | V1–V5 checks (scope, ambiguity, overlap, deps, TDD) |
| All tasks registered at once | 8+ tasks auto-split into progressive batches |
| Implementers communicate only via Lead | Implementers can message each other directly |

### Added

- **Breezing Planning Discussion (Phase 0)**: pre-execution plan review with Planner + Critic teammates (default-on, skip with `--no-discuss`)
- **Task granularity validation (V1–V5)**: validates task scope, ambiguity, owns overlap, dependency consistency, and TDD markers before TaskCreate
- **Progressive Batch strategy**: automatic batch splitting for 8+ tasks with 60% completion triggers
- **Implementer peer communication (Pattern D)**: direct Implementer-to-Implementer knowledge sharing via SendMessage
- **Hook-driven signals**: `task-completed.sh` now generates `partial_review_recommended` and `next_batch_recommended` signals
- **Spec Driven Development integration**: `[feature:tdd]` markers in Plans.md trigger test-first task generation
- **New agents**: `plan-analyst` (task analysis) and `plan-critic` (Red Teaming review) for Phase 0

### Fixed

- **Signal threshold comparison**: Changed `-eq` to `-ge` in `task-completed.sh` to handle simultaneous task completions that skip exact threshold
- **Signal deduplication**: Added existing signal check before emitting to prevent duplicate signals
- **Signal generation fallback**: Added `python3` fallback for signal JSON generation when `jq` is unavailable
- **Completion counting**: Fixed `grep -c` overcounting in batch scope (now counts each task_id once regardless of retakes)
- **Document consistency**: Resolved contradictions between execution-flow.md, team-composition.md, and planning-discussion.md regarding round counts and V1-V4 skip policy
- **Signal session scoping**: Signals now include `session_id` and dedup is session-scoped, preventing prior sessions from suppressing signals
- **grep pattern safety**: Changed `grep -q` to `grep -Fq` (fixed-string match) for task_id lookups, preventing regex meta-character injection
- **stdin piping safety**: Changed `echo` to `printf '%s'` for JSON piping to jq/python3, preventing edge-case mangling
- **DRY signal construction**: Extracted `_build_signal_json` helper to eliminate jq/python3 fallback duplication in signal paths
- **Phase 0 handoff persistence**: Added `handoff` payload to breezing-active.json for Compaction resilience between Phase 0 and Phase A
- **Resume stale-ID reconciliation**: Added rules for mapping old task IDs to new IDs during session resume, with completion evaluation against active ID set

---

## [2.20.13] - 2026-02-19

### What's Changed

**Codex execution is now documented and validated as native multi-agent first, with `--claude` forcing both implementation and review delegation to Claude.**

| Before | After |
|--------|-------|
| Codex skill docs still mixed legacy task-team vocabulary and old state paths | Codex skill docs are aligned to native multi-agent tool flow (`spawn_agent`, `wait`, `send_input`, `resume_agent`, `close_agent`) and CODEX_HOME state paths |
| `--claude` behavior could read as implementation-only delegation in some references | `--claude` is now consistently specified as implementation + review delegation to Claude |
| Setup could leave `multi_agent` / role defaults implicit | Setup scripts now ensure `features.multi_agent=true` and harness agent role defaults in target `config.toml` |

### Changed

- Rewrote Codex distribution docs for `work`/`breezing` to use native multi-agent flow terminology and removed legacy task-team wording.
- Standardized runtime state references to `${CODEX_HOME:-~/.codex}/state/harness/` across Codex skill docs.
- Added explicit flag conflict rule: `--claude + --codex-review` fails before execution.
- Updated Codex setup references and README to reflect native multi-agent defaults and role declarations.
- Strengthened `tests/test-codex-package.sh` and CI to guard against legacy vocabulary regressions and enforce required multi-agent keywords/config defaults.

### Fixed

- Fixed inconsistent review routing by making `--claude` mode explicitly require Claude reviewer routing in both `work` and `breezing`.

---
## [2.20.11] - 2026-02-19

### Changed

- **Harness UI moved out of distribution scope**: tracked UI assets/skills/templates/hooks are excluded from release payload
- **SessionStart hooks simplified**: removed `harness-ui-register` execution from startup/resume

### Fixed

- **Issue #50**: removed distribution-path dependency on memory wrapper scripts with hardcoded absolute paths
  - distribution no longer tracks the 8 wrapper files (`scripts/harness-mem*`, `scripts/hook-handlers/memory-*.sh`)
  - hooks/config no longer reference those wrapper scripts

---

## [2.20.10] - 2026-02-18

### What's Changed

**Codex Harness now defaults to user-based installation, and Codex command execution is Codex-first with explicit `--claude` delegation.**

| Before | After |
|--------|-------|
| Codex setup copied `.codex` per project by default | Setup defaults to user scope (`${CODEX_HOME:-~/.codex}`), with `--project` as opt-in |
| `/work --codex` and `/breezing --codex` were primary for Codex execution | Codex is default engine; `--claude` explicitly delegates implementation |
| Codex setup guidance was mixed between project/user scopes | README + setup references are aligned to user-based rollout (JP/EN) |

### Changed

- Updated Codex setup scripts (`scripts/setup-codex.sh`, `scripts/codex-setup-local.sh`) to install skills/rules to `${CODEX_HOME:-~/.codex}` by default.
- Added explicit fallback mode `--project` for project-local deployment when needed.
- Updated Codex distribution docs and setup references to user-based defaults in both English and Japanese.
- Reworked Codex skill routing/docs so implementation intents resolve to Codex-first `/work`, with `--claude` for intentional delegation.
- Aligned `/breezing` recovery/state docs (`impl_mode`) with Codex-first runtime semantics.
- Synced release-related references and command docs to avoid setup drift between README, setup skill references, and Codex distribution docs.

---
## [2.20.9] - 2026-02-15

### 🎯 What's Changed for You

**In Codex mode, `harness-review` guidance is now consistently documented as delegating to Claude CLI (`claude -p`).**

| Before | After |
|--------|-------|
| Codex-side review docs mixed Codex/MCP wording and delegation targets | Codex-side docs consistently describe Claude CLI (`claude -p`) delegation flow |

### Changed

- Updated Codex-side review docs to align review mode wording, integration flow, and detection guidance around `claude -p` delegation.
- Documentation consistency cleanup for Codex review-mode references.

---
## [2.20.8] - 2026-02-14

### Changed

- **Claude Code 2.1.41/2.1.42 adaptation**: Updated compatibility matrix and recommended version to v2.1.41+
  - Added v2.1.39〜v2.1.42 entries to `docs/CLAUDE_CODE_COMPATIBILITY.md` (4 new version sections, 30+ feature rows)
  - Recommended version raised from v2.1.38+ to **v2.1.41+** (Agent Teams Bedrock/Vertex/Foundry model ID fix, Hook stderr visibility fix)
- **Breezing Bedrock/Vertex/Foundry note**: Added CC 2.1.41+ requirement note to `guardrails-inheritance.md` for non-Anthropic API users
- **Session `/rename` auto-naming**: Added CC 2.1.41+ auto-generate session name documentation to session skill
- **Troubleshoot `claude auth` commands**: Added CC 2.1.41+ `claude auth login/status/logout` to diagnostic table

---
## [2.20.7] - 2026-02-14

### Fixed

- **Stop hook "JSON validation failed" on every turn (#42)**: Replaced unreliable `type: "prompt"` hook with deterministic `type: "command"` hook (`stop-session-evaluator.sh`)
  - Root cause: prompt-type hook instructed the LLM to respond in JSON, but the model frequently returned natural language, causing repeated JSON parse errors
  - New command-based evaluator always outputs valid JSON, eliminating validation failures entirely
  - Both `hooks/hooks.json` and `.claude-plugin/hooks.json` updated in sync

---
## [2.20.6] - 2026-02-14

### Fixed

- **session-auto-broadcast.sh の hookEventName バリデーションエラー** (#41):
  - `hookEventName` を `"AutoBroadcast"` → `"PostToolUse"` に修正（4箇所）
  - `session-broadcast.sh` の `hookEventName` を `"Broadcast"` → `"PostToolUse"` に修正
  - subprocess の stdout 汚染を防止（`>/dev/null` リダイレクト追加）
  - `test-hook-event-names.sh` テスト追加（hookEventName 一貫性の回帰テスト）

---
## [2.20.5] - 2026-02-12

### Fixed

- **Breezing `--codex` subagent_type enforcement**: Fixed `--codex` flag being ignored during Implementer spawn
  - Root cause: `execution-flow.md` Step 3 hardcoded `task-worker` with no `--codex` branch
  - Added mandatory `impl_mode` branching to SKILL.md, execution-flow.md, and team-composition.md
  - Added three "absolute prohibition" rules: codex mode must use `codex-implementer`, standard mode must use `task-worker`, codex mode Lead must not Write/Edit source
  - Added explicit parallel spawn instruction: N Implementers spawned simultaneously (`N = min(independent_tasks, --parallel N, 3)`)
  - Compaction Recovery now restores correct subagent_type based on `impl_mode`

---

## [2.20.4] - 2026-02-11

### Fixed

- **Codex MCP → CLI migration (Phase 7 completion)**:
  - Replace all `mcp__codex__codex` text references with `codex exec (CLI)` in `pretooluse-guard.sh` (4 messages) and `codex-worker-engine.sh` (1 log message)
  - Remove MCP legacy note from `codex-review/SKILL.md`
  - Add `codex-cli-only.md` rule to `.claude/rules/` for prevention
  - Add PreToolUse hook failsafe: deny `mcp__codex__*` tool calls with localized message via `emit_deny` + `msg()` pattern
  - Add `.gitignore` patterns for opencode/codex mirror dev-only skills (`test-*`, `x-promo`, `x-release-harness`)

### Security

- **Codex MCP dual-defense**: Three-layer protection against deprecated MCP usage (text correction + hook block + rule file). Codex review: Security A, Architect B

---

## [2.20.3] - 2026-02-10

### Fixed

- **Hook handler security hardening** (Codex review Round 1-3):
  - Replace manual JSON string escaping with `jq -nc --arg` and `python3 json.dumps` for safe JSON construction
  - Fix Python code injection vulnerability: pass data via `sys.argv`/`stdin` instead of triple-quote interpolation
  - Fix `grep` failure under `set -euo pipefail` with `|| true`
  - Use `grep -F` for fixed-string matching (avoid regex metacharacter issues)
  - Add `chmod 700` on `.claude/state` directory
  - Add `tostring` guard for description truncation type safety
  - Add 5-second dedup for TeammateIdle events
  - Add JSONL rotation (500 → 400 lines) to prevent unbounded growth

---

## [2.20.2] - 2026-02-10

### Added

- **TeammateIdle/TaskCompleted hook handlers**: New `scripts/hook-handlers/teammate-idle.sh` and `task-completed.sh` log agent team events to `.claude/state/breezing-timeline.jsonl`
- **3-layer memory architecture (D22)**: Documented coexistence design for Claude Code auto memory, Harness SSOT, and Agent Memory in `decisions.md`
- **Task(agent_type) pattern (P18)**: Documented sub-agent type restriction syntax in `patterns.md`

### Changed

- **Claude Code 2.1.38+ adaptation**: Updated Feature Table in CLAUDE.md with 6 new rows (TeammateIdle/TaskCompleted Hook, Agent Memory, Fast mode, Auto Memory, Skill Budget Scaling, Task(agent_type))
- **Version references**: Updated all "CC 2.1.30+" references to "CC 2.1.38+" across 16+ skill and agent files
- **Skill budget scaling**: Relaxed 500-line hard rule to recommendation in `skill-editing.md`, noting CC 2.1.32+ 2% context window scaling
- **Session memory**: Added "Auto Memory Relationship (D22)" section to `session-memory/SKILL.md` and `memory/SKILL.md`
- **Breezing execution flow**: Updated hook implementation status to "implemented" in `execution-flow.md`
- **Guardrails inheritance**: Added Task(agent_type) to safety mechanism table

---

## [2.20.1] - 2026-02-10

### Fixed

- **PostToolUse hook syntax error**: Fix bash parser error in `posttooluse-tampering-detector.sh` caused by `|| true` after heredoc inside command substitution
- **python3 fallback in all hooks**: Replace heredoc python3 fallback with `python3 -c` in all 10 hook scripts to fix stdin conflict
- **POSIX compliance**: Replace `echo` with `printf '%s'` for safe input piping, `echo -e` with `printf '%b'`
- **Pattern matching**: Replace `echo | grep -qE` with `[[ =~ ]]` for 6 pattern checks (with word boundaries)
- **Error handling**: Change `set -euo pipefail` to `set +e` to match all other PostToolUse scripts
- **Bilingual warnings**: Add English + Japanese warning messages to hook scripts

---

## [2.20.0] - 2026-02-08

### 🎯 What's Changed for You

**28 skills consolidated to 19. Breezing now runs with Phase A/B/C separation, teammate permissions fixed, and repo cleaned up.**

| Before | After |
|--------|-------|
| `memory`, `sync-ssot-from-memory`, `cursor-mem` as 3 skills | Unified `memory` (SSOT promotion + memory search in references) |
| `setup`, `setup-tools`, `harness-mem`, `codex-setup`, `2agent`, `localize-rules` as 6 skills | Unified `setup` (routing table dispatches to references) |
| `ci`, `agent-browser`, `x-release-harness` visible as slash commands | Hidden with `user-invocable: false` (auto-load still works) |
| Delegate mode ON at breezing start → bypass permissions lost | Phase A (prep) maintains bypass → delegate only in Phase B |
| Delegate mode stays on during completion → commit restricted | Phase C exits delegate → Lead can commit directly |
| Teammates auto-denied Bash due to "prompts unavailable" | `mode: "bypassPermissions"` + PreToolUse hooks for safety |
| Build artifacts, dev docs, lock files tracked in git | 33 files untracked, .gitignore updated |

### Changed

- **Skill consolidation (28 → 19)**:
  - `/memory`: Absorbed `sync-ssot-from-memory` and `cursor-mem`
  - `/setup`: Absorbed `setup-tools`, `harness-mem`, `codex-setup`, `2agent`, `localize-rules`
  - `/troubleshoot`: Added CI failure triggers to description
- **Breezing Phase separation**: Restructured execution flow into Phase A (Pre-delegate) / Phase B (Delegate) / Phase C (Post-delegate)
  - Phase A: Maintain user's permission mode while initializing Team and spawning teammates
  - Phase B: Delegate mode — Lead uses only TaskCreate/TaskUpdate/SendMessage
  - Phase C: Exit delegate, then run integration verification, commit, and cleanup
- **Teammate permission model**: All teammate spawns use `mode: "bypassPermissions"` with PreToolUse hooks as safety layer
  - PreToolUse hooks fire independently of permission system (official spec)
  - Safety layers: disallowedTools + spawn prompt constraints + .claude/rules/ + Lead monitoring
- **English-only releases**: GitHub release notes now written in English. Updated release rules and skills.
- **All related docs updated**: execution-flow.md, team-composition.md, codex-engine.md, guardrails-inheritance.md, session-resilience.md

### Added

- `skills/memory/references/cursor-mem-search.md` - Cursor memory search reference
- `skills/setup/references/harness-mem.md` - Harness-Mem setup reference
- `skills/setup/references/localize-rules.md` - Rule localization reference
- **Codex first-use check hook**: Auto-runs `check-codex.sh` on first `/codex-review` use (`once: true`)
- **timeout/gtimeout detection**: Guides macOS users to `brew install coreutils`

### Fixed

- **Codex review fixes (22 issues)**: pretooluse-guard JSON parse consolidation (5→1 jq call), symlink security guard, session-monitor `eval` removal
- **macOS compatibility**: All docs `timeout N codex exec` → `$TIMEOUT N codex exec` (GNU coreutils independent)
- **Teammate Bash auto-deny**: Resolved "prompts unavailable" error for background teammates

### Removed

- **Untracked 33 files**: `mcp-server/dist/` (24 build artifacts), `docs/design/` (2), `docs/slides/` (1), `docs/claude-mem-japanese-setup.md`, dev-only docs (3), lock files (2)
- **Archived skills**: `sync-ssot-from-memory`, `cursor-mem`, `setup-tools`, `harness-mem`, `codex-setup`, `2agent`, `localize-rules` → `skills/_archived/`

---

## [2.19.0] - 2026-02-08

### 🎯 What's Changed for You

**5つの実装コマンドを `/work` と `/breezing` の2つに統一。両方 `--codex` 対応。**

| Before | After |
|--------|-------|
| `/work`, `/ultrawork`, `/breezing`, `/breezing-codex`, `/codex-worker` の5コマンド | `/work` と `/breezing` の2コマンドに統一 |
| コマンドの使い分けが複雑 | `/work` = Claude 実装、`/breezing` = チーム完走 |
| Codex は別コマンド (`/codex-worker`, `/breezing-codex`) | `--codex` フラグで統一切り替え |
| スコープ指定方法がコマンドごとに異なる | 両コマンド共通の対話式スコープ確認 |

### Changed

- **`/work` 全面改修**: 対話式スコープ確認 + タスク数に応じた自動戦略選択
  - 1タスク → 直接実装、2-3 → 並列、4+ → 自動反復（旧 ultrawork 統合）
  - `--codex` フラグで Codex MCP 実装委託モード
  - 新リファレンス: scope-dialog.md, auto-iteration.md, codex-engine.md
- **`/breezing` 更新**: `--codex` フラグ統合（旧 breezing-codex 吸収）
  - 対話式スコープ確認の追加
  - Codex Implementer 連携を codex-engine.md に集約
- **pretooluse-guard.sh**: `ultrawork-active.json` → `work-active.json` に統一
  - 後方互換: 旧ファイル名もフォールバックで検出

### Removed

- **ultrawork** スキル → `/work all` で同等機能（`skills/_archived/` に移動）
- **breezing-codex** スキル → `/breezing --codex` で同等機能（`skills/_archived/` に移動）
- **codex-worker** スキル → `/work --codex` で同等機能（`skills/_archived/` に移動）

---

## [2.18.11] - 2026-02-06

### 🎯 What's Changed for You

**In `--codex` mode, Claude now acts as PM and Edit/Write are automatically blocked**

| Before | After |
|--------|-------|
| Claude could edit directly in `--codex` mode | Edit/Write blocked except for Plans.md |
| Ambiguous role separation | Clear PM (Claude) vs Worker (Codex) separation |

### Added

- **breezing skill (v2)**: Full auto task completion using Agent Teams
  - Lead in delegate mode (coordination only), Implementer for coding, independent Reviewer
  - `--codex-review` for multi-AI review integration
  - session_id-based Hook enforcement: Reviewer Read-only, Implementer file ownership (pretooluse-guard.sh)
  - Flexible flow: Lead-autonomous stages replace rigid Phase 0-4
  - State simplification: Agent Teams TaskList as SSOT, breezing-active.json metadata-only
  - Peer-to-peer: Reviewer↔Implementer direct dialogue for lightweight questions
  - Agent Trace: per-Teammate metrics in completion reports
- **Codex mode guard**: Added Codex mode detection to `pretooluse-guard.sh`
  - Claude functions as PM, delegating implementation to Codex Worker
  - Enabled via `codex_mode: true` in `ultrawork-active.json`
  - Only Plans.md state marker updates allowed

### Changed

- **Codex review improvements**: Enhanced parallel review quality
  - SSOT-aware reviews (considers decisions.md/patterns.md)
  - Output limit relaxed 1500 → 2500 chars for thorough analysis
  - Clear termination conditions (APPROVE when Critical/High = 0)
  - Fixed "nitpicking" issue (Low/Medium only → APPROVE)
- Minor expert template fixes

---

## [2.18.10] - 2026-02-06

### Added

- **Agent persistent memory**: Added `memory: project/user` to all 7 agents
  - Subagents can now build institutional knowledge across conversations
  - Security: Read-only agents (code-reviewer, project-analyzer) keep Bash/Write/Edit disabled
  - Privacy guards: Each agent documents forbidden data (secrets, PII, source code snippets)

---

## [2.18.7] - 2026-02-05

### Changed

- **Claude guardrails**: Stop prompting on normal `git push`; prompt only on `git push -f/--force/--force-with-lease`.

---

## [2.18.6] - 2026-02-05

### Fixed

- **Codex guardrails**: `harness.rules` now parses reliably and avoids prompting on safe commands (e.g. `git clean -n`, `sudo -n true`).
- **Claude guardrails**: `templates/claude/settings.security.json.template` now uses valid permission syntax (`:*`) and prompts only on destructive variants.

### Changed

- **Codex package test**: Added rule example validation to prevent startup parse errors.

---

## [2.18.5] - 2026-02-05

### Added

- **gogcli-ops skill**: Google Workspace CLI operations (Drive/Sheets/Docs/Slides)
  - Auth workflow and account selection
  - URL-to-ID resolution via `gog_parse_url.py`
  - Read-only by default, write requires confirmation

---

## [2.18.4] - 2026-02-04

### Added

- **Codex setup command**: Added `/codex-setup` skill and `scripts/codex-setup-local.sh`
- **Setup tools**: `/setup-tools codex` subcommand for in-session Codex setup
- **Harness init/update**: Optional Codex CLI sync during `/harness-init` and `/harness-update`

---

## [2.18.2] - 2026-02-04

### Added

- **Codex CLI distribution**: Added `codex/.codex` with full skills and temporary Rules guardrails
- **Codex setup**: Added `scripts/setup-codex.sh` and `codex/README.md`
- **Codex AGENTS**: Added `codex/AGENTS.md` tuned for `$skill` usage
- **Codex package test**: Added `tests/test-codex-package.sh`

### Changed

- **Docs**: README now includes Codex CLI setup instructions

---

## [2.18.1] - 2026-02-04

### Added

- **Aivis/VOICEVOX TTS support**: Added Japanese TTS providers to generate-video skill
  - `aivis`: Aivis Cloud API (speaker_id, intonation_scale, etc.)
  - `voicevox`: VOICEVOX (character voices like Zundamon)
  - Sample character configurations included

### Changed

- **MCP server optional**: Removed `.mcp.json`, excluded mcp-server from distribution
  - Users who need it can set up separately

---

## [2.18.0] - 2026-02-04

### Added

- **Claude Code 2.1.30 compatibility**: Full integration with new features
  - **AgentTrace v0.3.0**: Task tool metrics (tokenCount, toolUses, duration) in `docs/AGENT_TRACE_SCHEMA.md`
  - **`/debug` command integration**: troubleshoot skill now routes to `/debug` for complex session issues
  - **PDF page range reading**: notebookLM and harness-review support `pages` parameter for large documents
  - **Git log extended flags**: harness-review, CI, harness-release use `--format`, `--raw`, `--cherry-pick`
  - **OAuth `--client-id/--client-secret`**: codex-mcp-setup.md documents DCR-incompatible MCP setup
  - **68% memory optimization**: session-memory and session skills document `--resume` benefits
  - **Subagent MCP access**: task-worker and codex-worker document MCP tool sharing (bugfix in CC 2.1.30)
  - **Accessibility settings**: harness-ui documents `reducedMotion` setting

---

## [2.17.10] - 2026-02-04

### Added

- **PreCompact/SessionEnd hooks**: Support automatic session state save and cleanup
- **AgentTrace v0.2.0**: Added Attribution field for plugin attribution tracking
- **Sandbox settings template**: Added `templates/settings/harness-sandbox.json`

### Changed

- **context: fork added**: deploy/generate-video/memory/verify skills now use isolated context
- **release → harness-release**: Renamed to avoid conflict with Claude Code built-in command

---

## [2.17.9] - 2026-02-04

### Changed

- **Codex mode as default**: New project config template now defaults to `review.mode: codex`
- **Worktree necessity check**: `/ultrawork --codex` now auto-determines if Worktree is actually needed
  - Single task, all sequential dependencies, or file overlap → fallback to direct execution mode
  - Avoids unnecessary Worktree creation overhead

---

## [2.17.8] - 2026-02-04

### Fixed

- **release skill**: Fix `/release` not launching via Skill tool
  - Removed `disable-model-invocation: true`

---

## [2.17.6] - 2026-02-04

### 🎯 What's Changed for You

**generate-video スキルが JSON Schema 駆動のハイブリッドアーキテクチャに進化、README も刷新されました**

| Before | After |
|--------|-------|
| 動画生成の設定がコードに散在 | JSON Schema でシナリオを一元管理 |
| README の構成が長大 | TL;DR: Ultrawork セクションで即座に始められる |
| スキル説明が英語のみ | 28個のスキル description が日本語化 + ユーモア表現 |

### Added

- **generate-video JSON Schema Architecture** (#37)
  - `scenario-schema.json` でシナリオ構造を厳密定義
  - `validate-scenario.js` でセマンティック検証
  - `template-registry.js` でテンプレート管理
  - パストラバーサル攻撃対策を実装

- **TL;DR: Ultrawork セクション**: README に「説明が長い？これだけ」セクション追加
  - 日本語版にも「🪄 説明が長い？ならこれ: Ultrawork」として追加

### Changed

- **スキル description 日本語化**: 28個のスキルに日本語の説明とユーモア表現を追加
- **README 構成整理**: Install → TL;DR → Core Loop の流れに最適化
- **スキル数更新**: 42 → 45 スキル

### Fixed

- `validate-scenario.js`: セマンティックエラーフィルタリングのバグ修正
- `TransitionWrapper.tsx`: `slideIn` → `slide_in` でスキーマ命名規則に統一

---

## [2.17.3] - 2026-02-03

### 🎯 What's Changed for You

**Ultrawork がレビュー後に自動で自己修正ループに入るようになりました**

| Before | After |
|--------|-------|
| レビュー後に手動でプロンプト入力が必要 | APPROVE まで自動修正ループ |
| Codex 有無を手動で指定 | Codex MCP 自動検出 + フォールバック |
| 改善方法が不明確 | 「🎯 How to Achieve A」で改善指針を明示 |

### Added

- **自己修正ループ**: `/harness-review` 実行後、APPROVE になるまで自動で修正を繰り返す
  - リトライ状態管理（`ultrawork-retry.json`）で進捗追跡
  - REJECT/STOP は即停止して手動介入を促す
  - 最大3回のリトライ後に STOP

- **検証全実行規則**: 存在する検証スクリプトを優先順で全て実行し、失敗で即停止

- **改善指針テンプレート**: 「🎯 How to Achieve A」セクションで A 評価達成方法を明示
  - Decision 別統一フォーマット（APPROVE/REQUEST CHANGES/REJECT/STOP）

### Changed

- **Codex 自動検出**: Codex MCP が利用可能な場合は自動で Codex モードに切り替え
  - 利用不可の場合はサブエージェント並列にフォールバック
  - `timeout_ms`（ミリ秒単位）でタイムアウト設定可能

- **差分計算改善**: `merge-base` 基準で変更ファイル数を算出
  - staged/unstaged 差分も含む
  - 初回コミット/マージにも対応

- **review_aspects 検出**: パスベースの正規表現で決定的に判定

---

## [2.17.2] - 2026-02-03

### 🎯 What's Changed for You

**Codex Worker 完了時に Plans.md が自動更新されるようになりました**

| Before | After |
|--------|-------|
| 作業完了後に手動で Plans.md を更新 | スキルが自動で `cc:done` に更新 |

### Added

- **Plans.md 自動更新**: Codex Worker スキル完了時に必ずタスク完了処理を実行
  - 該当タスクを自動特定
  - `[ ]` → `[x]`, `cc:WIP` → `cc:done` に更新
  - タスクが見つからない場合はユーザーに確認

### Changed

- Codex Worker スクリプト品質改善（共通ライブラリ化、セキュリティ強化）

---

## [2.17.1] - 2026-02-03

### Added

- **Agent Trace**: Track AI-generated code edits for session context visibility
  - `emit-agent-trace.js`: PostToolUse hook records Edit/Write operations to `.claude/state/agent-trace.jsonl`
  - `agent-trace-schema.json`: JSON Schema (v0.1.0) for trace records
  - Stop hook now shows project name, current task, and recent edits at session end
  - `sync-status` skill now includes Agent Trace data for progress verification
  - `session-memory` skill now reads Agent Trace for cross-session context

### Changed

- Stop hook (`session-summary.sh`) enhanced with Agent Trace information display
- VCS info retrieval optimized: single `git status --porcelain=2 -b -uno` call with 5s TTL cache
- Repo root detection no longer spawns git process (walks up directory tree)

### Fixed

- Security hardening for trace file operations (symlink checks, permission enforcement)
- Rotation concurrency protection with lock file (O_CREAT|O_EXCL pattern)

---

## [2.17.0] - 2026-02-03

### Added

- **Codex Worker**: Delegate implementation tasks to OpenAI Codex as parallel workers
  - `codex-worker` skill for single task delegation
  - `ultrawork --codex` for parallel worker execution with git worktrees
  - Quality gates: evidence verification, lint/type-check, test, tampering detection
  - File locking mechanism with TTL and heartbeat
  - Automatic Plans.md update on task completion

### Changed

- Skills `codex-worker` and `codex-review` now have explicit routing rules (Do NOT Load For sections)
- Improved skill description for better auto-loading accuracy
- Added 5 shell scripts: `codex-worker-setup.sh`, `codex-worker-engine.sh`, `codex-worker-lock.sh`, `codex-worker-quality-gate.sh`, `codex-worker-merge.sh`
- Added integration test: `tests/test-codex-worker.sh`
- Added reference documentation: `skills/codex-worker/references/*.md`

### Fixed

- Shell script security improvements (jq injection, git option injection, value validation)
- POSIX compatibility for grep patterns (`\s` to `[[:space:]]`)
- Arithmetic operation in `set -e` context

---

## [2.16.21] - 2026-02-03

### Changed

- `ultrawork` Codex Mode options (`--codex`, `--parallel`, `--worktree-base`) moved to Design Draft
  - These features are planned but not yet implemented
  - Documentation now clearly marks them as "(Design Draft / 未実装)"
- Added `skills/ultrawork/references/codex-mode.md` as design draft documentation
- Added Codex Worker scripts and references (untracked, for future implementation)

---

## [2.16.20] - 2026-02-03

### Changed

- Centralized skill routing rules to `skills/routing-rules.md` (SSOT pattern)
- Made `codex-review` and `codex-worker` routing deterministic (removed context judgment)

---

## [2.16.19] - 2026-02-03

### Fixed

- Reduced duplicate display of Stop hook reason (now outputs keywords only)

---

## [2.16.17] - 2026-02-03

### 🎯 What's Changed for You

**Skills now show usage hints in autocomplete**

| Before | After |
|--------|-------|
| `/harness-review` | `/harness-review [code|plan|scope]` |
| `/troubleshoot` | `/troubleshoot [build|test|runtime]` |

### Added

- Usage hints (`argument-hint`) added to 17 skills
- Inter-session notifications (useful for multi-session workflows)

### Changed

- Updated CI/tests/docs for Skills-only architecture

---

## [2.16.14] - 2026-02-02

### 🎯 What's Changed for You

**Implementation requests are now automatically registered in Plans.md**

| Before | After |
|--------|-------|
| Ad-hoc requests not tracked | All tasks recorded in Plans.md |
| Hard to track progress | `/sync-status` shows full picture |

---

## [2.16.11] - 2026-02-02

### 🎯 What's Changed for You

**Commands have been unified into Skills (usage unchanged)**

| Before | After |
|--------|-------|
| `/work`, `/harness-review` as commands | Same names, now powered by skills |
| Internal skills (impl, verify) in menu | Hidden (less noise) |
| `dev-browser`, `docs`, `video` | Renamed to `agent-browser`, `notebookLM`, `generate-video` |

### Changed

- README rewritten for VibeCoders (added troubleshooting, uninstall)
- CI scripts updated for Skills structure

---

## [2.16.5] - 2026-01-31

### 🎯 What's Changed for You

**`/generate-video` now supports AI images, BGM, subtitles, and visual effects**

| Before | After |
|--------|-------|
| Manual image preparation | AI auto-generates (Nano Banana Pro) |
| No BGM/subtitles | Royalty-free BGM, Japanese subtitles |
| Basic transitions only | GlitchText, Particles, and more |

---

## [2.16.0] - 2026-01-31

### 🎯 What's Changed for You

**`/ultrawork` now requires fewer confirmations for rm -rf and git push (experimental)**

| Before | After |
|--------|-------|
| rm -rf always asks | Only paths approved in plan auto-approved |
| git push always asks | Auto-approved during ultrawork (except force) |

---

## [2.15.0] - 2026-01-26

### 🎯 What's Changed for You

**Full OpenCode compatibility mode added**

| Before | After |
|--------|-------|
| Separate setup needed for OpenCode | `/setup-opencode` auto-configures |
| Different skills/ structure | Same skills work in both environments |

---

## [2.14.0] - 2026-01-16

### 🎯 What's Changed for You

**`/work --full` enables parallel task execution**

| Before | After |
|--------|-------|
| Tasks run one at a time | `--parallel 3` runs up to 3 concurrently |
| Manual completion checks | Each worker self-reviews autonomously |

---

## [2.13.0] - 2026-01-14

### 🎯 What's Changed for You

**Codex MCP parallel review added**

| Before | After |
|--------|-------|
| Claude reviews alone | 4 Codex experts review in parallel |
| One perspective at a time | Security/Quality/Performance/a11y simultaneously |

---

## [2.12.0] - 2026-01-10

### Added

- **Harness UI Dashboard** (`/harness-ui`) - Track progress in browser
- **Browser Automation** (`agent-browser`) - Page interactions & screenshots

---

## [2.11.0] - 2026-01-08

### Added

- **Inter-session Messaging** - Send/receive messages between Claude Code sessions
- **CRUD Auto-generation** (`crud` skill) - Generate endpoints with Zod validation

---

## [2.10.0] - 2026-01-04

### Added

- **LSP Integration** - Go-to-definition, Find-references for accurate code understanding
- **AST-Grep Integration** - Structural code pattern search

---

## Earlier Versions

For v2.9.x and earlier, see [GitHub Releases](https://github.com/Chachamaru127/claude-code-harness/releases).

[Unreleased]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.3...HEAD
[4.0.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.2...v4.0.3
[4.0.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.1...v4.0.2
[4.0.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.0...v4.0.1
[4.0.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.17.1...v4.0.0
[3.17.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.17.0...v3.17.1
[3.17.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.16.0...v3.17.0
[3.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.15.0...v3.16.0
[3.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.14.0...v3.15.0
[3.10.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.10.2...v3.10.3
[3.10.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.10.1...v3.10.2
[3.10.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.10.0...v3.10.1
[3.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.9.0...v3.10.0
[3.9.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.2...v3.9.0
[3.7.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.1...v3.7.2
[3.7.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.7.0...v3.7.1
[3.7.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.6.0...v3.7.0
[3.4.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.0...v3.4.1
[3.4.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.1...v3.4.2
[3.5.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.4.2...v3.5.0
[3.4.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.3.1...v3.4.0
[3.3.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.3.0...v3.3.1
[3.3.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v3.2.0...v3.3.0
[2.26.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.26.0...v2.26.1
[2.26.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.25.0...v2.26.0
[2.25.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.24.0...v2.25.0
[2.24.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.6...v2.24.0
[2.23.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.5...v2.23.6
[2.23.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.3...v2.23.5
[2.23.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.2...v2.23.3
[2.23.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.1...v2.23.2
[2.23.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.23.0...v2.23.1
[2.23.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.22.0...v2.23.0
[2.22.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.21.0...v2.22.0
[2.21.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.13...v2.21.0
[2.20.13]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.11...v2.20.13
[2.20.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.10...v2.20.11
[2.20.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.9...v2.20.10
[2.20.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.8...v2.20.9
[2.20.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.7...v2.20.8
[2.20.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.6...v2.20.7
[2.20.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.5...v2.20.6
[2.20.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.4...v2.20.5
[2.20.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.3...v2.20.4
[2.20.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.2...v2.20.3
[2.20.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.1...v2.20.2
[2.20.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.20.0...v2.20.1
[2.20.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.19.0...v2.20.0
[2.19.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.11...v2.19.0
[2.18.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.10...v2.18.11
[2.18.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.7...v2.18.10
[2.18.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.6...v2.18.7
[2.18.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.5...v2.18.6
[2.18.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.4...v2.18.5
[2.18.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.2...v2.18.4
[2.18.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.1...v2.18.2
[2.18.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.18.0...v2.18.1
[2.18.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.10...v2.18.0
[2.17.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.9...v2.17.10
[2.17.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.8...v2.17.9
[2.17.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.6...v2.17.8
[2.17.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.3...v2.17.6
[2.17.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.2...v2.17.3
[2.17.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.1...v2.17.2
[2.17.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.17.0...v2.17.1
[2.17.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.21...v2.17.0
[2.16.21]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.20...v2.16.21
[2.16.20]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.19...v2.16.20
[2.16.19]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.17...v2.16.19
[2.16.17]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.14...v2.16.17
[2.16.14]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.11...v2.16.14
[2.16.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.5...v2.16.11
[2.16.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.16.0...v2.16.5
[2.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.15.0...v2.16.0
[2.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.14.0...v2.15.0
[2.14.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.13.0...v2.14.0
[2.13.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.12.0...v2.13.0
[2.12.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.11.0...v2.12.0
[2.11.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.10.0...v2.11.0
[2.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v2.9.24...v2.10.0
