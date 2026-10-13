# 変更履歴

[English](CHANGELOG.md) | [現在の使い方](README_ja.md)

CLIは入力したコマンドで操作するアプリです。
フックは作業の節目に自動で動く処理です。
作業ツリーは、タスク用に分けたプロジェクトの写しです。
preflightは着手や公開の前の検査、schemaは記録の形式を定義するものです。
MCPはアシスタントから外部の機能を使う接続方式です。
high、xhigh、maxなどの推論量は実行先ごとの設定値で、完了率ではありません。

各版は、その時点で変わった内容です。
当時の既定値とコマンドは後の版で変わっているため、導入は現在のREADMEを使ってください。
**Unreleased**は版を付けて公開する前の変更です。

[元の履歴全文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md)をバイト単位で変更せず保存しています。
当時の技術詳細と相対リンクは、[元コミット6c198b4c76f9の変更履歴](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md)から参照できます。
内部の工程番号と作業台帳は保存版へ分けました。
既存の比較参照はそのまま保ち、元にない比較リンクは作っていません。

## [Unreleased]

### Changed

- 共有marketplaceと全実行先の配布プラグインIDを`harness`へ揃えます。
  リポジトリ名、marketplace名、プロジェクトの設定パスは同じです。
  対応するClaude Codeはmarketplaceの改名マップに従います。
  配布元を更新して同じscopeへ新IDを導入し、有効なコピーが1つだけか確認します。
  プラグイン専用データの自動転送は保証しません。
  [切替手順](https://github.com/Chachamaru127/claude-code-harness/blob/main/docs/onboarding/plugin-rename_ja.md)を参照してください。

- 英語版と日本語版のREADME、全版の変更履歴を書き直しました。
  更新判断に必要な条件を残し、元の履歴全文へリンクしました。
  冒頭の短いアニメーションで仕事の流れを示し、動きを減らす設定向けに静止版も用意しました。
- ソースからビルドする場合はGo 1.26.0が必要です。
  モジュールとワークスペースを揃え、同じ版で4プラットフォームの同梱実行ファイルを再生成しました。
  同梱版の利用者はGoのインストール不要です。
- `golang.org/x/sys`を0.47.0から0.49.0へ、`modernc.org/sqlite`を1.56.0から1.60.1へ更新しました。
  関連するlibcは1.77.1、memoryは1.12.1です。
- ベンチマークの保守では、検査で固定した`@vercel/agent-eval` 1.4.xのパッチ更新だけをDependabotが提案します。
  固定条件に合わないメジャー更新とマイナー更新の提案を止めました。

### Fixed

- 別製品claude-memの利用者に、`~/.claude-mem/`があるだけで旧記憶領域の警告を出していた問題を直しました。
  harness-memの識別情報がある場合だけ判定します。
- 外部通信の検査が`late.txt`や`config.json`を通信先と誤認する問題を直しました。
  `evil.sh`など、登録済みのトップレベルドメインを持つホストは引き続き拒否します。
- 品質判定、書き込み後レビュー、会話圧縮前のフックで、解決可能なモデルID `claude-haiku-5-5`を使います。
  短縮名による未認識エラーを直しました。
- 別の場所からフックを実行しても、状態ファイルをプロジェクト直下に保存します。
  フック入力の作業場所を`CLAUDE_PROJECT_DIR`より優先し、作業ツリーごとのロックと計画監視を分けます。
- 統合試験では利用者のGit設定を読み込まず、背景で動くGit保守処理を止めます。
  後片付けの競合が再発した場合は短時間待ち、書き込み中のプロセスを記録します。
  利用者のプロジェクト設定は変えません。
- ベンチマークの依存条件を`undici ^7.30.0`、`brace-expansion ^5.0.12`、`@grpc/grpc-js ^1.14.6`へ修正しました。
  公開された脆弱性情報で変更検査が停止する問題を直します。

## [5.15.0] - 2026-09-06

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5150---2026-09-06) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L62)

### Added

- 日本語の製品ガイドを追加しました。
  依頼方法と期待できる結果をスマートフォンでも読めます。
  モデル設定は開いて確認できます。

### Changed

- 英語版、日本語版、Codex版の案内に、タスク実行、役割の既定値、手動のモデル選択、進捗、再開方法を記載しました。
  タスク件数の進捗と受け入れ検査の合格を分けます。
- Claudeの詳しい計画と相談役はFable 5.1/highを既定にしました。
  Codexの高性能枠はGPT-6 astraです。
  軽量な施工役、Codex各役の既存の推論量、隔離したSonnetのセキュリティ判定役は別設定を保ちます。
- 実行手順を、作業範囲、復元できる入力、独立した委譲、観測した完了証拠に合わせました。
  必要な検査、レビュー回数の上限、権限の境界は保ちます。

### Fixed

- LinuxとmacOSで引継ぎ時刻を数値のまま初期化、復元します。
  構造化した引継ぎをLinuxでも再開できます。
- 相談役の回帰試験が利用者の設定を変更する問題を直しました。
  プロジェクトに明示したモデル選択は引き続き検査します。
- 外部CLIへの委譲前に、対応する作業場所の指定形式を揃えます。
  レビュー対象が依頼したプロジェクトからずれる問題を直しました。
- 大きな計画と施工状況を標準入力で渡します。
  証拠を残しながら、OSのコマンド引数上限で起動できなくなる問題を直しました。
- Codexの初期設定で管理対象の判定役を結び付けます。
  既定の役割がそのモデルと指示を隠す問題を直しました。
  独自の役割指定は保ち、ネイティブ委譲の権限継承と外部CLIの読み取り専用レビューを区別します。
- 外部委譲でもCodexの明示したモデルと推論量を保ちます。
  `ultra`も対象です。
  相談役の既定値はインストール先ではなく対象プロジェクトから読みます。
- 実行と主環境の保護検査で、作業場所と書き込み予定を一致させます。
  未対応の設定上書きや追加の書き込みルートは起動前に拒否します。
- Claude版とCodex版に相談役と反復実行が必要とする補助処理を同梱しました。
  反復実行の起動と再開で、計画、完了条件、失敗証拠、前回の助言を保ちます。
- Goの施工処理で依頼内容とレビュー修正事項を保ちます。
  任意で使う判定契約は明示した判定を要求し、矛盾する文章に`APPROVE`が含まれるだけでは合格にしません。
- ブラウザレビューの指示へ、完了条件、推定した範囲、対象外、判定役の注意事項を渡します。
  結果形式と呼び出し方法は変えません。

## [5.14.1] - 2026-08-31

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5141---2026-08-31) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L113)

### Fixed

- 秘密ファイルの読み取り例外で、宣言とコマンドの先頭`~/`をプロセスのホームに揃えます。
  表記の補正だけです。
  単独の`~`と`~/`、`$HOME`、`~user`は展開も新規許可もしません。
- 入力ファイルを持たない`cat > file`、`cat >> file`、`cat > file <<EOF`を読み取りと誤認する問題を直しました。
  後続の環境ファイル指定を不要に拒否しません。
  `cat FILE`、入力リダイレクト、出力指定の前後に置く入力ファイルは引き続き拒否します。
  `&>`と`&>>`でも入力ファイルを隠せません。

## [5.14.0] - 2026-08-31

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5140---2026-08-31) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L131)

### Added

- 任意設定`destructive_delete: defer`を追加しました。
  対象が不確かな削除を拒否して待ち一覧`.claude/state/deferred-ops.jsonl`へ保存し、無人実行は続けます。
  再試行は拒否したまま重複登録しません。
  既定は`warn`のままで、警告付きで許可する場面も変えません。
- 設定場所は`harness.toml [safety.permissions] destructiveDelete`、プロジェクトYAMLの`safety.destructive_delete`、`HARNESS_DESTRUCTIVE_DELETE_POLICY`です。
  所有を静的に確認できる対象は許可します。
  ルート外、`..`、未解決変数、glob、単独の`.`はdeferで待ち一覧へ入れます。
  前置コマンドがある相対パスやプロジェクト内のパスはwarnと同じ扱いです。
- 本人は`bin/harness deferred list`で一覧を見て、`bin/harness deferred approve <id>`で1件を承認します。
  次の同一コマンドだけを1回許可し、その後の試行は再び拒否して登録します。
  一括承認と自動承認はありません。
  進捗画面にも待ち項目と承認コマンドを表示します。
- エージェントは一覧を読めますが、承認コマンドや保護対象の承認記録、監査記録への書き込みは拒否します。
  承認者を記録し、登録、承認、消費を同じロックで処理します。
  任意のインタプリタによる書き込みには検査上の限界が残ります。

## [5.13.2] - 2026-08-29

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5132---2026-08-29) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L168)

### Fixed

- 未導入の版に不完全なプラグインキャッシュを先に作る問題を直しました。
  既存キャッシュの`agents/`不足を補い、版情報のファイルは変更しません。
- マーケットプレイスの複製は、Git HEADが同じ版を示す場合だけ同期します。
  複製から追跡済みの調査ファイルを削除しません。
  更新先の版を誤認する問題を直しました。
  非公開パスの掃除はキャッシュ側だけです。

### Changed

- 同期報告書でプラグイン部品不足の原因を訂正し、修理の優先順位を記録しました。
  宣言ファイルとGo生成コードは変えていません。

## [5.13.1] - 2026-08-26

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5131---2026-08-26) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L187)

### Changed

- 開発計画で、無人実行が序盤の確認で止まる問題を優先しました。
  記憶処理の修理、日本語の文章規則の追加と引退、CLI標準機能との重複確認を予定しました。
  この版で実行機能を追加したという意味ではありません。

## [5.13.0] - 2026-08-25

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5130---2026-08-25) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L193)

### Added

- 同じPCのClaude Code、Codex、Cursor、Grok、Hermesセッションが互いを一覧で見て連絡できます。
  名札はセッション終了まで残り、ターンごとの更新は宣言した名前と作業を保ちます。
  全員向け通知は別の作業ツリーにも届きます。
  harness-mem側の未知の登録項目は消しません。
- セッション登録時に`CLAUDE_ENV_FILE`へ送受信者の識別情報をexport形式で渡します。
  `session-send`は`bin/harness inbox send --team/--from/--to/--subject`を案内します。
  完了通知、編集範囲の宣言、引継ぎが対象で、推測に基づく相談は対象外です。
- メッセージ検証は既定OFFです。
  `[livemsg] verification = "off" | "on"`で選びます。
  環境変数、プロジェクトYAML、プロジェクトTOML、プラグインTOML、既定値の順で解決します。
  OFFでは検証しません。
  ONではファイル、コミット、Git状態を機械検査し、HOLDなら送信せず理由を返します。
- 読み取り専用判定役の呼び出し口はありますが、実際の送信には未接続です。
  不在時は`not_observed`を記録して機械検査の結果を使い、文章の主張まで判定済みとは扱いません。
  Hermesにはターンごとの配信だけを用意し、操作を止めるフックは生成しません。

### Fixed

- HOLD判定で実際に配信を止めます。
  版番号やメールアドレスを存在しないファイルと誤認しません。
  スラッシュのない表記は既知の拡張子を要求します。
- Hermesの操作制限フックが未対応でも配信処理は生成します。
  必要なホーム設定がないホストは明示して飛ばします。
  一覧にteamとagentを残して表示し、セッションID宛ての黙った未達を防ぎます。
  配線検査は実際の生成物を確認します。

## [5.12.0] - 2026-08-24

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5120---2026-08-24) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L225)

### Added

- CodexのBreezing施工役は、管理対象の役割設定か中央の振分けで`gpt-5.6-luna`/`max`を使います。
  外部補助処理が受け付けない`max`はCodex実行設定へ変換します。
  判定役、相談役、高性能枠は`gpt-5.6-sol`/`xhigh`のままです。
- Codexレビューはローカルのapp-server中継へモデル、判定モデル、推論量を明示します。
  `review --commit`は起動前に拒否し、成功した委譲だけを記録します。
  中断を補助処理と中継の両方へ渡し、最大1秒後に残る子プロセスを終了、回収します。

### Changed

- Codex版の更新後は初期設定を再実行し、Codexを再起動します。
  事前検査後、Harness所有の旧通知設定2形式だけをバックアップして一括移行します。
  独自設定や曖昧な形式は変更せず失敗します。
  未設定の`features.multi_agent`と`features.default_mode_request_user_input`を追加します。
- Claude版とCodex版に施工役、判定役の設定とレビュー補助処理を同梱します。
  Codex版は範囲外変更の検査用実行ファイルも含みます。
  主環境の検査が拒否すれば実行先を起動しません。
  メイン会話と明示した実行先は施工役の既定固定の対象外です。
- 公開手順をタグで起動する処理と公開後の検証に揃えました。
  Windowsの名前付きパイプは試験用入力と静的検査だけで確認しています。
  実Windowsのapp-server実行は未観測です。

## [5.11.0] - 2026-08-22

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5110---2026-08-22) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L242)

### Changed

- 削除方針の既定を`ask`から`warn`へ変えました。
  静的に確定できないプロジェクト相対の対象は警告を記録して進めます。
  外部パス、`..`、未解決変数、glob、単独の`.`は引き続き確認します。
  `HARNESS_DESTRUCTIVE_DELETE_POLICY=ask`かプロジェクト設定で従来の既定に戻せます。
- 明示した不正値はaskへ戻します。
  プロジェクト直下に失うと困る未追跡データがある場合と保護処理の開発では、TOMLの`destructiveDelete = "ask"`かYAMLの`safety.destructive_delete: ask`で従来の確認を選びます。
  実行前制限は変えません。

## [5.10.0] - 2026-08-22

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#5100---2026-08-22) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L248)

### Added

- `destructive_delete = ask | warn`を追加しました。
  設定場所はYAMLの`safety.destructive_delete`、TOMLの`[safety.permissions] destructiveDelete`、`HARNESS_DESTRUCTIVE_DELETE_POLICY`です。
  この版の既定はaskです。
  warnでは不確かなプロジェクト相対パスや自セッションの一時領域の削除を`R05_WARN`の警告付きで許可し、記録します。
  外部パス、`..`、未解決変数、glob、単独の`.`と`/`は確認します。
  後続の拒否、確認規則を優先します。
  シンボリックリンクには既知の検査限界が残ります。

### Changed

- 公開タグを`vX.Y.Z`だけに揃えました。
  以前のプラグイン名付きタグは履歴として残します。
  導入はそれらのタグに依存していません。
  日英READMEは重複する表とリンクを整理し、対応区分を保ちます。

## [5.9.0] - 2026-08-17

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#590---2026-08-17) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L259)

### Added

- セキュリティのリスクには実行時検査、画面のリスクにはブラウザ検査を選びます。
  承認時に検査段階を黙って下げられません。
  ブラウザ環境が足りなければ未検証として記録します。
  受け入れ判断は保存した実行結果を読み、未検証の条件を出荷可にしません。
- 作業範囲の検査は`[scope_leash] enforce_level = off|warn|enforce`で選び、既定はwarnです。
  宣言外の書き込みを実行前に検査し、落とした範囲は停止時に通知します。
  施工報告を`.claude/state/review/`へ保存します。
- ブラウザの検証証拠としてPlaywright録画を受け入れHTMLへ埋め込めます。
  録画がない場合は理由付きの文章で残します。
  計画とレビューで再調査を1回行い、当初と別系統の案を1つ検討します。
- 日本語の文章検査は既定OFFです。
  `writing_lint.enabled`で有効にします。
  個人のJSONL辞書を使い、Markdownとテキスト、文末の連続、文体の混在を検査します。
  書き込み後は助言だけです。
  重大な指摘が残ると停止を1回止め、再入時は警告します。
  規則の下書きを正式登録できるのは本人の`scripts/writing-rule-approve.sh`だけです。
- 計画、進捗、受け入れ画面をスマートフォン対応にしました。
  進捗画面に文章規則の承認待ちを表示します。
  導入済みならdiagram-designで図を描けます。
  完了条件は機械検査、文章判定、目的を分けます。
  任意の基準を見せない受け手検査は説得用文書だけが対象です。
  判定役は新しい会話、固定した基準、絶対評価、実物確認を使います。
- 設定形式へwriting_lintとquality_packを正式に含めました。
  施工手順は承認境界を保ちつつ、通常の一時領域掃除で本人の作業を止めないようにします。
  検証の連携もプラグイン検査で確認します。

### Fixed

- セッション履歴の警告は600行超過と退避可能な項目の存在を両方満たすときだけ出します。
  30日以内の項目は残し、日付を読めない項目は退避可能と数えます。
  保守では委譲、読込指示、セッションイベント、変更ファイルの記録を末尾2,000行残します。
  agent-traceがある場合は1,000行です。
- サブディレクトリの操作は最寄りの`.harness`か`.git`まで遡り、ホームの手前で止めます。
  目印がなければ元の作業場所を使います。
  保護設定、事前承認、テスト先行設定、作業モードを同じルートで判定します。
  `.claude`は目印にしません。
- リダイレクトと`tee`に加え、`ln`、`cp`、`mv`、`install`の保護パスへの書き込みも検査します。
  最後の明示した宛先を対象とし、宛先が暗黙の1引数形式は対象外です。
  Grokの公開検査は、意図して同梱する宣言、フック、実行ファイルを受け入れます。

### Changed

- SQLiteを1.55.0から1.56.0へ、jsonschema/v6を6.0.2から6.0.3へ更新し、4プラットフォームの実行ファイルを再生成しました。
  関連版はlibc 1.74.4、go-isatty 0.0.24です。
  Grok版にフックを同梱し、`harness gen`は`.grok/hooks/harness-pretool.json`を`--host grok`付きで生成します。
  実機のプロジェクトフック読込は確認しましたが、配布物の再導入と読込は未確認です。
- `--parallel N`は同時実行の希望値です。
  実際の実行数はClaude Codeが決めます。
  当時の既定は20で、超過分は待ちます。
  入れ子起動の既定は深さ3です。
  Harnessはこれらの標準値を上書きしません。

## [5.8.0] - 2026-08-14

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#580---2026-08-14) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L401)

### Added

- Grokへ画面なしで作業を委譲できます。
  既定は読み取り専用で、作業範囲外の変更を検査し、秘密を伏せます。
  Grok実行ファイルがなければ未設定として終了コード3を返します。
  修正反復は回数、判定、指摘を`.claude/state/repair-loop/`に保存し、`MAX_REVIEWS`をその記録から検査します。
- 任意の`--blind-judge`で、基準を見ない受け手を追加します。
  公開画面の文章、文書、理解負荷を扱うHTMLが対象です。
  コード、試験、設定、形式定義は対象外です。
  食い違いは助言として残し、主判定を上書きしません。

### Changed

- 実アカウントの一覧に合わせてGrok振分けを訂正しました。
  軽量枠と通常枠は`grok-4.5`、高性能枠、相談役、判定役は`grok-4.6`/xhigh、公開と長文枠は`grok-4.6`/highです。
  両者は500kの入力枠を持ちますが、4.5はxhighを受け付けません。
  以前の根拠は同名の別CLIでした。
- 削除確認を対象で判断します。
  プロジェクト内と、自セッションIDを含む一時領域は進められます。
  一時領域のルート、別セッション、範囲外へのリンク、glob、曖昧な変数や置換、xargsの追加対象、記憶領域の再帰削除は確認します。
  絶対パスのパイプと1回だけのリテラル代入は解決できます。
  単引用符内か退避した`$`があれば変数解決しません。
- 標準の同時実行数と深さ、通信先制限、認証情報の伏せ字処理を記録しました。
  macOSの伏せ字処理は拒否へ戻るため、denyReadの置き換えは提案に留めました。
- 確認したGrok一覧は4.6でlow、medium、high、xhigh、4.5でlow、medium、highを受理します。
  Claude標準の`CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` (既定20)と`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH` (既定3)はHarness設定ではなく実行元の設定です。

### Fixed

- Cursorの実行ファイル探索で`agent`を先に確認します。
  汎用名なので、解決先のパス要素がCursorの識別名と一致する場合だけ採用し、正体を調べるために未知の実行ファイルを起動しません。
  Grokの標準フック能力とHarness配布不足を区別して記録しました。
  この版の生成は未対応のままです。

## [5.7.0] - 2026-08-12

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#570---2026-08-12) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L427)

この版では、Claude Codeが`.claude-plugin/settings.json`の権限規則を読まない欠陥も記録しました。
規則を配布しただけでは、会話で効いている証拠になりません。
`/permissions`で有効な規則を確認してください。

### Fixed

- `harness work-mode`で実セッションIDを使います。
  `--session-id`、exportした`HARNESS_SESSION_ID`、2時間以内の最新フックIDの順で解決し、旧監視IDは拒否します。
  セッション終了で解除し、残留状態は24時間で期限切れにします。
  実IDの試験は通りましたが、新Claudeセッションへの環境ファイル反映は公開後の確認が必要でした。
- Codexモードの直接書き込み禁止と判定役の書き込み禁止が、Breezing状態とネイティブの役割識別を読めるようになりました。
  判定結果は文字列上もリンク解決後も`.claude/state/`内にある場合だけ書けます。
  親参照とリンクによる脱出を拒否します。
  役割登録にagent_idを要求し、リーダーを誤って判定役にしません。
- `~/.claude/projects/<slug>/memory/**`と`~/.claude/plans/**`への書き込み確認を省きます。
  設定、スキル、役割、コマンド、フック、プラグイン、似た名前のバックアップ領域は例外にしません。
  作業範囲外の検査は変えません。
- grepの早期終了とpipefailによる試験の誤失敗を直しました。
  まとめてマージした後の計画内コミット参照を訂正します。
  浅い複製では到達可能性を未観測として扱い、検証済みにしません。
- 以前の全体指定`HARNESS_WORK_MODE=1`は、施工中以外もプロジェクト外の書込確認を省きました。
  この版ではその限界を記録し、会話単位の作業設定を用意します。
  保護パスの拒否と範囲外の破壊検査は別に保ちます。

### Added

- `harness work-mode on|off|status`でセッション単位の状態を操作できます。
  識別できない場合は失敗し、既存のセッション情報は保ちます。
  保護判定の値と設定に実際の供給元があることを試験し、手組み入力だけの検証にしません。
- Grokのモデル振分けを変更しましたが、参照した一覧は後に同名の別CLIと判明しました。
  当時の設定を使う前に5.8.0の訂正を確認してください。
  この版はCodexのmax受理が未確認だったためxhighを保ちました。
- 後に訂正した当時のGrok表は、grok-3-mini (low/high)、grok-4.20-non-reasoning、高性能、相談、判定、公開にgrok-4.3、長文にgrok-4.20-0309-reasoningを選びました。
  応答専用の複数役モデルは操作を使う役から外しました。
  この表は別製品の一覧を使っており、5.8.0で訂正しています。

### Changed

- 保護手順で、エージェントだけへの権限設定とフック、OSが子プロセス全体へ強制する隔離を分けました。
  強い制限は範囲を狭め、全体設定へ広げる前に1プロジェクトで試します。
  excludedCommandsは起動名に一致するだけで、子プロセスに権限を継承しません。
- セッション履歴の警告を500行から600行へ上げました。
  30日保持と`SESSION_LOG_MAX_LINES`による上書きは保ちます。
  x/sysを0.46.0から0.47.0へ、SQLiteを1.54.0から1.55.0へ更新し、実行ファイルを再生成しました。
  CI処理とベンチマークも更新し、agent-evalは1.4.0です。
- CI用CodeQLを4.37.1から4.37.3、Scorecardを2.4.3から2.4.4、setup-pythonを6.3.0から7.0.0へ更新しました。
  削除されたpip-install入力は使っていません。
  20個のベンチマーク設定はキーを改名せずagent-eval 1.4.0で型検査を通りました。

### Security

- ベンチマークの依存を監査済みのagent-eval `~1.4.0`、undici `^7.29.0`、nanoid `^3.3.17`、brace-expansion `^5.0.9`へ更新しました。
  高危険度3件を解消し、低危険度5件はmoderate検査の閾値未満で残ります。
  使用中のCLIとExperimentConfigは型検査上の互換性を保ちます。

## [5.6.0] - 2026-08-01

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#560---2026-08-01) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L618)

### Security

- 秘密読み取り例外は、相対パスと絶対パスを解決して作業ツリー内か検査します。
  範囲外へのリンクも拒否します。
  エージェントは`.claude-code-harness.config.json`と`.yaml`を編集できません。
  releaseAutoの変更は本人の手動編集です。
  公開用の設定雛形は書き込めます。
- 保護ブランチの検査が先頭`+`の強制push指定を認識します。
  `git push origin +main`と`+refs/heads/main`は確認し、保護先のhard resetは拒否します。
  保護外の`+feature/x`は従来どおりです。

### Added

- 毎ターン、回答言語を指示します。
  プロジェクトYAMLの`i18n.language`、`CLAUDE_CODE_HARNESS_LANG`、英語の順で決めます。

### Fixed

- 言語の案内を実行時に読むYAMLへ修正しました。
  保護機能の試験では本人の例外設定を引き継がず、検査の無効化や後続検査の未実行を防ぎます。
- macOSの進捗更新で、中断後も一意な一時ファイル名を使います。
  他9箇所の一時ファイルと173箇所のpipefail/grep検査も修理し、再発検査を追加しました。
  判定条件は残します。
  静的検査は変数や関数で間接的に組み立てたコマンドを対象にしません。
- 本人が案内どおり`/harness-plan-brief`、`/harness-progress`、`/harness-accept`を呼べるように直しました。
  Cursor配布の表示設定は従来の変換を保ちます。

## [5.5.0] - 2026-07-29

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#550---2026-07-29) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L732)

### Fixed

- 自律実行中も、作業ツリー外のGNU長形式の再帰削除とfindの削除を検出します。
  シェルへ渡して実行する複数行本文では秘密読み取りを検査し、文書本文やコメントの削除コマンド表記は誤検出しません。
- 秘密読み取りの事前承認は現在の対象作業と一致するときだけ反映します。
  無関係な将来の実行へ残しません。

### Added

- 警告、確認、拒否を`.claude/state/audit/guardrail-fires.jsonl`へ記録します。
  通常の許可は記録しません。
  コマンドとパスの生値は保存せず、ハッシュと長さだけを残します。
  秘密読み取りと課金ではそれらも省きます。
- リンク解決後もOS一時領域かキャッシュ内にある書き込みは確認を省きます。
  作業ツリー内の再帰削除も、全対象が内側と確認できる場合だけ省きます。
  動的対象、前置コマンド、パイプ、背景実行、親参照は確認します。
  未追跡と未コミットのファイルは失われ得ます。
- 保護ブランチへのpush事前承認に、有効期限、作業範囲、コマンド一致、回数上限を要求します。
  既定上限は10回で、使用ごとに加算します。
  範囲が未解決なら確認します。
  対象は保護規則R12だけで、5種類の実行前制限は変えません。

## [5.4.0] - 2026-07-26

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#540---2026-07-26) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L810)

### Added

- `bin/harness inbox send --team <t> --from <id> --to <agent> "本文"`で個別に連絡できます。
  `inbox sent`で既読を見ます。
  ターン境界で配信し、制御文字を除去してデータとして扱います。
  1件768バイト、合計4,096バイトが上限です。
  危険操作の承認は対象会話のコンソールだけで行います。
  未読がなければ表示しません。
- `session declare --task <id>`と`session list`で名前、作業、経過時間を見られます。
  共有名札とローカル一覧を合わせ、Git外の会話も表示します。
  CodexとCursorの配信は環境変数、フックのsession_idの順で宛先を解決します。
  不明なら警告して作業は止めません。
- `/breezing`は必要なら計画し、実装し、新しい会話のレビューとCodexの別判定を最大3巡行って報告します。
  範囲未指定の計画は今着手できる全作業を対象にし、必須、推奨、任意、除外と理由を示します。
- 検証が`claude-opus-5`を受理します。
  常時読む規則を103.2KBから29.2KBへ減らし、承認と拒否の契約は保ちます。
  場面別の手順は参照先へ移しました。

### Changed

- 標準の施工先をClaudeのネイティブ応援にしました。
  `--backend codex|cursor`で変更できます。
  Claudeの高性能枠と相談役はOpus 5/xhighでFableも選択可能、通常判定はFable 5/xhigh、施工役はSonnet 5です。
  Cursorの高性能枠はFable 5/xhighです。
  Codexの通常、高性能、判定、相談役はGPT-5.6-sol/xhigh、公開と長文はhigh、軽量枠はGPT-5.4-miniを保ちます。
- 会話圧縮前に、変更した`Plans.md`だけを自動コミットします。
  他のファイルは含めません。
  コミット失敗か`precompactAutoCommit: false`では従来どおり止めます。

### Fixed

- ファイル使用権は共有名札とローカル一覧で生存を確認します。
  別の作業ツリーの会話も60分の期限後に保護します。
  共有名札がなければ従来の判定へ戻ります。
  未完了タスクによる停止禁止は初回だけで、再入は警告して停止を許可します。
  調査会話が終了できない反復を直しました。

### Removed

- モデル候補からOpus 4.8を除きました。
  `HARNESS_BRAIN_MODEL=opus`と`opus5`はいずれもOpus 5を選びます。

## [5.3.1] - 2026-07-20

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#531---2026-07-20) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L912)

### Fixed

- 進捗と開始時の件数は実タスクのStatus欄を、大文字小文字を区別せず現在と旧表記で読みます。
  凡例、例、本文の言及による架空の作業中件数とずれ警告を直しました。

## [5.3.0] - 2026-07-19

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#530---2026-07-19) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L926)

### Changed

- 検証した実行手順についてCodex CLI、Cursor、Grokを正式対応にしました。
  能力が同じという主張ではありません。
  Cursorにはファイルシステムの隔離がなく、GrokはClaude形式の操作前制限、Codex CLIのBash制限はCodexアプリの同等性を示しません。
  Codexアプリ、OpenCode、Hermes、Copilot CLI、Antigravityは昇格しません。

### Added

- プロジェクトJSONの`runtimefloor.releaseAuto: true`で、版タグのpushと非破壊のGitHub公開操作を任意で許可できます。
  既定はOFFで、設定不在や解析失敗では拒否します。
  公開物の削除、npm公開、Vercel、Kubernetes、Terraformは拒否したままです。
  公開前は全配布先の実行検査を要求し、1つでも失敗すれば止めます。

### Fixed

- ベンチマークの20個の試験用プロジェクトでVitestを`^4.1.0`へ更新し、CVE-2026-47429に対応しました。
  provider-utilsの低危険度1件は上流未修正で残ります。
  最低版を検査します。

## [5.2.0] - 2026-07-17

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#520---2026-07-17) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L949)

### Added

- `harness release --check`は版を変更せず更新案を出します。
  最後の版タグから7日、Security項目があれば2日、Breaking見出しがあれば即時が条件です。
  終了コードは常に0です。
  開始時は候補だけを表示し、検査不能を候補なしの実証にしません。
- 独立した試験配線監査は追加だけを提案し、不服申立ては1回までです。
  書き込み後に、試験削除、`|| true`追加、`set +e`、判定条件の減少を警告します。
  操作は拒否しません。
  Hermes、LSP、公開能力の主張検査をCIへ接続しました。

### Changed

- 別リポジトリへの引継ぎをharness-memの作業記録に揃えました。
  版管理は6ファイルの7表記を扱う`scripts/sync-version.sh`を参照します。
  公開案はプラグイン名付きタグを数えず、Breaking Changes見出しも認識します。

### Fixed

- 各環境のビルドでGoをgo.mod指定に固定し、実行ファイルの版管理メタデータを除いて再生成検査と一致させます。
  追跡済みの調査7ファイルを再追加してもgitignoreで黙って除外しません。

## [5.1.0] - 2026-07-16

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#510---2026-07-16) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1013)

### Added

- 初期設定がMavenとGradleのJava、Kotlinを識別します。
  両方の目印があればJavaを優先し、対応する試験コマンドと命名を案内します。
- 対応区分を記録する一覧と構造検査を追加しました。
  Grokは`--check`付き初期設定、専用配布、振分けを持つ内部互換枠です。
  この版の公開上の正式対応はClaudeだけです。
  Hermesは手動リンクの候補で、初期設定、配布、モデル振分け、同等の操作制限はありません。
- 同じ識別子を繰り返し探す場合や複数モジュールの同型修正前に、構文構造の検索を使います。
  Harness MCPが接続されているTypeScriptとTSXの完了確認では言語サーバー診断を要求します。
  他の形式と未接続は止めません。
  参照先、定義、hoverの呼び出しは未接続です。
- 最初のGrok配布と振分けはgrok-4.5とgrok-composer-2.5-fastを指定しました。
  後続版で一覧の根拠を訂正しています。
  現在の導入手順として当時のIDを使わないでください。

### Fixed

- 完了報告は日本語指定がなければ英語を既定にします。
  Windowsでも作業中の停止検査を確実に行います。
  生成は明示した未対応ホストを飛ばし、途中生成後の失敗を防ぎます。
  公開タグはVERSIONと一致しないと公開しません。
- 公開雛形`.env.example`、`.env.template`、`.env.sample`、`.env.dist`は完全一致の名前だけ書き込みとステージを許可します。
  追加接尾辞、本物の秘密、秘密領域の入れ子、秘密を指すリンクは作業場所を変えたGitコマンドでも拒否します。
  対応済みの主張を部分的な但し書きで検査から隠せません。
- Codex版に必要な一覧補助処理を同梱し、Claude専用の役割フックと非同期フックを空の指定で上書きします。
  CodexとCursorの生成フックは対応するキーだけを使い、共有のコマンド検査と配信は保ちます。
  Cursor未設定は終了コード3です。
  案内と試験を出荷済みの内部互換区分に揃えました。

## [5.0.0] - 2026-07-08

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#500---2026-07-08) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1129)

### Breaking Changes

- スキル、フック、配布の再設計を4.x系から本流へ切り替えました。
  4.16.xから更新したら`/reload-plugins`を実行してください。

### Added

- 計画時に、秘密読み取り、外部送信、破壊操作を作業範囲ごとに事前確認します。
  未宣言の操作は止めます。
  実行判定への追加接続は後続版で行います。
  秘密の許可パスは`HARNESS_RUNTIME_FLOOR_SECRET_ALLOW`かJSONの`runtimefloor.secretAllow`で宣言します。
  全開放、不正設定、プロジェクト外の絶対パスは拒否します。
- `harness doctor`は7日以上古いかGitに未登録のHarness作業ツリーを警告します。
  起動処理は取得した1つの基準コミットから作業ツリーを作ります。
  掃除はHarness作業ツリーと対応ブランチだけを扱い、未保存変更があれば既定で飛ばします。
  削除にはforceが必要で、対象内からの実行は拒否します。
- 実行前の5制限は課金、外部通信、秘密読み取り、本番公開、作業ツリー外の破壊を対象にします。
  OS一時領域とキャッシュの掃除は範囲を限定して許可します。
  施工の前後で設定と認証情報の保存場所を比較し、範囲外書き込みで止めます。
  通常の実行キャッシュは対象外です。
  任意の自動許可には比較検査が実行可能であることを要求します。
- 並列作業の統合は、基準へ揃え、未コミットで取り込み、規約を検査してからコミットします。
  失敗時は作業ツリーを戻します。
  共有追記ファイルは担当を決め、作業ツリーで版を上げず、生成物は本流で1回再生成します。
- Failure Codifierは失敗から規則案を読み取り専用で出します。
  3回で確信度medium、5回でhighとし、正式採用は本人が行います。
  判断履歴は追記専用でプロジェクト別に保存し、文字一致で過去3件まで参照できます。
  どちらも規則を自動変更しません。
- Night Watchは既定OFF (`NIGHT_WATCH_ENABLED=false`)で、任意の導入が必要です。
  未解決反復、72時間停滞した作業、168時間未決の判断を報告します。
  作業の古さはファイル更新時刻で測ります。
  複製検査は一致、ずれ、未設定を分け、自動同期はOFFです。
- 引退した名前の一覧で移行残りを検査します。
  Breezingの自由文依頼を3〜7タスクへ分けて確認でき、Noなら実行しません。
  Claudeの高性能枠は`HARNESS_BRAIN_MODEL=fable`でFable 5を選べます。
  未指定はOpus 4.8、未知の値は失敗します。
- Cursorの実機で操作前拒否を確認し、Shell名をBashへ揃えました。
  対応区分は候補のままです。
  AppleScriptはアプリの表示と起動だけを許可し、System Eventsで入力を注入しません。
  標準機能一覧は観測済みと版未確認を分けます。
- 自己学習の導入計画を、出荷した機能と分けて記録しました。
  自動の規則昇格と承認はOFFです。
  外部施工と統合の結果を記録し、試行、失敗、完了を見分けます。
- `bin/harness wt fingerprint capture/diff`で監視した変更を確認できます。
  対象はClaudeの設定とプラグイン登録、認証領域の`~/.aws/`、`~/.ssh/`、`~/.gnupg/`、`~/.config/gcloud/`、`~/.netrc`です。
  通常のClaudeプロジェクト記録とキャッシュ書込は除外します。
  前後比較による検出で、OSのファイル隔離ではありません。
  比較コマンドが成功しなければ`HARNESS_AUTO_APPROVE=on`もOFFへ戻します。

### Changed

- 自己レビューを、同じモデル系列ではなく施工した会話状態の共有として定義しました。
  新しいCursor会話の助言を主判定前に使えますが、主判定は置き換えません。

### Fixed

- 公開スキルはタグ起動の処理へ公開を渡し、下書きでないGitHub Releaseと4個以上の添付物を検証します。
  セキュリティレビューは許可済み監査の範囲を明示し、隔離した新しいSonnet 4.6会話を使います。
  戻す内容を判定、件数、場所、修正方針に限定し、モデル保護による中断を減らします。
  無停止の保証ではありません。

## [4.16.4] - 2026-06-28

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4164---2026-06-28) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1241)

### Changed

- 許可リスト外のホストへ送るコマンド（`curl`、`wget`、`nc`、`scp`、`rsync`）は、実行のたびに確認が出ます。
  自分で見ている調査の会話では、この確認だけを外せます。
  Claude Codeの起動前に`HARNESS_RUNTIME_FLOOR_EGRESS=off`を設定します。
  起動するシェルで`export`するか、`~/.claude/settings.json`に`{ "env": { "HARNESS_RUNTIME_FLOOR_EGRESS": "off" } }`を書きます。
  外れるのは値が`off`のときだけで、未設定と他の値では確認が続きます。
  値は会話を起動した人のフック実行環境から読むため、隔離された施工役や指示を注入された施工役は変えられません。
  課金、秘密の読み取り、本番公開、作業ツリー外の破壊の確認は外せません。

## [4.16.3] - 2026-06-24

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4163---2026-06-24) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1267)

### Fixed

- 再読込したプラグインの配布とキャッシュに、直接呼ぶフックスクリプトを同梱します。
  不足する古いルートは使いません。
  Codexの`breezing --cursor`に補助スクリプトを含め、起動できるようにしました。
  推論量未指定時は既定を渡します。

## [4.16.2] - 2026-06-24

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4162---2026-06-24) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1291)

### Fixed

- 公開版にも実行前の安全確認を入れました。
  これまでは手元の試験版だけにありました。
  5種類の操作は必ず本人の確認に回り、`RUNTIME_FLOOR:<category>`と表示されます。
  対象は課金、外部への送信、秘密の読み取り、本番公開、作業ツリー外の削除です。
  この版では設定でも環境変数でも外せません。
  外部送信の確認だけは4.16.4から外せます。
  OSの一時領域とキャッシュ（`/tmp`、`/var/tmp`、`/private/tmp`、`$TMPDIR`、利用者のキャッシュ）の掃除は通します。
  `~/Desktop`、`~/Documents`、`/etc`、`/opt`での削除は引き続き確認します。
- `/harness-release`はタグを送った時点で終わります。
  GitHub Releaseの公開は、そのタグで動くGitHub Actions（`.github/workflows/release.yml`）が行います。
  Claude Code 2.1.183以降は公開コマンド自体を止めるためです。
  その後、5秒ごとに最大60回（約5分）、下書きでなく添付ファイルが4個以上ある公開物を確認します。
  時間切れはタグ送信済みのため失敗にせず警告にします。
  推定（確信度高、この版のスクリプトから）: タグで公開する処理がないプロジェクトでは公開物ができません。
  添付が4個未満のプロジェクトは、公開できていても警告で終わります。
- 秘密ファイルを明示してGitへ載せる操作を拒否します。
  対象コマンドは`git add`、`git stage`、`git commit <パス>`です。
  対象ファイルは`.env`、`.env.local`、`.env.production`、`*.pem`、`*.key`、`*.p12`、`*.pfx`、`id_rsa`、`id_ed25519`、`secrets/`、`.ssh/`、`.aws/`、`.npmrc`、`.pypirc`、`credentials`です。
  外部へ送ったGit履歴から秘密を除くには、通常は履歴の書き換えと強制更新が必要です。
  Harnessは強制pushの規則でこれを拒否します。
  他者が取得した写しまで消せる保証はありません。
  新しいコミットでファイルを消しても、古い履歴には残ります。
  コミット本文の文字（例: `-m "fix .env loading"`）はパスとして扱いません。
  一括の`git add .`と`git add -A`は許可したままで、`.gitignore`と既存の書き込み保護に任せます。
  `git -C <dir>`、`$(...)`、バッククォート、引用符、退避した引用符による隠し方も検査します。
- 日英の用語集`docs/onboarding/glossary.md`を加え、READMEの導入手順から開けます。
  生成物に出るspec（製品仕様）、contract（合意した条件）、`cc:完了`（完了して確認済み）、確信度%などを説明します。
  この版の確信度の目安は75%以上で進行、40〜74%で注意、40%未満で相談です。
  判断補助であり、成功確率の保証ではありません。

## [4.16.1] - 2026-06-19

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4161---2026-06-19) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1355)

### Fixed

- `/harness-review`と`/harness-release`内のレビューで出たAPPROVEを`.claude/state/review-result.json`へ保存します。
  これで次の`git commit`が「Run /harness-review before committing」で止まらなくなりました。
  判定役の終了時に動くフックでも保存し、判定役は読み取り専用のままです。
  `VERSION`、`.claude-plugin/plugin.json`、`harness.toml`、`CHANGELOG.md`だけを変えるコミットとマージでは承認を消費しません。
  そのため公開時の版更新コミットが通ります。
  判断は`.claude/state/commit-cleanup-audit.jsonl`に残します。
  Gitが使えないときは従来どおり承認を消します。
- スキル説明を短くして切り捨ての危険を減らしましたが、合計は6,000文字の目標を超えたままです。
  `docs/i18n.md`で出力言語の決め方を説明します。
  優先順は`.claude-code-harness.config.yaml`の`i18n.language`、`CLAUDE_CODE_HARNESS_LANG`、既定の英語です。
  会話ごとに頼むこともできます。
  機械用JSONとコミット接頭辞は英語のままです。
  セキュリティ判定は攻撃コードを書かずに事実だけを示します。
  モデル側の安全機能で判定役が途中で止まることは残ります。
  `docs/known-limitations.md`はOpus 4.8への切り替えか、セキュリティ中心の変更の人手レビューを勧めます。

## [4.16.0] - 2026-06-18

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4160---2026-06-18) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1393)

### Added

- `HARNESS_SESSION_RELAY=monitor|both`で会話間の個別連絡を有効にできます。
  既定OFFです。
  Claudeは5秒間隔で監視し、CursorとCodexは補助処理で引き継ぎます。
  本文はデータであり承認ではありません。
  即時配信はClaude間だけで、harness-loopと併用しません。
  waitingForの案内で10分超の作業停滞を見分けます。
  連絡はHarness内部（`.claude/sessions/relay-signals.jsonl`）に保存し、追加の道具は使いません。
  harness-memの伏せ字処理が効きます。

### Fixed

- 新規設定でharness.tomlを作り、既存ファイルや別プラグインの宣言を上書きしません。
  同期先もない場合だけフック不在を飛ばし、同期先だけ残る場合は失敗します。
  Windowsの記憶コマンドはJavaScriptを実行環境経由で起動します。
  末尾表示は選択言語に従います。
  `setup-codex.sh --project`がプロジェクトへ写す`AGENTS.md`を直しました。
  Codexはフックに対応済みで、Harnessは当時未配線、暫定の保護は`.codex/rules/`と書きます。
  推定（確信度中）: この版より前に写した複製は、写し直すまで「フック未対応」の記述が残ります。
  Cursorの根拠文書を内部互換区分へ揃えました。

## [4.15.0] - 2026-06-05

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4150---2026-06-05) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1447)

### Added

- 「施工役は自分を縛る設定を書き換えられない」という約束の正本を`harness.toml`に置きました。
  配布する`.claude-plugin/settings.json`へ4件の拒否規則として写します。
  対象は`.claude/settings*`と`.claude-plugin/settings*`への`Edit`（部分編集）と`Write`（ファイル書き込み）です。
  4件のどれかが欠けるとCI（変更を自動検査する処理）が失敗します。
  後の5.7.0の記録は、Claude Codeがプラグインの`.claude-plugin/settings.json`の`permissions`を読まないとしています。
  当時の実行環境は再試験していません。
  [現在のプラグイン設定の公式仕様](https://code.claude.com/docs/en/plugins-reference#settings)で適用されるのは、`agent`（既定の担当）と`subagentStatusLine`（施工役の状態表示）だけです。
  ファイルに規則があるだけでは、当時の保護が効いた証拠になりません。
  拒否規則を適用するには、本人の利用者設定かプロジェクト設定に書きます。
- `/harness-review`と診断の会話で使う自己監査に項目を加えました。
  `.claude/settings.local.json`の`hooks`を読み、持ち主が意図しない`command`型フックを指摘します。
  このファイルは通常Git管理外で、コードレビューを通らないためです。
  監査を実行したときの検査であり、常時の監視ではありません。

### Changed

- `.claude-plugin/settings.json`と`.claude/settings.local.json`への書き込みを、保護パスの警告に分類しました。
  `.claude-plugin/plugin.json`と同じ扱いです。
  シェルのリダイレクトのように拒否規則をすり抜ける経路への警告になります。

### Fixed

- 委譲の累計へ会話途中の記録も含め、開始と終了の間の取りこぼしを直しました。

## [4.14.0] - 2026-06-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4140---2026-06-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1491)

### Added

- CodexとCursorへの委譲を`.claude/state/orchestration-ledger.jsonl`へ1行ずつ記録します。
  項目は委譲先、操作、書き込みの有無、終了コード、所要時間、セッションIDです。
  依頼の本文と秘密は記録しません。
  状態確認や設定確認の問い合わせは数えません。
  プロジェクトごとの累計は`orchestration-totals.json`に残します。
  `harness-orchestration`スキルで共有できるHTMLの集計表を作れます。
  各委譲先は利用中、設定済み未使用、未設定のどれかで示し、未設定は異常扱いしません。
  全作業の完了時に端末へ1回だけ要約を出します。
  実行量の指標であり、品質や完了の証明ではありません。

## [4.13.3] - 2026-06-01

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4133---2026-06-01) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1517)

### Fixed

- Cursorの初回利用で、補助ファイル探索、前提条件、作業ツリー統合、失敗表示を修理しました。
  同じPCのファイル使用権、会話登録、編集衝突の通知、Go、Markdown、シェルの全員通知を復旧しました。
  協調の助言であり強制ロックではありません。
  別の複製とPCには共有せず、通知は追記で増えます。
  受信文を整え、データとして扱います。
- Cursorが変更を未コミットで残した場合、リーダーが作業ツリー内で1コミットにまとめてから取り込みます。
  このコミットでは`--no-verify`でフックを飛ばし、本流側のコミットで通常の保護とpre-commitを通します。
  コミット文は`TASK_SUMMARY`を設定すれば使い、なければ`cursor: cursor-do delegated change`です。
  補助スクリプトは`CLAUDE_PLUGIN_ROOT`、`HARNESS_PLUGIN_ROOT`、`CLAUDE_PROJECT_DIR`、現在のフォルダ、導入済みプラグインの順で探します。
  見つからなければ終了コード2で止まります。
  作業ツリーのパスはGitルートからの絶対パスです。
  使用権は同じリポジトリの作業ツリー間で共有します。
  60分経過と持ち主の登録消失の両方で失効し、24時間を超えた登録は整理します。
  Git管理外か使用権の保存先に届かないときは、使用権なし、警告なしで編集が進みます。
  受信はパス、送信者、経過時間だけを4,096バイト以内で渡し、通知の文章は捨てます。

### Changed

- BreezingとCursor委譲は、開始表示と2〜4段の予定を合計5行以内で示し、途中結果も短く伝えます。
  開始1行だけで黙る挙動を改めました。

## [4.13.2] - 2026-05-30

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4132---2026-05-30) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1616)

### Added

- `/cursor:ask`は質問、調査、設計の相談を読み取り専用でCursor（composer-2.5-fast）へ渡します。
  答えはClaudeが3〜5行に要約します。
  `/cursor:do`は1件の書き込み作業を、専用の作業ツリー（`.claude/worktrees/cursor-do-<id>`）でCursorへ渡します。
  リーダーが差分を確認して取り込み、Plans.mdの作業を`cc:done [hash]`（完了と保存した変更の識別値）にします。
  どちらも事前設定が必要です。
  `.cursorignore`で`.env`、`*.pem`、`*.key`、`.ssh`、`.aws`、`.git`を隠します。
  `~/.claude/settings.json`の`sandbox.network.allowedDomains`に`*.cursor.sh`、`sandbox.filesystem.allowWrite`に`~/.cursor`を加えます。
  Cursor自体はファイル書き込みを特定フォルダに閉じ込められません。
  書き込みの安全は、専用作業ツリー、リーダーの差分確認、Harnessの保護を通る取り込みで保ちます。

### Changed

- `/harness-review --cursor`は、Cursorを助言の別意見として加えます。
  判定は主レビューが決めます。
  主レビューがREQUEST_CHANGES（要修正）なら差し戻しです。
  主レビューがAPPROVE（承認）ならCursorが反対しても承認のままで、食い違いを記録します。
  `--dual --cursor`でClaude、Codex、Cursorの3者が見ます。
  `/breezing --cursor --reviewer-only`はレビューだけをCursorへ回します。
  Anthropicの利用制限やCodexレビューの認証失敗のときに使います。
- Opus 4.8向けに指示を調整しました。
  深い推論は「ultrathink」の文字ではなく推論量で指定します。
  複雑さの点数が3以上なら`high`、コードのリスクを含めば`xhigh`です。
  レビューは判定前に全指摘を重大度と確信度付きで記録します。
  並列施工役の起動条件を明示しました。
  相談役はOpus 4.8へ変えました。
  施工役と判定役はSonnet 4.6のままです。
  開始表示を短くし、4.13.3で緩めました。
- 配布先ごとに内部のスキルパスを使い、他の配布先の情報を含めません。
  Cursorへの導入は`scripts/setup-cursor.sh`で実フォルダを写します。
  `~/.cursor/plugins/local`へのリンクはCursorが拒否するためです。
  `scripts/setup-cursor.sh --check`は配布物を作って検査するだけで、導入しません。
  HarnessのワークフロースキルをCursorで隠さずスキルとして表示します。
  Cursorは内部互換で、公開上の正式対応ではありません。
  `scripts/diagnose-harness-skill-duplication.sh`は重複したHarnessスキルを削除せずに一覧します。
  掃除の手順は`docs/local-harness-environment-cleanup.md`にあります。

### Removed

- 呼び出し先のない雛形生成役を外しました。
  初期設定と計画がその作業を直接続けます。

### Fixed

- Gitのフックと署名を省くフラグを、シェル区切りと隣接しても検出します。
  古いharness.tomlからplugin.jsonの版を戻す問題も直しました。

## [4.13.1] - 2026-05-29

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4131---2026-05-29) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1679)

### Changed

- Claude以外の施工は、追加のClaude施工役を起動せずCodexかCursorへ直接渡します。
  取り込む前にリーダーは差分に加え、公開主張、整合性、プラグイン契約の検査を行います。

## [4.13.0] - 2026-05-29

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4130---2026-05-29) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1686)

### Added

- `scripts/set-impl-backend.sh [--user] <claude|codex|cursor>`で施工先を選べます。
  `/breezing`と`/harness-work`の施工がその先へ渡ります。
  優先順はコマンドの指定、`HARNESS_IMPL_BACKEND`、プロジェクトの`env.local`、本人用の`~/.config/claude-harness/impl-backend.env`、最後にClaudeです。
  判定と相談は常にClaudeに残し、選んだ施工先には渡しません。
  施工先が自分の作業を判定しないためです。
  スキル本文はOpusと書きますが、この版の判定役定義はSonnet 4.6でした。
  Cursorはローカルで任意に使う候補です。
  出力は信用せず、専用作業ツリー、リーダーの差分確認、取り込みを通してだけ入れます。
  読み取りの委譲はaskモードで、全自動実行（`--force`）は使いません。
  `--debug`か`HARNESS_CURSOR_DEBUG=1`で、コマンドとエラーを標準エラーに出します。
  `--api-key`、`--auth-token`、`Authorization:`の値は伏せます。

### Changed

- 作業全体の委譲にCursor ACPの逐次通信は採用しません。
  逐次表示、別IDEへの埋込、操作ごとの権限が必要になったら再評価します。
  シェルの整理は挙動を変えません。

## [4.12.11] - 2026-05-28

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#41211---2026-05-28) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1704)

### Changed

- Cursor候補の配布、振分け根拠、静的検査を追加しました。
  公開上の対応には実行手順の観測が必要で、同等の操作制限は主張しません。

## [4.12.10] - 2026-05-28

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#41210---2026-05-28) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1724)

### Fixed

- 公開の完了条件を、既定ブランチへの反映と、そこから到達できるコミットにタグと公開物があることへ揃えました。

## [4.12.9] - 2026-05-28

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4129---2026-05-28) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1730)

### Changed

- Claude 2.1.143〜152とCodex 0.131〜134の禁止操作、スキル再読込、メッセージ表示、Codexプロファイルを案内しました。
  標準Autoモードの同意変更でもHarnessの任意選択と拒否の既定は変えません。

## [4.12.8] - 2026-05-27

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4128---2026-05-27) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1736)

### Changed

- 単純でない計画は、確定前に独立した応援へ相談します。
  軽い作業の例外と相談の根拠を計画に残し、日英の案内に条件を記載しました。
- 計画で仕様とタスクの整合、過去記憶、製品価値、安全性、実際に動く条件を確認します。
  秘密の値は読みません。

## [4.12.7] - 2026-05-27

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4127---2026-05-27) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1748)

### Fixed

- Harness自身の公開前検査で、自リポジトリのブランチ保護がレビュー条件からずれていないか確認します。

## [4.12.6] - 2026-05-27

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4126---2026-05-27) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1755)

### Changed

- CodeQLの脆弱性検査をmainへの各pushと変更提案で実行します。

### Fixed

- TOML解析の異常入力試験を継続し、配布検査で全対象プラットフォームのフック実行ファイルを要求します。

### Security

- 簡易導入とCodex更新の案内で、任意のツールを自動で全体へ入れる代替経路を廃止しました。
  この経路は版を固定しない`npm install -g`による導入と更新でした。
  任意の開発ツールはHomebrewか、版を指定したパッケージ管理コマンドで入れます。
  意図した実行ファイル配布と、セキュリティ報告、ブランチ保護の判断を記録します。

## [4.12.5] - 2026-05-27

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4125---2026-05-27) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1781)

### Fixed

- Breezingのagent-eval依存を修正し、残るDependabotの脆弱性指摘に対応しました。
- ベンチマークのundici、minimatch、uuidを修正版へ揃え、試行タスクは追跡済みの評価対象を指します。

### Security

- 当該ベンチマークへ範囲を絞ったnpm更新と監査を追加しました。
  使い捨ての試験用プロジェクトへ大量の更新提案は登録しません。

## [4.12.4] - 2026-05-27

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4124---2026-05-27) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1796)

### Added

- SECURITY.mdに非公開の脆弱性報告先と、公開問題票での扱いを記載しました。

### Fixed

- 英語を既定へ戻しました。
  依頼、`i18n.language: ja`、`CLAUDE_CODE_HARNESS_LANG=ja`で日本語を選べます。

### Security

- 証拠のラベルで絶対パス、親参照、入れ子、単純な名前以外を拒否します。
  試験パスはシェルのコードではなく引数で渡します。
  YAMLのパスもPythonの本文に埋め込まず引数で渡します。

## [4.12.3] - 2026-05-25

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4123---2026-05-25) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1812)

### Changed

- 新しいタスク行は`pm:requested`、`cc:todo`、`cc:wip`、`cc:done`、`pm:approved`を使います。
  既存の日本語と大文字の表記は読めるままで、明示した移行なしに全体を書き換えません。

### Fixed

- 公開時の版同期にCodexの宣言を含めました。
  保護理由は英語を既定に日本語を選べます。
  環境ファイル例外と孤立した反復実行の回収は検査済みの挙動を保ちます。

## [4.12.2] - 2026-05-24

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4122---2026-05-24) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1830)

### Fixed

- README検査をCursor導線、5つの基本操作、Goの保護処理、日本語の任意選択に揃えました。

## [4.12.1] - 2026-05-24

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4121---2026-05-24) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1836)

### Changed

- 日英READMEを導入、実行手順、対応範囲、移行から読めるようにし、承認した図を使います。
  計画はspec.mdの製品仕様とPlans.mdの作業一覧を両方作り、仕様の変更か省く理由を残します。
  仕様を優先します。

## [4.12.0] - 2026-05-23

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4120---2026-05-23) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1845)

### Added

- 利用するCLIから導入手順を選べます。
  Claude、Codex CLI、OpenCodeの初期設定と対応限界を分けました。
  既存利用者は変更前に読み取り専用の移行報告を見ます。
  健全性、配布、公開の検査で配布内容を確認し、HTMLに統合と公開の判断根拠を残します。
  入口は`docs/onboarding/index.md`です。
- この版はClaudeが正式対応、Codex CLIとOpenCodeが内部互換、Codexアプリ、Cursor、Copilot CLIが候補、Antigravityは未対応です。
  `harness doctor --migration-report`で古いキャッシュ、操作不足、重複、リンク、バックアップ、記憶を削除せず調べます。
  OpenCodeの実環境同等性は未観測です。
  `release-preflight.sh --check-adapters`で保存状態、接続、複製、配布、能力、初期設定、CIを検査します。

## [4.11.4] - 2026-05-21

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4114---2026-05-21) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1889)

### Added

- 通信先制限の手動手順は`docs/sandbox-allowlist-recipe.md`です。
  `HTTP/2 403 / x-deny-reason: host_not_allowed`（隔離環境で接続先を許可していないエラー）を説明します。
  許可29ドメイン、拒否9ドメイン、除外6コマンドを案内します。
  `templates/sandbox-settings.json.template`も同じ内容にしました。
  以前は8ドメインで、`git clone`、`pip`、`go mod`、`cargo`が失敗し得ました。
- テンプレートの丸写しは、`~/.claude/settings.json`に`sandbox`キーがないとき限定です。
  `jq 'has("sandbox")' ~/.claude/settings.json`で確認します。
  既存なら内容を合併し、`filesystem`（ファイルアクセスの規則）と`failIfUnavailable`（隔離できないとき停止する設定）を保ちます。
  設定をバックアップし、配列を合併してファイル権限を保ちます。
  ホストの完全一致を検査し、Claudeを完全再起動します。
  新規設定は許可がちょうど29件、拒否がちょうど9件です。合併ではそれ以上になります。
  Firecrawlは`FIRECRAWL_API_KEY`が別途必要です。
  この本人設定を役割は自己編集しません。
- 拒否9ドメインはクラウドのmetadata endpoint（内部サービスの情報取得先）と貼り付けサイトです。
  SSRF（内部クラウドサービスへの不正なリクエスト）と情報流出の経路を塞ぎます。
  `allowedDomains`に入っていても、`deniedDomains`が優先して拒否します。


## [4.11.3] - 2026-05-19

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4113---2026-05-19) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L1993)

### Changed

- `/harness-release`と`/harness-review`の最後に、固定の1行を出します。
  内容は「↑この結果は Claude が要約します。Enter キーで次へ進むか、新規 prompt で別の指示を出してください。」です。
  スラッシュ操作の結果が止まったように見える問題への対策です。
  この版では常に日本語で、4.16.0から言語設定に従います。
  他のスキルは変わりません。

## [4.11.2] - 2026-05-19

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4112---2026-05-19) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2035)

### Fixed

- 引数なしの公開依頼で、既定対象を示して着手します。
  追加指示待ちで黙る問題を直しました。
  保護検査と承認条件は保ちます。

## [4.11.1] - 2026-05-18

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4111---2026-05-18) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2073)

### Fixed

- `/harness-review`と`/ci`がスキル一覧に戻り、起動後に黙って止まらなくなりました。
  危険な副作用を持つスキル専用の設定が、両者の起動を止めていました。
  引数なしの`/harness-review`は`REVIEW_AUTOSTART:`の行を出して始めます。
  その設定を使う条件と、黙るスキルの診断手順を案内しました。

## [4.11.0] - 2026-05-18

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4110---2026-05-18) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2111)

### Added

- TOMLの`[[safety.guardrail.protectedPathAskList]]`で環境ファイルへのシェル書き込みを完全一致で確認扱いにできます。
  理由は必須で記録します。
  許可への変更ではありません。
  直接編集、秘密と鍵、Git内部、フック、シェル設定、外部パス、拒否対象を混ぜた書き込みは拒否します。
  検出はリダイレクトとteeだけで、sedの直接書換は対象外です。
  任意のローカルスキル複製も検査します。
- CIでLinux、macOS、Windowsをビルドして検査します。
  自動処理の依存をコミットへ固定し、週次更新に7日の待機期間を設けます。
  CodeQL、Scorecard、構文検査で公開の証拠を増やします。
  別製品としての全CLI対応は主張しません。
- 背景で動く会話の端末通知を任意で選べます。
  `HARNESS_TERMINAL_NOTIFY=1`か`bell`でベル、`title`で窓の題名、`osc9`でmacOSとiTermの通知、`notify`でLinuxのデスクトップ通知です。
  未設定と`0`は無表示です。
  `HARNESS_WEBHOOK_URL`がなくても使えます。
  標準の`/goal`は短い継続メモとし、受け入れ条件はPlans.mdに置きます。
  Harnessの安全設定の雛形`templates/claude/settings.security.json.template`に2つの基準を加えました。
  使うには本人の設定へ写します。
  `worktree.baseRef: "fresh"`は新しい作業ツリーを`origin/<既定ブランチ>`から作り、未送信のコミットを持ち込みません。
  持ち込みたい場合はプロジェクト設定で`head`を選びます。
  `autoMode.hard_deny`の7件はAutoモードでも拒否します。
  `Bash(sudo:*)`、`Bash(rm -rf:*)`、`Bash(rm -fr:*)`、`Bash(git push -f:*)`、`Bash(git push --force:*)`、`Bash(git reset --hard:*)`、`mcp__codex__*`です。
  保護ブランチ、認証情報、本番配備では`claude agents --dangerously-skip-permissions`を使わない方針にしました。

### Changed

- レビューを既定で読み取り専用にし、軽い`--quick`と`--codex-closeout`を用意しました。
  コミット、push、公開は施工と公開の手順で行います。
  自動処理は最小権限とし、取得用トークンを残しません。
  古い変更検査は中止しますが、公開とベンチマークは完走させます。

### Fixed

- 公開配布からローカル情報、非公開の開発スキル、別CLIの複製、試験用データ、隔離設定の例を除外します。
  OpenCodeの名前と設定項目を対応形式に揃えました。

## [4.10.0] - 2026-05-12

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#4100---2026-05-12) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2292)

### Added

- 名前付きの複数計画を使えます。
  `plans/manifest.json`に`default`と追加の計画を登録し、`--plan NAME`で選びます。
  最後の選択は`.claude/state/active-plan.json`に残ります。
  単一の`Plans.md`（`plans.md`、`PLANS.md`も可）なら変更は不要です。
  登録パスはプロジェクトルートからの相対だけです。
  絶対パス、`..`、リポジトリ外へのリンクは拒否します。
  長時間実行、CI、問題票連携は保存した選択に頼らず`--plan NAME`を付けます。
  テスト先行の強制はローカル任意の試用で、全体の既定にはしません。
  製品仕様と作業台帳を分けます。

### Fixed

- `harness codex-loop start`は実行役が即座に落ちると`startup_failed`で失敗し、0以外で終わって実行ログの末尾を残します。
  孤立した作業は`runner_lost_job_running`と表示し、停止と異常終了で中止します。
  作業ツリーフックはJSON形式の作業場所を受け付けません。
  通知は表示済みを既読にして日付を示し、古い作業場所を飛ばします。
  タグ作成前に複製のずれを検査します。
  Codex 0.130.0の案内に版の根拠を残します。

## [4.9.0] - 2026-05-10

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#490---2026-05-10) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2333)

### Added

- 非エンジニア向けに1枚のHTMLを3種類加えました。
  `/harness-plan-brief`は着手前に、Claudeの理解、選択肢、リスク、受け入れ条件、根拠付きの確信度（0〜100）を示します。
  本人の判断は依頼文のSHA-256ハッシュ（依頼を照合するために計算した識別値）と一緒に記録します。
  `/harness-accept`は出荷、待機、却下を示します。
  確認済みの条件が80%以上なら出荷、50%以上なら待機、50%未満か確認済みが0件なら却下です。
  `/harness-progress`は進捗%、作業中、直近完了5件、未着手5件、5種類の警告（範囲の膨張、時間超過、失敗の繰り返し、費用、高リスクファイル）を示します。
  進捗ページはWrite、Edit、MultiEdit、Bashの後に最短60秒間隔で自動更新します。
  このフックはプラグインの既定で有効です。
  計画概要と受け入れは同じ依頼ハッシュで結びます。
  各ページの末尾に根拠の欄があります。
- 別プロジェクトの記憶検索は、実行ごとに`--cross-project-group <name>`を付けたときだけ使えます。
  グループは`.claude/rules/cross-project-groups.yaml`、伏せ字の辞書は`.claude/rules/client-redaction.yaml`に書きます。
  伏せ字は段階的に行います。
  記憶サーバーが`<private>`の内容を除いてプロジェクト範囲で絞り、次に辞書、日本語の固有名詞処理、HTML作成直前の最終検査を通します。
  最終検査でカタカナが5文字以上続くとHTMLを作らず終了コード1で止まります。
  検索は`.claude/state/audit/cross-project-search.jsonl`に記録し、検索文そのものではなくハッシュだけを残します。
  決めた形式での検査であり、個人情報保護全般の保証ではありません。
  辞書にない表記や別の文字種の名前は通る場合があります。

## [4.8.1] - 2026-05-09

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#481---2026-05-09) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2436)

### Fixed

- 計画検査が追跡する退避履歴を読めます。
  完了作業を現行計画に置き続ける必要はありません。
  通信拒否一覧の正本をharness.tomlに揃え、生成設定のずれを同期時に警告します。

### Security

- `be2a1781`以降、会話開始時の同期が6件の投稿サイトへの通信拒否を設定から消していた不具合を修正しました。
  `pastebin.com`、`transfer.sh`、`0x0.st`、`paste.ee`、`termbin.com`、`ix.io`の拒否を`harness.toml`に揃え、同期しても維持します。

このネットワーク設定は当時`harness.toml`からプラグイン設定へ出力したもので、当時の本体での実効性は再検証していません。
  [現在の公式仕様](https://code.claude.com/docs/en/plugins-reference#settings)でプラグイン設定に効くのは`agent`と`subagentStatusLine`だけなので、通信拒否一覧は本人の利用者設定かプロジェクト設定へ写してください。

## [4.8.0] - 2026-05-08

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#480---2026-05-08) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2492)

### Changed

- Claude Code 2.1.112〜2.1.132への追従です。
  MCPツール型フック（外部の道具を直接呼ぶ処理、`type: "mcp_tool"`）は当面採用しません。
  既存のシェル経由のフックを使い続けます。
  記憶MCPの正式公開、包み処理の遅延の計測、Claude Codeの認証案内が出たら再評価します。
  フックが見る推論量で保護を緩めることはありません。
  フックはセッションIDを入力JSONから読み、BashコマンドはClaude Codeの`CLAUDE_CODE_SESSION_ID`を使えます。
  強制push、hard reset、保護ブランチへのpushの検査は、`env`、`sudo`、`watch`で包んでも止まることを確認しました。

### Added

- 止まった施工役の再起動は1回までです。
  作業中が10分を超えるか停滞ログが出たときが条件です。
  30分を超える会話では、Claude Codeを`ENABLE_PROMPT_CACHING_1H=1`付きで起動すると1時間キャッシュを使えます。
  これはClaude Code側の機能です。
- 出力の伏せ字処理は任意で、`HARNESS_OUTPUT_GOVERNANCE_ENABLE=1`がない限り動きません。
  置き換えるのは、`sk-`の後に英数字が20文字以上続くキーです。
  `sk-ant-`の後に英数字かハイフンが20文字以上続くキーも対象です。
  Read、Grep、Glob、TodoWrite、Bashの出力は対象外です。
  そのためコマンドの表示やファイル内のキーは伏せられません。
  記録ファイル`.claude/state/output-audit.jsonl`は伏せる前の文章も残します。
  このファイル自体にキーが入るため、保護か削除が必要です。
- スキル起動の記録は`.claude/state/skill-trigger-stats.jsonl`にだけ保存し、セッションIDは先頭12文字にします。
  `HARNESS_SKILL_TELEMETRY_DISABLE=1`で止まります。
- 通信拒否の雛形`templates/claude/settings.security.json.template`に投稿サイト6件を加え、3件から9件にしました。
  追加は`pastebin.com`、`transfer.sh`、`0x0.st`、`paste.ee`、`termbin.com`、`ix.io`です。
  雛形なので、本人が`sandbox.network.deniedDomains`へ写すまで何も変わりません。
  原文は`.claude-plugin/settings.json`への追記を案内していました。
  後の5.7.0の記録は、このプラグイン設定の`permissions`を読まないとしています。
  当時の実行環境は再試験していません。
  [現在のプラグイン設定の公式仕様](https://code.claude.com/docs/en/plugins-reference#settings)で適用されるのは、`agent`（既定の担当）と`subagentStatusLine`（施工役の状態表示）だけです。
  `sandbox`は対象外なので、通信拒否の項目は利用者設定かプロジェクト設定へ書いて適用します。
  `skillOverrides`の既定は未設定です。
  組織には`name-only`、教育には`user-invocable-only`を勧めます。

## [4.7.0] - 2026-05-06

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#470---2026-05-06) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2577)

### Added

- `harness mem status|setup|update|doctor|off|purge`で記憶機能を管理できます。
  所有範囲と安全な削除条件を定めました。
  証拠不足、形だけの合格、試験省略、再現のない修正を、情報の扱いを付けてローカルに追記します。

### Changed

- プラグインの`Setup:init`は既定で、Claude CodeとCodex向けに記憶の初期設定を1回試します。
  作業は止めません。
  SessionStartでは導入しません。
  `CLAUDE_CODE_HARNESS_MEM_AUTO_SETUP=0`で試行を止められます。
  相談役は、過去の証拠不足の記録から短い手掛かりを読めます。
  その記録はまずローカルに書き、可能な範囲でharness-memへ送ります。
  記憶の内部は読みません。
  相談役の答えはPLAN（計画）、CORRECTION（修正）、STOP（停止）のままです。

## [4.6.1] - 2026-05-05

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#461---2026-05-05) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2589)

### Fixed

- OpenCode生成へBreezingを含め、スキル複製と一致させました。

## [4.6.0] - 2026-05-05

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#460---2026-05-05) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2595)

### Added

- タグ前に版ファイルと宣言を構造的に検査します。
  開発者向けにGo中心の実装案内と機械可読のスキル設計情報を追加し、Claude、Codex、OpenCodeで検査します。

### Changed

- Codex手順を標準の応援APIへ揃えました。
  メディアと告知は明示した手動起動が必要です。
  重い実行詳細を参照先へ移し、入口と停止条件は残します。
  更新したスキル複製を揃えました。

### Fixed

- 反復処理の補助ファイルを利用先ではなくプラグインで探します。
  レビューリンク、配布版のずれ、未追跡ファイル検査、未対応の役割項目、文書配置、実行ファイルとライブラリの識別、雛形の重複誤検知を直しました。
  役割の安全性は無視される設定欄ではなく、フック、Go検査、起動前確認で保ちます。

## [4.5.4] - 2026-05-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#454---2026-05-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2623)

### Fixed

- 新しい複製の言語と宣言検査は公開追跡ファイルだけを使い、個人のローカルスキルを要求しません。

## [4.5.3] - 2026-05-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#453---2026-05-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2629)

### Fixed

- キャッシュ同期を追跡済みの宣言領域だけに限定し、古い非公開内容とOS情報を除きます。
  公開補助処理は追跡bin外でビルドし、既存添付物を保ちます。
  ローカルの上流調査とメディア用メモは公開配布しません。

## [4.5.2] - 2026-05-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#452---2026-05-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2637)

### Changed

- 基本作業のスキルは見つけられるままです。
  広い内部補助の自動読込を止め、明示した利用は残します。
  基本以外も含めて複製を検査します。

### Fixed

- 毎ターンの規則二重挿入と、施工役のレビュー先読みを外しました。
  キャッシュ修理でスキルと出力形式を残し、有効なプラグインを読み込めるようにします。

## [4.5.1] - 2026-05-03

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#451---2026-05-03) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2650)

### Changed

- 機密パスを拒否、確認、警告に分け、動作設定、秘密、フック、導入情報を個別に扱います。
  Codex 0.125と0.128の権限設定、通信方針、記録の限界、更新、旧full-auto限定の案内を加えました。

## [4.5.0] - 2026-05-03

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#450---2026-05-03) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2657)

### Changed

- `main`と`master`への直接pushを拒否から確認へ変えました。
  `.claude-code-harness.config.yaml`の`safety.protected_branch_push`か、`harness.toml`の`protectedBranchPush`で`ask`（確認）、`deny`（拒否）、`allow`（許可）を選べます。

### Fixed

- WindowsのGit Bash、MSYS、Cygwinで入口から.exeを解決し、作業ツリーパスを正しく作ります。
  JSON形式の作業場所は拒否します。
  UnixのflockがないWindowsでは場所に応じてmkdirかロックなしへ戻ります。
  WindowsのBreezingが、実行ファイルか作業ツリーのパスを見つけられずSoloモードへ戻る問題も直りました。

### Added

- Claude 2.1.120〜126とCodex 0.125、0.128の差分を記録し、Windows作業ツリーの回帰検査を追加しました。

## [4.4.0] - 2026-04-26

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#440---2026-04-26) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2685)

### Added

- Codex Breezingの既定と反復の一括実行を加え、Claude 2.1.116〜119、Codex 0.123〜124へ追従しました。
  updatedInput.answersで回答を渡せます。
  未対応と試験版の能力は提案に留め、推測で実装済みにしません。

### Fixed

- 反復開始が`6G-6`などの見出しID、`Plans.md:546`、範囲を受け付けます。
  絶対スクリプトパスで起動し、実際の失敗コードとログを保って停止時に子作業を終了します。
  導入は現行リンクを保ち、古いリンクを元ファイルごと移動せず退避し、同名バックアップの衝突を防ぎます。
- 環境情報がない場合もフックはプラグインルートを検証します。
  キャッシュ同期で配布先パスを修理し、画面以外の契約は未使用欄をnullで残さず省いて公開検査の誤失敗を防ぎます。

### Security

- 通信拒否一覧`sandbox.network.deniedDomains`にクラウドのmetadata endpoint（サービスの認証情報などを返す宛先）を加えました。
  危険な削除を確認するR05は、`find -delete`、`find -exec rm`、macOSの`/private/etc`、`/private/var`、`/private/tmp`、`/private/home`、`~/Library`も対象にします。

このネットワーク設定は当時`harness.toml`からプラグイン設定へ出力したもので、当時の本体での実効性は再検証していません。
  [現在の公式仕様](https://code.claude.com/docs/en/plugins-reference#settings)でプラグイン設定に効くのは`agent`と`subagentStatusLine`だけなので、通信拒否一覧は本人の利用者設定かプロジェクト設定へ写してください。

## [4.3.3] - 2026-04-20

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#433---2026-04-20) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2815)

### Fixed

- harness-mem未導入（`~/.claude-mem/`がない）の場合、会話開始ごとの`harness-mem unhealthy`警告を出さず終了コード0です。
  導入済みで到達不能か破損した場合は終了コード1と警告を保ちます。

## [4.3.2] - 2026-04-20

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#432---2026-04-20) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2871)

### Fixed

- 会話のずれ検査で末尾の有限領域を使います。
  記憶フックのnull安全な試験と、移行例外の絞り込みで内部検査を直しました。
  利用手順は変えません。

## [4.3.1] - 2026-04-19

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#431---2026-04-19) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L2922)

### Added

- 会話の監視が3つの点を1行ずつ警告します。
  記憶の健全性は`~/.claude-mem/`を確認し、記憶の常駐処理`HARNESS_MEM_HOST:HARNESS_MEM_PORT`（既定`127.0.0.1:37888`）へ接続します。
  相談役と判定役の未回答は、既定600秒を超えたら知らせます。
  `orchestration.advisor_ttl_seconds`で変えられます。
  計画のずれは、作業中が5件以上かPlans.mdが24時間変わらないときに知らせます。
  `monitor.plans_drift.wip_threshold`と`monitor.plans_drift.stale_hours`で変えられます。
  3つとも`.claude-code-harness.config.yaml`に書きます。
  健全性の確認はプラグインかPATHの`harness`を使い、プロジェクト内の`bin/`は使いません。
  リポジトリに仕込まれた実行ファイルに置き換えられないためです。

### Fixed

- 新規と再開の会話で、最初の入力時にharness-memから前回の要約を渡します。
  処理は同梱されていましたが、つながっていませんでした。
  harness-memの常駐処理が動き、`curl`と`jq`が入っている必要があります。
  記憶が未設定か到達不能なら静かに飛ばし、他のフックは続きます。

## [4.3.0] - 2026-04-19

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#430---2026-04-19) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3000)

### Fixed

- 引数なしの`/harness-review`は自動で始まり、`REVIEW_AUTOSTART:`の行を出します。
  施工役はPlans.mdの状態表記を変えられません。
  `cc:`表記を書き換えるWriteとEditはフックが拒否します。
  作業ツリー内への別リポジトリの複製と、相談役の直接起動もできず、助言はリーダーが中継します。
  施工役は根拠付きの自己検査5項目を提出します。
  不足があればリーダーが最大2回差し戻し、その後は上へ上げます。
  規則は`harness.toml`の`[worker.self_review]`で設定します。
  共通の指摘は同じ`/breezing`の次の施工役へ渡し、終了時に捨てます。
  レビュー上限を3から10へ増やし、プロジェクトごとに変えられます。
  Codexの判定が詰まるとリーダーが引き継げます。

## [4.2.0] - 2026-04-18

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#420---2026-04-18) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3046)

### Added

- 会話圧縮（履歴の要約）は、長時間の施工役が実行中か、`Plans.md`に未コミット変更があるときに止めます。
  判定役と相談役の会話は止めません。
  サブディレクトリからの起動と`plansDirectory`（計画の保存先指定）にも対応します。
- プラグインを有効にすると`harness-session-monitor`が自動で始まります。
  作業ツリー（独立した作業用の複製）内でもブランチと最終コミットを正しく記録します。
- prompt cache（処理済み入力の再利用）は、`ENABLE_PROMPT_CACHING_1H=1 claude`で任意に使います。
  保持時間を5分から1時間に延ばします。30分を超える会話は1時間、それ以外は5分を選びます。
  `scripts/enable-1h-cache.sh`が`env.local`へ`export ENABLE_PROMPT_CACHING_1H=1`を書きます。
  `source env.local`でClaudeの子プロセスにも渡します。
- 判定役と相談役は`xhigh`（`high`と`max`の間の推論量）を使います。`/effort xhigh`で指定できます。
  Opus 4.7以外では`high`になります。
  `harness-review`スキルは、呼び出し側の上書きがなければ`high`です。
- 高解像度確認は短辺2576px、3.75MP（375万画素）までです。
  超える画像は事前に縮小します。
  Task Budgets（APIの費用とトークン上限指定）の公開試験版は、この版では採用しません。
  再入処理はJSON（構造化データ）だけを出力します。

### Changed

- 役割はディレクトリから、監視は`monitors/monitors.json`から読み、不正なプラグイン宣言欄を使いません。
- プラグインの役割では、frontmatter（定義冒頭の設定欄）の`permissionMode`と`hooks:`が警告なしに無視されます。
  役割単位の指定が効いていなかった可能性があります。
  この版は`docs/agent-frontmatter-policy.md`へ限界を記録し、動作自体は変えていません。
  対応していない設定は4.6.0で外しました。
- Opus 4.7は指示を文字どおりに実行します。
  Harnessの4役割と7スキルの指示を、上限などの明示値へ直しました。
  独自の指示も同様の調整が要る場合があります。
- `/undo`は自律操作しません。
  `/ultrareview`（Claude Code標準のレビュー）は補助で、Harnessの受け入れ判断を置き換えません。

### Removed

- `harness.toml`の`[telemetry]`（`otel_endpoint`、`webhook_url`）は実行時に使われていなかったため削除しました。
  通知先は環境変数`HARNESS_WEBHOOK_URL`で設定します。

### Fixed

- 同期で不正な宣言欄を戻しません。
  `claude plugin validate`の`monitors: Invalid input`と`agents: Invalid input`が消えました。
  `harness codex-loop start 41.1-41.4`のような範囲指定が再び動きます。
  arm64の実行ファイルで上書きされていたPOSIXの`bin/harness`（シェル経由の入口）を戻しました。
- 隣接する導入先からの補助スクリプト探索、再開時に残る古い失敗状態、同じ実行への二重再入を直しました。
  相談が時間切れでも途中の文章を保ちます。
  高リスクの事前確認と再試行しきい値の相談が失敗しても、助言なしでタスク実行を続けます。
  初回push前のCI結果不在は警告です。

### Security

- Claude Code 2.1.110本体が、`PermissionRequest`（権限要求時の処理）の`updatedInput`（書き換えた入力）に対して`permissions.deny`（拒否規則）を再評価します。
  `PreToolUse`（操作前の処理）の`additionalContext`（モデルへ渡す補足情報）も、操作失敗後に保持します。
  バックスラッシュ、複合コマンド、環境変数の前置きによるBash迂回を本体側で塞ぎました。
  Harness側は、これらの本体修正に対して保護規則R01〜R13を34件の回帰検査で確かめ直しました。


## [4.1.1] - 2026-04-16

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#411---2026-04-16) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3170)

### Added

- 相談の有効化、形式、回数上限、再試行閾値、モデルを`.claude-code-harness.config.yaml`か雛形から読みます。
  相談の状態`.claude/state/advisor/`は自動で作ります。

### Fixed

- リンク経由のコマンドが実行ファイルの本来の場所を探し、PATH導入後も反復コマンドを動かせます。

## [4.1.0] - 2026-04-16

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#410---2026-04-16) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3180)

### Added

- `/maintenance`を戻し、それを案内していた整理の警告に対応しました。
  `plans`は完了作業を退避し、`session-log`はsession-log.mdを月ごとに分けます。
  `logs`は`.claude/logs/`の古いファイルを削除し、`state`は`agent-trace.jsonl`を切り詰めます。
  `all`はこの4つを順に実行します。
  `--dry-run`を付けると変更せず対象だけ示します。
  閾値と除外は文章で指定できます。
  `harness codex-loop start all --max-cycles 3`、`status`、`stop`で、Codexの施工、判定、保存を背景で繰り返します。
  状態は`.claude/state/codex-loop/`に残します。

### Changed

- Codex固有のスキル正本を共有版と分け、公開処理でメジャーとマイナー更新を扱えます。

### Fixed

- 配布と複製の検査で、Codexの判定と実行手順を実際の正本に照合します。

### Removed

- `allow1`スキルを配布と検査から外しました。

## [4.0.4] - 2026-04-14

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#404---2026-04-14) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3295)

### Fixed

- マーケットプレイス導入に、macOS Apple Silicon、macOS Intel、Linux amd64のフック実行ファイルを含めました（合計約32MB）。
  4.0.4より前に`/plugin marketplace add`で導入した場合、実行ファイルが届いていませんでした。
  そのためLinux amd64（WSL2を含む）とApple Siliconでは保護が一切動いていませんでした。
  4.0.0〜4.0.3をマーケットプレイスから入れた場合は更新してください。
  この版にWindowsは含まれません。
  推定（確信度高）: 実行ファイルのない環境ではフックは何もしないままです。
  実行ファイルが不在か未対応なら、標準エラーに診断を出し、標準出力なしで終了コード0にします。
  フック以外のコマンドも同じで、会話は続きますが保護は動いていません。
  同期は`./skills/`を保ちます。

### Added

- 公開配布から開発用内容を除外します。
  スキルパスを検査し、版更新で比較リンクを追加します。

### Changed

- 汎用公開はVERSION、package.json、pyproject.toml、Cargo.tomlを扱い、実行前に具体的な内容を1回確認します。
  Harness専用の事前検査と後処理は内部の包み処理へ移しました。

## [4.0.3] - 2026-04-13

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#403---2026-04-13) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3409)

### Fixed

- 宣言のスキル領域が誤っていたため、導入したプラグインのスキルが0件でした。
  開発用の複製では別経路で読めていたため気づけませんでした。
  `claude plugin update claude-code-harness`で修正版へ更新してください。
  4.0.4までは同期でこの修正が戻ることがあったため、4.0.4以降へ更新します。

## [4.0.2] - 2026-04-12

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#402---2026-04-12) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3432)

### Added

- `harness doctor --residue`、変更検査、公開前検査で既知の移行残りを検出します。
  履歴の例外は証拠を残すためで、現行の古い参照を許すものではありません。

### Removed

- 3.xの現行参照の残りを整理し、移行の担当範囲を記録しました。

## [4.0.1] - 2026-04-11

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#401---2026-04-11) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3473)

### Security

- Claude Code 2.1.89〜2.1.98の修正を、Harness自身の権限検査でも2層目として繰り返します。
  バックスラッシュで空白やフラグを退避したコマンドは安全扱いしません。
  前に付けてよい環境変数は`LANG`、`LANGUAGE`、`TZ`、`NO_COLOR`、`FORCE_COLOR`、`LC_*`だけです。
  他の変数が付くと安全扱いしません。
  連続した空白とタブは検査前に1つの空白へ揃えます。
  保護パスの検査はリンク先も見ます。
  壊れたリンクと循環リンクは拒否し、まだ存在しないパスは新規作成のため許可します。
  `.husky/`のGitフックを保護します。
  「保留」の判定がClaude Codeへ届くようになりました。

### Changed

- レビューは判定、理由、対応、重大度から読み、技術データを分けます。
  この版ではレビューを日本語で出す決まりでした。
  4.12.4で英語既定に戻しました。
  引数なしなら最後のタグ、`main`、直近10コミットの順に基準を選び、10コミットまでに限定します。
  スキル名を一時的な`HAR:*`から`harness-*`（例: `harness-review`）へ戻しました。
  長時間処理の監視を案内しました。

### Fixed

- 同期が有効な宣言設定を上書きしません。
  開始条件は似た別イベントを拒否し、検査と記憶配線をGoの実行名へ揃えました。

## [4.0.0] - 2026-04-09

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#400---2026-04-09) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3643)

### Breaking Changes

- フックはシェルとNodeの処理ではなく、同梱のGoプログラム（`bin/harness hook ...`）を呼びます。
  `harness sync`でフックの設定を作り直してください。
  旧`run-hook.sh`は廃止です。
  フックにNodeは不要になりました。
  保護ブランチへの直接pushを警告から拒否へ変えました。
  4.5.0で確認に緩めています。
  旧シェル処理を呼ぶ独自フックは新しいコマンドへ向け直します。

### Added

- 37のフック処理と保護規則をGoで動かします。
  設定ファイルは`harness.toml`から`bin/harness sync`で作り、状態はSQLite（`state/harness.db`）に保存します。
  新しいコマンドは`bin/harness doctor --migration`（移行状態）、`bin/harness validate`（スキルと役割定義の検査）、`harness status`（役割の状態）です。
  実行ファイルはmacOS Apple Silicon、macOS Intel、Linux amd64向けに作り、GitHub Releaseへ添付しました。
  推定（確信度高、4.0.4から）: マーケットプレイス導入には4.0.4まで届かず、保護は動いていませんでした。

## [3.17.1] - 2026-04-06

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3171---2026-04-06) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3774)

### Fixed

- harness-memを標準の場所`~/.harness-mem/runtime/harness-mem`へ入れた環境では、記憶連携が見つけられず何も言わずに終わっていました。
  そのため会話開始時に前回の文脈が戻りませんでした。
  この場所を最初に探すよう直しました。
  `HARNESS_MEM_ROOT`を設定していれば、そちらが最優先です。

### Changed

- Claude Code 2.1.91〜92の機能を記録しました（Harnessの新規実装ではありません）。
  `disableSkillShellExecution`、プラグインの`bin/`、MCPの`maxResultSizeChars`（最大500K）、応援役の起動修正です。

## [3.17.0] - 2026-04-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3170---2026-04-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3807)

### Added

- `harness-review --dual`でClaudeとCodexの判定役が並行して判定し、結果をまとめます。
  どちらかが修正要求なら全体も修正要求です。
  出力の`dual_review`欄に各モデルの判定と、割れた理由を示します。
  Codexが使えない環境ではClaudeだけで判定します。
  通常の`harness-review`と`harness-review code`は変わりません。
- `harness-review --security`はOWASP Top 10（よくあるWebの弱点10分類）、認証と認可、情報露出に絞り、通常より厳しい基準で判定します。
- Claude Code 2.1.89以降で、Autoモードの判定器がコマンドを拒否すると`permission-denied.jsonl`へ記録します。
  Breezing施工役が拒否された場合はリーダーへ知らせます。
  Claude Codeの`defer`判断は手引きだけで、Harnessの`defer`規則はまだありません。
- 圧縮後に、保存しておいた作業中の状態を戻します。
  タスク完了の通知は`HARNESS_WEBHOOK_URL`を設定した時だけ、Slack、Discord、任意のURLへ送ります。
  未設定なら何も送りません。
  OTelの記録は`OTEL_EXPORTER_OTLP_ENDPOINT`を設定した時だけHTTPで送り、未設定ならローカルのJSONLに残します。
  Codex施工役へは、ファイル数、依存、言葉、完了条件から計算した推論量を渡します（以前は常にmedium）。

### Changed

- Harnessは、JSONと終了コード2を返してコマンドを止めます。
  Claude Code 2.1.90より前は、この止め方が確実には効きませんでした。
  ガードレールの拒否を確実にするには2.1.90以降を使ってください。
  ほかのClaude Code 2.1.87〜90の修正は、追加の包み処理なしで継承します。
- 過大な機能表記7件を訂正しました。
  HTTPフックは雛形だけ、OTelは独自JSONL、分析画面とSlack連携は計画中、LSPとデスクトップの定期実行はClaude Code標準、Autoモードは導入の第1段階で既定ではありません。
- 公開の案内に`--dry-run`、`--complete`、`--announce`、複製の同期、版の選び方、劣化確認の一覧を入れ、npmでは配布しないと明記しました。

## [3.16.0] - 2026-04-01

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3160---2026-04-01) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3924)

### Added

- 任意のチーム設定です。
  `scripts/plans-issue-bridge.sh`がPlans.mdから、課題管理の親課題と子課題（issue）の下書きを作ります。
  課題そのものは作りません。
  正本はPlans.mdのままです。
- `/harness-release --dry-run`で、特定サービスに依存しない公開前点検（`scripts/release-preflight.sh`）が走ります。
  作業ツリー、変更履歴、環境差、健全性、CI、配布物の残りを確認します。
- `harness-plan create`で任意の画面（UI）概要か連携（API）概要を付けられます。
  `scripts/generate-skill-manifest.sh`で機械が読めるスキル一覧（`skill-manifest.v1`）を作ります。

### Changed

- 計画と公開の手引き、Claude、Codex、OpenCodeの複製に、これらの入口を揃えました。

## [3.15.0] - 2026-03-28

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3150---2026-03-28) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L3949)

当時の本体での実効性は再検証していません。
[現在の公式仕様](https://code.claude.com/docs/en/plugins-reference#settings)では、プラグイン設定で有効なのは`agent`と`subagentStatusLine`だけです。
プラグインファイルに設定があるだけでは、保護が効いていた証拠になりません。

### Added

- Claude CodeのTaskCreated、FileChanged、CwdChangedのフックで、作業の作成、Plans.mdや規則の変更、作業ツリーの切替のあとに読み直しを促します。
- 重い作業と、施工役、判定役、雛形役は、完了条件と検証方針から始めます（`effort`と`initialPrompt`の設定）。

### Changed

- Claude Code 2.1.85の`if`条件を使い、権限フックは`git status`、`git diff`、`pytest`、`npm run lint`などの安全寄りのBashだけで動きます。
  危険なコマンドは既存のガードレールで扱います。
- Harnessは、プラグインの設定ファイルに`sandbox.failIfUnavailable: true`と`CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1`を加えました。
  ただしClaude Codeはこのファイルの隔離と権限の設定を読みません。
  隔離が使えない時に止める動作と、子プロセスから認証情報を除く動作が必要なら、自分のClaude Code設定に書いてください。
- 規則の対象パス一覧をYAMLで構造化し、公開の複製から内部専用スキルを除きました。

## [3.14.0] - 2026-03-25

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3140---2026-03-25) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4006)

### Changed

- ClaudeとCodexで同じガードレールを使います。
  フックや署名の省略（`--no-verify`、`--no-gpg-sign`）、保護ブランチでの`git reset --hard`、`main`や`master`への直接push、保護ファイルの編集を検出して警告します。
  この版は、どれかを止める（ブロックする）とは書いていません。
  Codexの実行にはこの規則を渡し、取り込み前に省略フラグ、保護ファイル編集、秘密情報の混入を検査します。
  CodexのAGENTS.mdにHarnessの規則の詳細を入れました。

### Fixed

- Marketplaceから入れた環境では記憶用フックの部品が無く、SessionStart、UserPromptSubmit、PostToolUse、Stopのフックがエラーになっていました。
  記憶用フックを1つの連携部品に通すよう直しました。
  キャッシュ同期のプラグイン位置の解決も直しました。

## [3.13.0] - 2026-03-25

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3130---2026-03-25) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4036)

### Added

- `harness-work`と`breezing`にCodex専用版を用意し、Codex自身の役割操作（起動、送信、待機、終了）を使います。
  ほかの作業はClaudeと共用です。
  `~/.codex/skills/`へ置くと、どのプロジェクトからでも使えます。
  Claude Codeとの違いは3つです。
  作業ツリーは`git worktree add`で明示して作り、レビューはCodexだけで判定役への切替はなく、チーム実行は`--breezing`を付けた時だけ始まります。
- `harness-review`に5つ目の観点「AIの残骸」を加えました。
  差分から仮データ、ダミー利用者、`localhost`のURL、`TODO`と`FIXME`、飛ばしたテスト、直書きのAPIキーなどを探し、minorかmajorに分けます。
- harness-memを入れている場合、SessionStart、UserPromptSubmit、Stopのフックで会話の記憶を保存し、次の開始時に前回の要約（Continuity Briefing）を表示します。

## [3.12.0] - 2026-03-21

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3120---2026-03-21) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4092)

### Added

- Plans.mdが無ければ`harness-plan create --ci`で作ります。
  会話の「追加して」「修正して」などの依頼のうち、Plans.mdに無いものを自動で書き足します。
- すべての方式で実装後にレビューします。
  Codexを先に使い、使えなければ内部の判定役を使います。
  修正要求なら直して再レビューし、最大3回です。
  合格を止めるのはcriticalとmajorだけで、minor、推奨、範囲外は止めません。
- コミット後に、したこと、前後の違い、変更ファイル、Plans.mdの残作業を報告します。
  Breezingは全タスク完了後にまとめて報告します。

### Changed

- Breezing施工役は作業ツリーの中でコミットし、リーダーが判定、修正指示（最大3回）、合格分だけの取り込みを行います。
  Plans.mdを書き換えるのはリーダーだけです。
- codex-cli 0.115.0で`-a never`が廃止されたため、それより前のHarnessではCodexの呼び出しがすべて失敗します。
  更新してください。
  Codexの呼び出しは`--full-auto`、レビューは読み取り専用の隔離で動きます。
  当時のCLIに合わせた指定で、現在の権限の案内ではありません。

## [3.11.0] - 2026-03-20

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3110---2026-03-20) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4161)

当時の本体での実効性は再検証していません。
[現在の公式仕様](https://code.claude.com/docs/en/plugins-reference#settings)では、プラグイン設定で有効なのは`agent`と`subagentStatusLine`だけです。
プラグインファイルに設定があるだけでは、保護が効いていた証拠になりません。

### Added

- Claude Code 2.1.78以降で、利用枠制限429や認証失敗401などのAPIエラーで会話が正常に止まらなかった場合を、StopFailureフックで記録します。
  記録先は`${CLAUDE_PLUGIN_DATA}`があればそこ、無ければ`.claude/state/stop-failures.jsonl`です。
  429ではリーダーへ知らせます。
  `scripts/show-failures.sh`でエラーコード別、時間帯別の要約を見られます。
  自動復旧（待ってからの再開）と推論量の自動変更は設計だけで、未実装です。
- 隔離設定の`allowRead`の例（`.env.example`、`docs/**`）をプラグインの設定ファイルに加えました。
  この例を現在の公式仕様で使う場合は、自分の利用者設定かプロジェクト設定へ写してください。
  当時の本体での実効性は再検証していません。

### Changed

- Claude Code 2.1.77以降は、フックがallowを返しても設定のdenyが優先します。
  フックの手引きをこれに合わせました。
  Claude Codeは`/fork`を`/branch`へ改名しました。
- 旧Codex MCPツール（`mcp__codex__*`）を拒否する規則をプラグインの設定ファイルに加えました。
  ただしClaude Codeはこのファイルの権限規則を読みません。
  止めたい場合は自分の設定に書いてください。
- 導入手順に`CLAUDE_PLUGIN_DATA`と`ANTHROPIC_CUSTOM_MODEL_OPTION`を載せました。
  施工役と判定役の推論量はmediumです。

## [3.10.6] - 2026-03-19

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3106---2026-03-19) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4238)

### Fixed

- `claude plugin install`で入れた環境には組み立て済みの処理本体が無く、PreToolUse、PostToolUse、PermissionRequestの全フックがMODULE_NOT_FOUNDで失敗していました。
  そのためR01〜R09のガードレール（危険な操作を止める保護）は一切動いていませんでした。
  処理本体をプラグインに同梱しました。
  3.0.0〜3.10.5をプラグインとして入れていた場合、ガードレールは動いていなかったので更新してください。
- `localhost:9090`へ送る計測用HTTPフックは、雛形ではなく既定で有効でした。
  計測サーバーが無い環境では、Write、Edit、Bash、Taskのたびに接続拒否エラーと最大5秒の待ちが出ていました。
  既定から外しました。
  使う場合は`docs/examples/hooks-metrics-http.json`を自分のフック設定へ写します。
- 壊れた`codex-review`リンクを外しました。
  ライセンスはプラグイン情報と配布情報の両方でMITです（配布情報は以前Proprietaryでした）。

### Changed

- 役割の禁止ツール名を、旧名`Task`から公式名`Agent`へ揃えました。

### Added

- 背景のBreezing施工役で出たMCPの質問画面（`elicitation_dialog`）を、権限確認と同じように記録します。
- Harness Opsの返答形式をプラグインに同梱しました。
  `/config` → Output style → `Harness Ops`で選びます。

## [3.10.5] - 2026-03-15

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3105---2026-03-15) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4294)

### Fixed

- `scripts/i18n/set-locale.sh ja`が、作り直したスキル領域の説明も日本語へ切り替えるよう直しました。
  以前はこの領域だけ英語のままでした。

### Changed

- ローカルのSuperset状態と告知開発用スキルを追跡から除きます。

## [3.10.4] - 2026-03-15

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3104---2026-03-15) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4314)

### Added

- 役割のターン上限を施工役100、判定役50、雛形役75にしました。
  上限ではリーダーが途中結果を回収し、暴走とトークン費用を抑えます。
- 通知（`permission_prompt`、`idle_prompt`、`auth_success`）を`.claude/state/notification-events.jsonl`へ記録します。
  背景のBreezingで出た権限確認も後から調べられます。
- 機能表にClaude Code 2.1.74の`/context`命令を載せました。
  入力枠の使い方を表示し、圧縮が多い原因を調べられます。

## [3.10.3] - 2026-03-14

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3103---2026-03-14) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4342)

### Changed

- Codexの命令名は`$harness-plan`、`$harness-sync`、`$harness-work`、`$breezing`、`$harness-review`です。
  旧名の`$work`、`$plan-with-agent`、`$verify`などは使えません。
  `scripts/setup-codex.sh`と`scripts/codex-setup-local.sh`は、出荷しなくなった旧スキルを`~/.codex/skills`から控えへ移します。
- 終了時フックの待ち時間設定`CLAUDE_CODE_SESSIONEND_HOOKS_TIMEOUT_MS`を案内しました。
- 開発に参加する人向けです。
  通常の変更は版情報を変えずUnreleasedへ記録し、コミット前とCIは自動で版を上げずに整合だけ確認します。

### Added

- クラウド会話（`--remote`）では`HARNESS_IS_REMOTE`を`CLAUDE_ENV_FILE`へ残し、ほかのフックがクラウドかローカルかを判断できます。
- 背景のBreezing施工役は、答えられないMCPの質問画面を飛ばします。
  通常の会話では本人に質問し、結果を記録します。
  圧縮後に作業中と未着手の作業を戻します。
- Claude Code 2.1.76の機能を使い方とともに記録しました（Harnessの新規実装ではありません）。
  大きなリポジトリ向けの`worktree.sparsePaths`と古い作業ツリーの掃除、`-n`や`--name`の会話名、`/effort`（low、medium、high）、背景役を止めた時の途中結果の保持、自動圧縮の3回連続失敗での停止です。

### Breaking Changes

- Claude 2.1.76では`--plugin-dir`は1パスだけを受け付けます。
  複数プラグインは`--plugin-dir path1 --plugin-dir path2`のように繰り返します。
  Harness単独なら変更不要です。

## [3.10.2] - 2026-03-12

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3102---2026-03-12) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4430)

### Fixed

- 完了件数が総数へ達した時点で、TaskCompletedがharness-memへwork_completedを1回記録します。
  停止まで待ちません。
  成功印で重複を防ぎ、会話を識別できない場合とAPI不達は静かに飛ばします。
  Claude 2.1.74の文書と公開版情報も揃えました。

## [3.10.1] - 2026-03-12

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3101---2026-03-12) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4463)

### Added

- SubagentStart とSubagentStopのフックを`worker`、`reviewer`、`scaffolder`、`video-scene-generator`ごとに分け、役割ごとの開始と終了を記録します。
- Claude Codeの機能を記録しました（Harnessの新規実装ではありません）。
  Chrome連携（`--chrome`、試験版）、言語サーバー（`.lsp.json`）、チームの依存関係、`--teammate-mode`、`CLAUDE_CODE_DISABLE_BACKGROUND_TASKS`、`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`、`cleanupPeriodDays`、`/btw`、プラグインのCLI命令、遠隔操作、役割定義の`skills`欄です。

### Changed

- Breezing施工役の出荷時の既定は`bypassPermissions`のままです。
  これは権限確認をすべて飛ばす設定です。
  `--auto-mode`は任意選択で、対応する親会話でだけ試します。
  雛形と役割定義も`bypassPermissions`のままで、文書を変えただけでは既定は切り替わりません。

## [3.10.0] - 2026-03-11

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#3100---2026-03-11) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4509)

### Added

- `/statusline use scripts/statusline-harness.sh`で2行の状態表示を有効にできます。
  1行目はモデル、ブランチ、staged（コミット対象に選んだファイル）と変更ファイルの件数、役割と作業ツリー（独立した作業用の複製）です。
  2行目は入力使用率（モデルの入力枠を使った割合）、会話費用、経過時間、出力スタイルです。
  使用率70%で黄、90%で赤です。
- Claude Code本体の機能を案内しました。Harnessの既定値ではありません。
  `/sandbox`はOSで処理を隔離します。macOSはSeatbelt、Linuxはbubblewrapを使います。
  `bypassPermissions`（権限確認を省くモード）を補う層として段階的に導入します。
- モデルの案内は`opusplan`（計画はOpus、実行はSonnet）、`CLAUDE_CODE_SUBAGENT_MODEL`（応援役のモデル上書き）、`availableModels`（利用者が選べるモデルの制限）です。
- `Esc+Esc`か`/rewind`で巻き戻せます。
  管理型Code Review（Teams/Enterprise向けの試験公開）は`REVIEW.md`に指示を書き、ローカルの`harness-review`と併用します。
- 長文入力の案内は`sonnet[1m]`（Sonnetの100万トークン入力枠）、モデルごとのprompt cache（処理済み入力の再利用）、`CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING`（推論量の自動調整を止める指定）です。


## [3.9.0] - 2026-03-11

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#390---2026-03-11) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4573)

### Added

- `/output-style harness-ops`で有効にすると、進捗、検査、判定、相談、最大3つの判断の選択肢を揃えます。
  推奨案を先頭に置きます。
- Agent Teams（`breezing`が使うチーム実行）には`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`が必要です。
  `teammateMode`（応援役の表示形式）は`auto`、`in-process`、`tmux`の3つです。
  目安は応援役1人あたり5〜6タスク、チームは3〜5人です。Harnessは施工役1〜3人と判定役1人です。
  施工役に計画を出させ、承認してから実行する手順を案内しました。
  `TeammateIdle`（応援役の手すき通知）と`TaskCompleted`（タスク完了通知）は、終了コード2で差し戻せます。

### Changed

- 下書きのv3.7.3とv3.8.0の内容はこの版に含み、単独では公開していません。
- Claude Code 2.1.72の`ExitWorktree`（作業用の複製から明示的に出る操作）と、呼び出しごとのAgentの`model`指定復活を案内しました。
  `/clear`は背景で動く役割を保持します。`/plan`は説明の引数を受け取ります。
  Bashの自動承認も増えました。
  推論量は`low`、`medium`、`high`の3段階です。Claude Code 2.1.72で`max`は廃止されました。
- 役割定義へ`permissionMode: bypassPermissions`（権限確認を省く指定）を書きました。
  これは当時の設定の誤りです。4.2.0でプラグインの役割では無視されると判明し、4.6.0で外しました。
- Claude Code 2.1.71以降の公式文書から、`/agents`（役割の対話管理）と`--agents`（起動時の役割定義）を案内しました。
  応援役の`background`（背景実行）と`local`記憶（プロジェクト内の保存）も対象です。
  `CronCreate`/`CronList`/`CronDelete`（定期タスクの作成、一覧、削除）、`CLAUDE_CODE_DISABLE_CRON`（定期実行を止める指定）、Desktop Scheduled Tasksも案内しました。
- Auto Modeの既定変更はこの版では予定のままです。
  試験公開は2026-03-12開始予定でした。


## [3.7.2] - 2026-03-10

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#372---2026-03-10) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4725)

### Fixed

- 計測の余分な表示を捨て、フック出力をJSONだけにします。
  タスク0件で単独の0行が混ざる問題を直しました。

### Changed

- 会話要約と利用記録フックの無駄な表示を実行試験で検査します。

## [3.7.1] - 2026-03-09

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#371---2026-03-09) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4736)

### Changed

- 施工役と判定役の型名を`claude-code-harness:worker`と`claude-code-harness:reviewer`へ揃えました。
  以前はファイルごとに名前が違い、施工役の書込前ガードと判定役の完了記録が確実には動いていませんでした。
  この版から適用されます。
- Breezing施工役は背景で動き権限確認を出せないため、`bypassPermissions`（権限確認をすべて飛ばす設定）で動きます。
  意図しない書換えや危険なコマンドも通りえます。
  Claude Code 2.1.71以降では、`/breezing --auto-mode`か`/harness-work --breezing --auto-mode`でAuto Modeを選べます。
  Auto Modeは決めておいた安全な操作だけを自動で許し、`rm -rf`や`git push --force`などは止めます。
  予定は3段階です。
  今は任意、検証後に既定、安定後に`bypassPermissions`を廃止します。
- 施工役はそれぞれ別のgit作業ツリー（作業用の別の取り出し）で動きます。
  並行して同じファイルを編集しても衝突せず、完了後にリーダーが統合します。

## [3.7.0] - 2026-03-08

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#370---2026-03-08) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4773)

### Added

- 作業が3回失敗すると、止まるだけでなく原因を分類し、修正タスク案を保存します。
  `approve fix <task_id>`で承認するとPlans.mdへ`.fix`タスクとして追加し、`reject fix <task_id>`で却下します。
- `/harness-sync --snapshot`で今の進捗を保存します。
  次の会話開始か`/resume`で、最新の要約と前回からの変化を表示します。
- 完了した作業の状態欄に7文字のコミット識別子を自動で付けます（`cc:完了 [a1b2c3d]`）。
  識別子の無い行もそのまま有効です。
- Breezingは施工役が作業を1件終えるごとに、1行の進捗を表示します。
- Plans.mdの各段階に、任意で`Purpose:`行（目的）を置けます。
  本人が目的を述べた時だけ書きます。

## [3.6.0] - 2026-03-08

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#360---2026-03-08) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4859)

### Breaking Changes

- Plansは完了条件と依存を含む5列を必須にし、3列形式を外しました。
  同期前にタスク行を移行してください。

### Added

- `harness-plan create`が検査できる完了条件と依存を推定し、影響と危険度で順位を付けます。
  影響も危険度も高い作業には`[needs-spike]`印と技術検証の作業を加えます。
  完了条件の空欄、検査できない条件、循環する依存を確認します。
- 計画レビューに5つ目の観点「利用者にとっての価値」を加えました。
- 完了した作業が1件以上あれば、同期のたびに振返りを行います。
  `--no-retro`で省けます。
- Breezingは開始前に範囲、依存、危険度を確認します。
  依存の無い作業から割り当て、前提が終わった作業を順に続けます。
  単独施工は先に目的と影響を確認します。

## [3.5.0] - 2026-03-07

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#350---2026-03-07) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4899)

### Added

- 60秒以内の操作3回連続失敗で相談へ上げます。
  `TeammateIdle`（応援役が手すきになったときの通知）と`/loop 5m /sync-status`の定期確認を併用する手順を加えました。
  会話圧縮（履歴の要約）後も背景で動く役割の結果を保つ手順を案内します。
  版を固定したプラグイン導入（`owner/repo@vX.X.X`）を勧めます。

### Changed

- Claude Code 2.1.70〜2.1.71の更新時の注意を加えました。
  `--resume`はスキルを再注入しません。
  会話圧縮で画像が残ります。
  `--print`の停止、プラグインフック、並列導入の不具合はClaude Code本体側で直りました。

### Fixed

- 実際のシンボリックリンク（別の場所を指すリンク）を作れないWindows複製でも、`SessionStart`（会話開始時の処理）前から作業スキルを見つけられます。

### Security

- 失敗回数の保存先か親ディレクトリがシンボリックリンクなら書き込みを省きます。


## [3.4.2] - 2026-03-06

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#342---2026-03-06) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4936)

### Changed

- 日英READMEを導入後の動作と根拠ある比較へ改め、Codex導入をパス指定の読込へ揃えました。

### Added

- 全作業実行の成功と失敗を再確認できる証拠セット、日英の手順と保護図を追加しました。

### Fixed

- 証拠生成で反転した値ではなくClaudeと試験の実終了コードを保ちます。
  公開前に主張と配布範囲のずれを検査します。

## [3.4.1] - 2026-03-06

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#341---2026-03-06) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4962)

### Changed

- 日英機能表の名前を`harness-work`と`harness-review`へ揃えました。

### Fixed

- 機能表の旧名（`task-worker`、`code-reviewer`、`work`、`all skills`）を、`harness-work`、`harness-review`、`harness-*`全スキルへ直しました。
  `/breezing`と`/harness-work`の導入時の誤解を防ぎます。


## [3.4.0] - 2026-03-06

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#340---2026-03-06) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L4980)

### Added

- InstructionsLoadedに対応しました。
  チームの待機と完了のフックは`{"continue": false, "stopReason": "..."}`を返して、その役を止められます。
- Claude Code 2.1.69の`${CLAUDE_SKILL_DIR}`による参照、役割のIDと種類、`/reload-plugins`、`includeGitInstructions: false`、gitの下位フォルダにあるプロジェクトを案内しました。

### Changed

- Breezingの役割確認は`agent_id`を先に、無ければ`session_id`を使います。
  スキルの参照はスキル自身の場所から解決します。
  プロジェクト雛形は、文書化された権限形式の既定値だけを配ります。

### Fixed

- `false`の停止応答が落ちる問題を直し、停止理由が確実に反映されます。

## [3.3.1] - 2026-03-05

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#331---2026-03-05) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5010)

### Changed

- 日英の図を橙色へ揃え、ロゴを更新し、重複した図と表を外しました。

### Added

- 4視点レビューの図と、基本手順と保護の日本語図を追加しました。

## [3.3.0] - 2026-03-05

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#330---2026-03-05) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5036)

### Added

- ファイル数、重要な場所、作業の言葉、過去の失敗から複雑度を数え、3以上なら`ultrathink`を渡します。
  複雑な作業だけ深く考え、簡単な作業は速いままです。
- LLMを使うエージェントフックを3つ入れました。
  該当する操作のたびに動くので、モデル呼び出しの費用と待ち時間が増えます。
  Write とEditの前には、秘密情報、TODOの仮置き、セキュリティを確認します。
  書込のあとは毎回haikuで軽くレビューします。
  終了時は未完了の`cc:WIP`作業があれば警告します。
  圧縮前にも作業中の作業を拾います。
- 作業ツリー作成時に施工役の情報を`.claude/state/worktree-info.json`へ記録し、削除時にCodexの一時ファイルとログを片付けます。
  会話開始時に`HARNESS_VERSION`、`HARNESS_EFFORT_DEFAULT=medium`、`HARNESS_BREEZING_SESSION_ID`を`CLAUDE_ENV_FILE`へ書きます。
- `localhost:9090`への計測用HTTPフックは雛形と説明していましたが、実際は3.10.6まで既定で有効でした。
  計測サーバーが無いと、接続エラーと待ちが出ていました。

### Changed

- Claude Code 2.1.68に合わせ、command、prompt、http、agentのフックと推論量を含む引継ぎを案内しました。
  広い当時のフック記述は、後続の上流条件を優先してください。

### Fixed

- promptフックはStopだけでなく全イベントで使えると訂正し、存在しない文書へのリンクを外しました。

## [3.2.0] - 2026-03-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#320---2026-03-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5075)

### Added

- `/harness-work --no-tdd`でTDD（実装前に失敗する試験を書くテスト先行の進め方）を省けます。
- 会話開始時、スキルを探す前に壊れたWindowsのシンボリックリンク（スキルの場所を指すリンク）を検出します。
  `scripts/fix-symlinks.sh`がディレクトリの実体コピーへ置き換えます。

### Changed

- TDD（テスト先行）を任意から既定へ変えました。
  旧来の`[feature:tdd]`は不要です。
  `[skip:tdd]`がない作業中タスクにはすべて通知が出ます。
  施工役と単独施工で失敗する試験から合格へ進めます。


## [3.1.0] - 2026-03-03

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#310---2026-03-03) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5101)

### Added

- `/harness-work`は作業数で方式を選びます。
  1件は単独、2〜3件は並行、4件以上はBreezingです。
  Codex（`--codex`）は指定した時だけ使います。
  `/breezing`は`/harness-work --breezing`を実行します。
- Codexの`config.toml`に、応援後の記憶連携（`[notify]`）と判定役の読み取り専用隔離を入れました。
  Codex固有の制約も案内します。

### Changed

- Codex連携をCLIだけにし、MCPサーバーの参照を外しました。
  フラグは当時のCLIに合わせ、長い指示は標準入力で渡して引数の長さ制限を避けます。

### Fixed

- 指示ファイルの名前を一意にして、並行実行での衝突を防ぎます。
  エラーは捨てずにログへ残します。
  スキル情報と振分けの誤りも直しました。

### Removed

- 転送用の15スキルと旧い接尾辞の名前を外しました。
  `breezing`（旧）、`codex-review`、`handoff`、`harness-init`、`harness-update`、`impl`、`maintenance`、`parallel-workflows`、`planning`、`plans-management`、`release-har`、`setup`、`sync-status`、`troubleshoot`、`verify`、`work`、`*-harness`の別名、`x-release-harness`です。
  機能ごとの移り先は次のとおりです（この版の原文ではなく、v3の構成メモによる）。
  planning、plans-management、sync-statusは`harness-plan`です（同期は後に`harness-sync`へ分かれました）。
  work、impl、parallel-workflows、旧breezingは`harness-work`です。
  codex-review、verify、troubleshootは`harness-review`です。
  release-har、x-release-harness、handoffは`harness-release`です。
  setup、harness-init、harness-update、maintenanceは`harness-setup`です。

## [3.0.0] - 2026-03-02

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#300---2026-03-02) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5142)

### Breaking Changes

- 42スキルを5操作、11役を3役へまとめました。
  フックはNodeの型付き処理、状態はSQLiteへ移し、複製をリンクにしました。
  この版の移行中は旧スキルと旧役割も残します。

### Added

- 開始、状態の切替、終了、分岐、再開を1つの会話管理にまとめ、旧状態をSQLiteへ移す処理と構造の検査を用意しました。

### Fixed

- SQLiteのモジュール型を直し、改ざん検査を書込ごとに2回ではなく1回にしました。

### Removed

- rsyncによる複製、単独のBashの保護部品、散らばった状態ファイルを、新しい処理へ置き換えました。

## [2.26.1] - 2026-03-02

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2261---2026-03-02) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5193)

### Added

- 日英READMEへ各6枚の図を加え、作業手順、並行施工、保護、スキル、チームを示します。

### Fixed

- 合格後の自動整理をコミット前の判定表へ加え、実行手順と一致させました。

## [2.26.0] - 2026-03-02

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2260---2026-03-02) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5203)

### Added

- `/work`は判定の合格後、コミット前にClaude Code標準の`/simplify`を実行します。
  `--deep-simplify`は`code-simplifier`プラグインも使い、`--no-simplify`は省きます。
  `/simplify`と`/batch`はClaude Code 2.1.63以上の機能で、Harnessは起動と提案だけを行います。
- `/breezing`は多数ファイルへの同じ変更（移行、一括置換、全体追加）を見つけ、標準の`/batch`への委譲を提案します。
- Claude Codeの`type: "http"`フックを案内し、Slack、計測、ダッシュボードの例を用意しました。
  このフックは設定したURLへフックのデータをPOSTします。
  Harnessは送信先を設定しません。送信先を足すと、そのサービスへデータが渡ります。

### Changed

- 版の参照をClaude Code 2.1.49以上から2.1.63以上へ上げました。
  作業ツリー間の自動記憶共有と、`/clear`によるスキルキャッシュ更新を案内します。
  `/work`の状態に、整理を通常、詳しい整理、省略のどれで行ったかを記録します。

## [2.25.0] - 2026-02-24

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2250---2026-02-24) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5231)

### Added

- `CLAUDE_CODE_SIMPLE`（Claude Code 2.1.50以降の機能を絞るモード）では、37スキル、11役割、記憶が警告なしに無効でした。
  `SessionStart`（開始時）と`Setup`（設定時）に検出します。
  端末の`stderr`（エラー表示先）と`additionalContext`（モデルへ渡す会話の補足情報）へ警告します。
  影響は「スキル無効」「役割無効」「フックのみ動作」の3分類で示します。
  互換性文書で限界と回避方法を案内します。
  検出しても無効な機能は復旧しません。

### Changed

- 互換表でSIMPLEモードを「要注意」から「対応済み」へ変え、影響範囲を載せました。
  対応済みは検出と案内を指し、機能の復旧を意味しません。


## [2.24.0] - 2026-02-24

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2240---2026-02-24) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5260)

### Added

- Claude Code 2.1.50〜2.1.51の機能を互換表へ記録しました。
  記憶の漏れ修正、完了作業の整理、WorktreeCreateとWorktreeRemoveフック、宣言的な作業ツリー分離、SIMPLEモード、遠隔操作です。
  この版のHarnessは作業ツリーフックを将来対応として記載するだけです。
- 役割の起動に失敗したときの診断に`claude agents list`（Claude Code 2.1.50以上）を加えました。
- 背景で動く役割は`Ctrl+F`で止めます（Claude Code 2.1.49以上）。
  `Esc`は推奨しません。

### Changed

- 推奨Claude Code版を2.1.49以上から2.1.51以上へ上げました。

## [2.23.6] - 2026-02-24

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2236---2026-02-24) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5288)

### Added

- `release-har`スキルの枝の規則で、単独プロジェクトは通常の`main`への直接pushを許可します。
  強制pushは引き続き禁止です。
  プロジェクト雛形`templates/AGENTS.md.template`も単独プロジェクトの`main`直接push禁止を外しました。
  新しく作るプロジェクトの規則でも許可されます。

### Changed

- Codex施工役の品質検査で、Pythonの試験省略、何でも通す判定、試験設定の緩和も改ざんとして扱います。

## [2.23.5] - 2026-02-23

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2235---2026-02-23) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5309)

### Added

- 試験改ざんの検出を12種以上へ広げました。
  判定の緩和（`toBe`→`toBeTruthy`）、待機上限の水増し、何でも通す判定、Pythonの省略指定を含みます。
- `HARNESS_AUTO_TEST=run`を設定すると、自動試験フックが関連試験を実際に実行し、合否を返します。
  未設定では試験を勧めるだけです。
- これとは別に、`git push`の後にCI失敗を検出し、次の入力にCI修正の勧めを加えます。
- `sync-rules-to-agents.sh`が`.claude/rules/*.md`を`codex/AGENTS.md`の規則欄へ写し、Codexがプロジェクト規則を読めるようにします。
  `codex-exec-wrapper.sh`は`codex exec`の前にこの同期を行います。
  後で`[HARNESS-LEARNING]`の学びを`codex-learnings.md`へ保存し、秘密を除きます。
- `/breezing`では、`.claude/state/review-result.json`が現在のHEADコミットのAPPROVEを記録していれば、最終段の手動APPROVE確認を省きます。
- Codexの実行方針（`harness.rules`）では、`npm test`、`yarn test`、`pnpm test`を確認なしで実行します。
  `git push --force`、`git reset --hard`、`rm -rf`、`git clean -f`、`DROP TABLE`、`DELETE FROM`は確認します。

### Changed

- `/breezing`の施工役の数は最低1です。
  上限は独立作業数、`--parallel N`、計画上の上限、5のうち最小の値です。
- `release-har`スキルは最初に`--dry-run`の試行表示を出します。
  版の上げ幅を推定し、比較リンク付きの4節の公開説明を書きます。
  告知は`--announce`を付けたときだけ加えます。

## [2.23.3] - 2026-02-22

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2233---2026-02-22) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5348)

### Added

- Codex配布に`generate-slide`スキルを含め、日英READMEで`/generate-slide`の使い方を案内しました。

### Changed

- Breezing以外のCodex施工と別判定を`codex exec`へ揃え、MCPではなくCLIの設定と診断を案内します。

### Fixed

- 設定でCodex CLIの実際の利用可否を確認し、複製と回帰検査をCLI限定契約へ揃えました。

## [2.23.2] - 2026-02-22

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2232---2026-02-22) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5380)

### Fixed

- Codexの施工とチーム手順を標準応援APIと`${CODEX_HOME:-~/.codex}/state/harness/`へ揃えました。
  `--claude`は判定も委譲し、`--claude --codex-review`は開始前に失敗します。
  OpenCodeから当時の開発専用Breezingを外しました。

## [2.23.1] - 2026-02-22

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2231---2026-02-22) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5402)

### Changed

- Codex設定は新規ファイルを足し、管理対象の既存ファイルを退避して更新し、利用者だけのファイルを保ちます。
  プロジェクトと本人設定で同じ合併を使い、導入案内を開閉できる欄へ移しました。

### Added

- 設定で計画、施工、判定の不足5役を加え、既存役を重複登録しません。

## [2.23.0] - 2026-02-21

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2230---2026-02-21) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5428)

### Added

- Codexの計画相談は標準応援とリーダー中継の分析役、批判役の対話を使います。
  計画、施工、判定の5役を追加しました。

### Changed

- Breezingの3参照はCodex固有の内容を保つため、共有の写しから外します。
  Codexのチーム実行には`config.toml`の`[features] multi_agent = true`が必要です。
  Harnessの環境確認がこの設定を確かめます。

## [2.22.0] - 2026-02-21

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2220---2026-02-21) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5454)

### Added

- この版は既定の保護規則を`.claude-plugin/settings.json`に入れて配布しました。
  当時はClaude Code 2.1.49以上が導入時に適用し、`/harness-init`は不要と説明していました。
  後の5.7.0で、Claude Codeはこのプラグインファイルの権限規則を読まないと記録されています。
  会話内の`/permissions`に表示されない限り、これらの規則が効いていたと考えないでください。
- `ConfigChange`フックは、Breezingの実行中だけ設定ファイルの変更をチーム履歴へ記録し、操作は止めません。
- 停止時フックは最後の返答（Claude Code 2.1.47以上）を読み、長さとSHA-256ハッシュだけを保存します。
  本文は残しません。
  書き込みは一時ファイルに書いてから置き換え、途中状態を残しません。

### Security

- この版のファイルは全体許可を持ちません。
  拒否: `.env`と秘密ファイル、SSH鍵（`id_rsa`、`id_ed25519`、`.ssh/`）、`.aws/`、`.npmrc`、`sudo`、`rm -rf`と`rm -fr`、データベースCLIの`psql`、`mysql`、`mongo`、`mongod`。
  確認: `git push --force`、`git reset --hard`、`git clean -f`、通常の`git rebase`と`git merge`、`npm`、`bun`、`pnpm`の`install`、`npx`、`npm exec`。
  この版の既定であり、現在の方針ではありません。

### Changed

- Breezingの案内にClaude Code 2.1.49以上の作業ツリー分離（`isolation: "worktree"`）を加えました。
  並行する施工役は、分けた作業ツリー内のファイルを編集します。
  後で統合するとき、同じ行の変更は解決が必要な場合があります。
  2.1.47以上の役割モデル指定の挙動も反映しました。
- 背景実行（`background: true`）を得たのは`video-scene-generator`役だけです。
- CodexとOpenCodeのチーム参照を揃え、版の参照をClaude Code 2.1.38から2.1.49へ上げました。

## [2.21.0] - 2026-02-20

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2210---2026-02-20) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5506)

### Added

- `/breezing`は施工の前に計画を判定します。
  計画役（`plan-analyst`）と批判役（`plan-critic`）が先に話し合います。
  既定でONで、`--no-discuss`で省けます。
  作業を作る前に、範囲、曖昧さ、ファイル担当の重複、依存の整合、テスト先行の印を確認します。
- Plans.mdの作業に`[feature:tdd]`を付けると、先に試験を作ります。
- 8件以上の作業は群に分け、今の群が60%終わると次の群を勧めます。
  施工役同士で直接連絡でき、完了フックが途中判定と次の群を勧めます。

### Fixed

- 同時完了で閾値を飛び越しても通知し、会話単位で重複を除きます。
  圧縮後も計画引継ぎを保ち、古い作業IDを対応付けて現行作業を1回だけ数えます。
  安全な文字一致とJSON処理を使い、jq不在はPythonへ戻ります。

## [2.20.13] - 2026-02-19

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#22013---2026-02-19) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5545)

### Changed

- Codex手順は標準の起動、待機、送信、再開、終了と専用状態領域を使います。
  設定でmulti_agentと役割の既定を加えます。
  `--claude`は施工と判定の両方を委譲し、`--codex-review`と併用できません。

### Fixed

- 施工とBreezingのClaude判定先を、明示した委譲に一致させました。

## [2.20.11] - 2026-02-19

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#22011---2026-02-19) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5570)

### Changed

- Harness UIのダッシュボード（`/harness-ui`、2.12.0で追加）を配布から外しました。
  素材、スキル、雛形、フックを配布せず、会話開始時の登録もしません。

### Fixed

- Issue #50: 絶対パスを埋め込んだ記憶用の8本のラッパー（`scripts/harness-mem*`、`scripts/hook-handlers/memory-*.sh`）を配布から外しました。
  フックと設定もこれらを呼びません。

## [2.20.10] - 2026-02-18

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#22010---2026-02-18) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5585)

### Changed

- Codex設定の既定を本人領域`${CODEX_HOME:-~/.codex}`にしました。
  `--project`でプロジェクトへ置けます。
  Codex上の施工はCodexを既定にし、`--claude`で委譲します。
  復旧状態もその振分けに従います。

## [2.20.9] - 2026-02-15

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2209---2026-02-15) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5607)

### Changed

- Codex側の別判定文書をClaude CLIの`claude -p`委譲へ揃えました。

## [2.20.8] - 2026-02-14

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2208---2026-02-14) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5623)

### Changed

- 推奨Claude Code版を2.1.38以上から2.1.41以上へ上げました。
  Bedrock、Vertex、FoundryでBreezingを使う場合は2.1.41以上が必須です。
  この版でチームのモデルIDの不具合が直りました。
  2.1.41以上ではフックのエラー出力も表示されます。
- `/rename`による会話の自動命名と、`claude auth login`、`claude auth status`、`claude auth logout`（Claude Code 2.1.41以上）を案内します。
  互換表は2.1.42まで記録しました。

## [2.20.7] - 2026-02-14

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2207---2026-02-14) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5635)

### Fixed

- 停止時のモデル判定を、正しいJSONを返すコマンドへ置き換えました。
  自然文の返答で毎回解析失敗する問題を直します。

## [2.20.6] - 2026-02-14

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2206---2026-02-14) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5645)

### Fixed

- 通知フックを有効なPostToolUse名へ修正し、子処理の余分な表示をフック出力から除きます。

## [2.20.5] - 2026-02-12

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2205---2026-02-12) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5656)

### Fixed

- `/breezing --codex`でCodex施工役を起動するよう直しました。
  以前はこの指定が無視され、標準の施工役が動いていました。
  Codex形式では、手順書がリーダーのソース編集を禁止します。
  通常形式は標準の施工役のままです。
  施工役はN人を同時に起動し、Nは独立作業数、`--parallel N`、3の最小値です。
  圧縮後の復旧でも選んだ形式を戻します。

## [2.20.4] - 2026-02-11

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2204---2026-02-11) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5669)

### Fixed

- Harnessの表示と`codex-review`スキルを`codex exec`（Codex CLI）だけの記述へ揃えました。
  開発専用スキルをCodexとOpenCodeの写しから外しました。

### Security

- PreToolUseフックが`mcp__codex__*`の呼び出しを理由付きで拒否します。
  `codex-cli-only`規則も使用を禁じ、引退したCodex MCPサーバーを誤って使わせません。
  代わりにCodex CLI（`codex exec`）を使います。

## [2.20.3] - 2026-02-10

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2203---2026-02-10) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5686)

### Fixed

- フックJSONを正しく符号化し、データをコードに埋めず引数で渡します。
  状態領域の権限を700にし、待機イベントは5秒以内で重複除去、JSONLは500行から400行へ整理します。
  安全な文字一致と型変換で解析と注入の問題を防ぎます。

## [2.20.2] - 2026-02-10

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2202---2026-02-10) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5702)

### Added

- TeammateIdleとTaskCompletedフックが、チームの出来事を`.claude/state/breezing-timeline.jsonl`へ記録します。
- 記憶の案内で、Claude Codeの自動記憶、Harnessの判断と手順、役割の記憶を分けました。
  どれも他の置き換えにはしません。

### Changed

- 版の参照をClaude Code 2.1.30以上から2.1.38以上へ上げました。
  チームフック、役割記憶、高速形式、自動記憶、スキル読込量の調整（文脈の2%、2.1.32以上）、`Task(agent_type)`による応援の種類制限を案内します。
  500行のスキル上限を強制から目安へ変えました。

## [2.20.1] - 2026-02-10

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2201---2026-02-10) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5721)

### Fixed

- 書込後のシェル解析と10フックのPython入力競合を直しました。
  移植可能なprintfと文字一致、日英警告で、助言用フックの付随エラーが作業を止める問題を減らします。

## [2.20.0] - 2026-02-08

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2200---2026-02-08) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5734)

### Changed

- 28スキルを19へまとめました。
  `/memory`が`/sync-ssot-from-memory`と`/cursor-mem`を吸収しました。
  `/setup`が`/setup-tools`、`/harness-mem`、`/codex-setup`、`/2agent`、`/localize-rules`を吸収しました。
  `/ci`、`/agent-browser`、`/x-release-harness`はスラッシュコマンドに出ません（`user-invocable: false`）。
  Claudeによる自動読込は残ります。
- Breezingを3段に分けました。
  準備段は利用者の権限形式を保ち、中間段のリーダーは作業の調整だけを行い、最終段でリーダーが検証とコミットを行います。
- 応援は常に`mode: "bypassPermissions"`で動くため、権限確認が出ません。
  保護はPreToolUseフック、禁止ツール、起動時の指示、`.claude/rules/`、リーダーの監視が担います。
  背景の応援がBashを自動拒否される問題（prompts unavailable）を解消しました。
- GitHubの公開説明は英語で書きます。

### Added

- 初めての`/codex-review`でCodexの利用可否を1回確認します。
- macOSで`timeout`も`gtimeout`も無い場合は、`brew install coreutils`の実行を案内します。

### Fixed

- 保護フックのJSON解析を1回にまとめ、リンク先を検査し、`eval`を外しました。
  Codexのコマンドは環境に依存しない時間制限を使います。

### Removed

- 統合したスキルを`skills/_archived/`へ移しました。
  ビルド生成物（`mcp-server/dist/`を含む）、開発メモ、ロックファイルをリポジトリから外しました。

## [2.19.0] - 2026-02-08

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2190---2026-02-08) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5787)

### Changed

- 5つの施工コマンドを`/work`（Claudeが施工）と`/breezing`（チームで完走）の2つにまとめました。
  どちらも`--codex`を受け付け、この版ではCodex MCP経由で施工を委ねます。
  どちらも同じ対話式の範囲確認を行います。
- `/work`は作業数で進め方を選びます。
  1件は直接、2〜3件は並行、4件以上は反復です。
- 状態ファイルを`work-active.json`へ統一し、旧`ultrawork-active.json`も読みます。

### Removed

- `/ultrawork`は`/work all`へ移行します。
- `/breezing-codex`は`/breezing --codex`へ移行します。
- `/codex-worker`は`/work --codex`へ移行します。
- 旧スキルは`skills/_archived/`へ移しました。

## [2.18.11] - 2026-02-06

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21811---2026-02-06) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5820)

### Added

- Breezing（チーム形式）v2で、調整役のリーダー、施工役、独立した読み取り専用の判定役を分けました。
  フックが会話ごとに判定役の読み取り専用と施工役のファイル担当を強制します。
  `--codex-review`でCodexの判定を加えます。
  完了報告に役割ごとの計測を含めます。
- Codex形式（`--codex`、`ultrawork-active.json`の`codex_mode: true`）では、Claudeが管理役になります。
  Plans.mdの状態印の更新を除き、すべてのEditとWriteを止めます。

### Changed

- Codex判定は`decisions.md`と`patterns.md`を読み、出力を1,500字から2,500字へ広げました。
  criticalとhighが0件なら合格にし、lowとmediumだけでは止めません。

## [2.18.10] - 2026-02-06

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21810---2026-02-06) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5857)

### Added

- 7役にプロジェクトか本人単位の継続記憶を加えました。
  読み取り専用の判定と分析はBash、Write、Editを使えません。
  秘密、個人情報、ソース断片を記憶に残しません。

## [2.18.7] - 2026-02-05

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2187---2026-02-05) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5868)

### Changed

- 通常のGit pushでは確認しません。
  強制とforce-with-leaseは確認します。

## [2.18.6] - 2026-02-05

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2186---2026-02-05) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5876)

### Fixed

- Codexの`harness.rules`（コマンド権限の規則）を確実に解析します。
  `git clean -n`（未追跡ファイルの削除予告）や`sudo -n true`（対話なしのsudo確認）のような安全な確認では、不要な権限確認で止まりません。
  Claudeの安全テンプレート`templates/claude/settings.security.json.template`は、有効な`:*`構文（コマンド引数に一致させる表記）を使います。
  破壊的な形だけで確認します。


## [2.18.5] - 2026-02-05

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2185---2026-02-05) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5889)

### Added

- `gogcli-ops`スキルで、Google Workspace CLIによるDrive、Sheets、Docs、Slidesの操作を案内します。
  認証、アカウント選択、URLからIDへの変換を含みます。
  既定は読み取りだけで、書き込みは確認します。
  このスキルは後に退役しました。

## [2.18.4] - 2026-02-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2184---2026-02-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5900)

### Added

- 会話の中で`/codex-setup`か`/setup-tools codex`を使い、Codex CLIを導入できます。
  プロジェクト単位の導入は`scripts/codex-setup-local.sh`が行います。
  `/harness-init`と`/harness-update`で、Codex CLIのファイルを任意で同期できます。
  2.20.0で`/codex-setup`と`/setup-tools`は`/setup`へ統合されました。

## [2.18.2] - 2026-02-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2182---2026-02-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5910)

### Added

- Codex CLI配布へスキル、暫定の規則保護、初期設定、`$skill`（名前でスキルを呼ぶ指定）用の指示と配布検査を含めました。
  導入は`scripts/setup-codex.sh`、手順は`codex/README.md`です。

### Changed

- READMEにCodex CLIの導入手順を加えました。


## [2.18.1] - 2026-02-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2181---2026-02-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5925)

### Added

- 動画生成に日本語音声の提供元を加えました。
  `aivis`は外部サービスのAivis Cloud APIで、`speaker_id`や`intonation_scale`を指定できます。
  `voicevox`はずんだもんなどのVOICEVOXの声です。
  話者の設定例を同梱します。

### Changed

- MCPサーバーを任意にしました。
  プラグインの`.mcp.json`を削除し、`mcp-server`を配布しないため、導入しても登録されません。
  必要なら別途設定します。

## [2.18.0] - 2026-02-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2180---2026-02-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5941)

### Added

- Claude Code 2.1.30に対応しました。
  Harness側の変更は次のとおりです。
  診断スキルは複雑な会話の問題を`/debug`へ回します。
  役割記録の形式v0.3.0で、作業ごとの入力量、ツール使用回数、所要時間を記録します。
  notebookLMとレビューはPDFをページ範囲（`pages`）で読みます。
  レビュー、CI、公開は詳しい`git log`の指定を使います。
- Claude Code標準の機能も案内します。
  動的クライアント登録に非対応のMCPサーバー向けの`--client-id`と`--client-secret`によるOAuth、応援からのMCP利用（2.1.30で修正）、`--resume`での約68%の記憶削減、動きを減らす`reducedMotion`設定です。

## [2.17.10] - 2026-02-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21710---2026-02-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5957)

### Added

- PreCompactとSessionEndフックで、圧縮前に会話の状態を保存し、終了時に整理します。
- 役割記録の形式v0.2.0で、どのプラグインが編集したかを記録します。
- 隔離設定の雛形`templates/sandbox-settings.json.template`を用意しました。

### Changed

- `deploy`、`generate-video`、`memory`、`verify`は分岐した隔離文脈で動きます。
- Claude Code標準コマンドとの衝突を避けるため、`/release`を改名しました。
  v2.17.10の配布物では`/release-harness`で、2.18.0の時点では`/release-har`です。

## [2.17.9] - 2026-02-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2179---2026-02-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5972)

### Changed

- 新しいプロジェクト設定の雛形は`review.mode: codex`です。
  新しく設定したプロジェクトの判定は、既定でCodex（OpenAI）へ送られます。
  別の判定役を使うときは`review.mode`を変えます。
- `/ultrawork --codex`は必要なときだけ作業ツリーを作ります。
  作業が1件、依存がすべて直列、ファイルが重なる場合は直接実行します。

## [2.17.8] - 2026-02-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2178---2026-02-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5983)

### Fixed

- `/release`をSkillツールから起動できるよう直しました。
  `disable-model-invocation: true`を外したため、入力しなくてもClaudeが公開スキルを自ら起動できます。

## [2.17.6] - 2026-02-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2176---2026-02-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L5992)

### Added

- 動画のシナリオをJSON形式、意味検査、雛形一覧で扱い、親参照による脱出を止めます。
  日英READMEに短い開始手順を加えました。

### Changed

- 28スキルへ日本語説明を加え、READMEの導入順を整理しました。

### Fixed

- シナリオエラーの抽出とslide_inの切替名を形式定義へ揃えました。

## [2.17.3] - 2026-02-03

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2173---2026-02-03) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6028)

### Added

- `/harness-review`の後、`/ultrawork`は合格まで自動で修正します。
  再試行は3回までで、`ultrawork-retry.json`に記録します。
  REJECTとSTOPは即座に止まり、手動対応を求めます。
  3回を超えると止まります。
- 既存の検査スクリプトを優先順にすべて実行し、最初の失敗で止まります。
  判定報告に「🎯 How to Achieve A」として合格に必要な改善を示します。

### Changed

- この当時の版は、Codex MCPが使えるとき自動でCodex判定へ切り替えます。
  使えないときは並行する応援へ戻します。
  待機上限は`timeout_ms`（ミリ秒）で指定します。
- 変更ファイル数は共通祖先からの差分と、保存前後の変更から数えます。
  判定の観点はファイルパスで決めます。

## [2.17.2] - 2026-02-03

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2172---2026-02-03) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6066)

### Added

- Codex施工完了時に一致するタスクを探して完了へ更新します。
  見つからなければ確認し、更新を黙って捨てません。

### Changed

- 施工スクリプトの共通処理と安全なデータ扱いを揃えました。

## [2.17.1] - 2026-02-03

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2171---2026-02-03) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6089)

### Added

- `Edit`/`Write`での編集をagent-trace（編集記録、`.claude/state/agent-trace.jsonl`）へ保存します。
  会話要約、進捗確認、会話をまたぐ記憶で使います。

### Changed

- 会話終了時の要約にプロジェクト名、現在のタスク、最近の編集を表示します。
  Git状態は5秒間の保存結果を使います。

### Fixed

- 編集記録のファイル権限とシンボリックリンク（別の場所を指すリンク）を検査します。
  履歴整理をロックし、同時処理で記録が失われるのを防ぎます。


## [2.17.0] - 2026-02-03

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2170---2026-02-03) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6113)

### Added

- Codex WorkerでOpenAI Codexへ施工を委ねます。
  1件は`codex-worker`スキル、並列は`/ultrawork --codex`でgitの作業ツリーごとに施工します。
  品質検査は証拠、構文と型、試験、試験改ざんを確かめます。
  ファイルの担当ロックは有効期限と生存通知を使い、作業の完了時にPlans.mdを更新します。

### Changed

- 施工と判定の振分けを明示した対象と除外で決め、誤読込を減らします。

### Fixed

- シェル、Git、JSON入力と移植可能な空白検査を直し、厳格シェル形式で計算が予期せず終了する問題を直しました。

## [2.16.21] - 2026-02-03

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21621---2026-02-03) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6140)

### Changed

- `/ultrawork`のCodex指定`--codex`、`--parallel`、`--worktree-base`を設計案と明記しました。
  この版では動きません。
  関連スクリプトと参照は未追跡の下書きで、配布する機能ではありません。
  `/ultrawork --codex`は2.17.0で実装されました。

## [2.16.20] - 2026-02-03

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21620---2026-02-03) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6152)

### Changed

- 振分け規則を1つへ揃え、Codexの施工と判定を決められるようにしました。

## [2.16.19] - 2026-02-03

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21619---2026-02-03) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6161)

### Fixed

- 停止通知を短い語へ変え、理由全文の二重表示を減らしました。

## [2.16.17] - 2026-02-03

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21617---2026-02-03) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6169)

### Added

- 17スキルが補完欄に引数の案内を出します。
  例は`/harness-review [code|plan|scope]`と`/troubleshoot [build|test|runtime]`です。
  変わるのは補完欄の表示だけです。
- 会話間で通知できます。

### Changed

- 試験と案内をスキルだけの構成へ揃えました。

## [2.16.14] - 2026-02-02

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21614---2026-02-02) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6191)

### Changed

- 施工依頼をPlans.mdへ自動登録し、途中で加えた作業も進捗に含めます。

## [2.16.11] - 2026-02-02

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#21611---2026-02-02) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6204)

### Changed

- コマンドをスキルへ移しました。
  `/work`や`/harness-review`などの呼び出し名は変わりません。
  `impl`や`verify`などの内部スキルはメニューに出しません。
- 改名: `dev-browser`→`agent-browser`、`docs`→`notebookLM`、`video`→`generate-video`。
- READMEへ診断と削除の手順を加えました。

## [2.16.5] - 2026-01-31

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2165---2026-01-31) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6223)

### Added

- `/generate-video`にAI画像（外部の画像サービスNano Banana Pro）、権利処理済みの背景音楽、日本語字幕、GlitchTextやParticlesなどの効果を加えました。

## [2.16.0] - 2026-01-31

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2160---2026-01-31) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6237)

### Changed

- 試用機能として、`/ultrawork`の実行中は確認を減らしました。
  `rm -rf`は計画で承認したパスだけ確認なしで実行し、それ以外は従来どおり確認します。
  通常の`git push`は確認なしで進みます。
  強制pushは引き続き確認します。

## [2.15.0] - 2026-01-26

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2150---2026-01-26) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6250)

### Added

- `/setup-opencode`でOpenCodeの互換設定を自動で行い、同じスキルを両方で使えます。
  当時の互換形式であり、現在の同等対応を示しません。

## [2.14.0] - 2026-01-16

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2140---2026-01-16) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6263)

### Added

- `/work --full`で作業を並行実行できます。
  同時に動く数は`--parallel N`で決め、`--parallel 3`なら最大3件です。
  各施工役が自分の結果を自己判定します。

## [2.13.0] - 2026-01-14

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2130---2026-01-14) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6276)

### Added

- 当時のCodex MCPレビューで、安全性、品質、性能、アクセシビリティの4専門家が並行して判定します。

## [2.12.0] - 2026-01-10

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2120---2026-01-10) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6289)

### Added

- `/harness-ui`でブラウザに進捗のダッシュボードを開きます。
  2.20.11で配布から外れました。
- ブラウザ自動操作で画面操作と画像取得を行います。
  当時の名前は`dev-browser`で、2.16.11で`agent-browser`へ改名しました。

## [2.11.0] - 2026-01-08

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2110---2026-01-08) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6298)

### Added

- 会話同士でメッセージを送受信できます。
- `crud`でZodの入力検査付きの入口を生成します。

## [2.10.0] - 2026-01-04

[当時の技術記録](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md#2100---2026-01-04) | [元コミットの原文](https://github.com/Chachamaru127/claude-code-harness/blob/6c198b4c76f983d82a93048d67807b45551a6dc6/CHANGELOG.md?plain=1#L6307)

### Added

- 言語サーバーの定義と参照検索、構文構造検索でコードの調査を支援します。

## 以前の版

2.9.x以前は[GitHub Releases](https://github.com/Chachamaru127/claude-code-harness/releases)で確認できます。

[Unreleased]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.15.0...HEAD
[5.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.14.1...v5.15.0
[5.14.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.14.0...v5.14.1
[5.14.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.13.2...v5.14.0
[5.13.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.13.1...v5.13.2
[5.13.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.13.0...v5.13.1
[5.13.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.12.0...v5.13.0
[5.12.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.11.0...v5.12.0
[5.11.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.10.0...v5.11.0
[5.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.9.0...v5.10.0
[5.9.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.8.0...v5.9.0
[5.8.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.7.0...v5.8.0
[5.7.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.6.0...v5.7.0
[5.6.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.5.0...v5.6.0
[5.5.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.4.0...v5.5.0
[5.4.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.3.1...v5.4.0
[5.3.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.3.0...v5.3.1
[5.3.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.2.0...v5.3.0
[5.2.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.1.0...v5.2.0
[5.1.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v5.0.0...v5.1.0
[5.0.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.4...v5.0.0
[4.16.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.3...v4.16.4
[4.16.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.2...v4.16.3
[4.16.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.1...v4.16.2
[4.16.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.16.0...v4.16.1
[4.16.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.15.0...v4.16.0
[4.15.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.14.0...v4.15.0
[4.14.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.3...v4.14.0
[4.13.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.2...v4.13.3
[4.13.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.1...v4.13.2
[4.13.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.13.0...v4.13.1
[4.13.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.11...v4.13.0
[4.12.11]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.10...v4.12.11
[4.12.10]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.9...v4.12.10
[4.12.9]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.8...v4.12.9
[4.12.8]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.7...v4.12.8
[4.12.7]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.6...v4.12.7
[4.12.6]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.5...v4.12.6
[4.12.5]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.4...v4.12.5
[4.12.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.3...v4.12.4
[4.12.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.2...v4.12.3
[4.12.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.1...v4.12.2
[4.12.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.12.0...v4.12.1
[4.12.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.4...v4.12.0
[4.11.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.3...v4.11.4
[4.11.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.2...v4.11.3
[4.11.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.1...v4.11.2
[4.11.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.11.0...v4.11.1
[4.11.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.10.0...v4.11.0
[4.10.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.9.0...v4.10.0
[4.9.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.8.1...v4.9.0
[4.8.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.8.0...v4.8.1
[4.8.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.7.0...v4.8.0
[4.7.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.6.1...v4.7.0
[4.6.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.6.0...v4.6.1
[4.6.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.4...v4.6.0
[4.5.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.3...v4.5.4
[4.5.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.2...v4.5.3
[4.5.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.1...v4.5.2
[4.5.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.5.0...v4.5.1
[4.5.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.4.0...v4.5.0
[4.4.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.3...v4.4.0
[4.3.3]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.2...v4.3.3
[4.3.2]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.1...v4.3.2
[4.3.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.3.0...v4.3.1
[4.3.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.2.0...v4.3.0
[4.2.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.1.1...v4.2.0
[4.1.1]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.1.0...v4.1.1
[4.1.0]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.4...v4.1.0
[4.0.4]: https://github.com/Chachamaru127/claude-code-harness/compare/v4.0.3...v4.0.4
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
