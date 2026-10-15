# Claude用プラグインをharnessへ切り替える

Claude Codeが旧名を予約名として拒否するため、プラグインIDを`claude-code-harness`から`harness`へ変更します。
GitHubリポジトリ`Chachamaru127/claude-code-harness`とmarketplace名`claude-code-harness-marketplace`は同じです。

[English](plugin-rename.md)

## 切替前

ここにあるのは端末のコマンドです。
AIとの会話欄には入力しません。
実行中のHarness作業を終え、旧プラグインを使うClaudeの会話を閉じます。
`claude plugin disable --help`と`claude plugin install --help`で、ここにあるscope指定が使える版か確認します。
この指定はClaude Code 2.1.296で確認しました。

`claude plugin list`で、旧プラグインが有効なscopeをすべて調べます。
scopeは導入が適用される範囲です。
`user`は自分のアカウント、`project`はプロジェクトの共有設定、`local`は1プロジェクトだけの個人設定です。
projectとlocalの操作は、そのプロジェクトのディレクトリで行います。
共有設定を変えると他の利用者にも影響するため、切替時期を合わせます。

## 現行のClaude Codeでは改名情報に従う

Claude Code 2.1.193以降は、marketplaceの`renames`マップ（旧IDから新IDへの対応表）に従います。
user、project、localの有効化設定とプラグイン設定のキーを書き換えます。
組織の管理設定は、管理者による更新が必要です。
[公式の改名仕様](https://code.claude.com/docs/en/plugins/host-marketplace#migrate-users-with-a-renames-map)に基づく経路です。

改名版が公開された後、端末で実行します。

```bash
claude plugin marketplace update claude-code-harness-marketplace
claude plugin install harness@claude-code-harness-marketplace --scope user
claude plugin list
```

旧版を導入したscopeに合わせ、必要なら`user`を`project`か`local`へ変えます。
終了後にすべてのscopeを確認します。
意図して無効にした設定は無効のまま保ち、使いたい場合だけ新プラグインを有効にします。
GitやURLから追加したmarketplaceでは、新IDを1回導入してキャッシュを揃えます。
新しいClaudeの会話を開始します。
対応する機能は`/reload-plugins`でも再読込できますが、再起動すると会話の境界を明確にできます。

`/plugin`で必要な新IDが有効で、旧版が同時に有効でないか確認します。
`/harness-setup`を実行し、小さな依頼を`/harness-plan`へ渡します。
名前が衝突する場合は`/harness:harness-plan`を使えます。
提案されたプロジェクトの変更内容を見てから受け入れます。

## 古い版や手動での復旧

実行中の作業を先に終えます。
旧IDが残るscopeごとに、データを保持して旧版を外し、同じscopeへ新IDを導入します。

```bash
claude plugin uninstall claude-code-harness@claude-code-harness-marketplace --scope user --keep-data
claude plugin install harness@claude-code-harness-marketplace --scope user
claude plugin list
```

実際のscopeに合わせて`user`を変えます。
`--keep-data`が使えない版では止め、データを消すアンインストールを実行しません。
検証済みのバックアップを用意し、その版で対応するプラグイン管理の経路を使います。
導入失敗の回避策として、両IDを有効にはしません。

## データと他の実行先

プロジェクトの`Plans.md`、`.claude/state/`、`.claude-code-harness.config.yaml`、harness-memの保存先は同じです。
プラグイン専用ディレクトリはIDに応じて変わります。
Harnessは`CLAUDE_PLUGIN_DATA`がある場合、その中の`state.db`と`livemsg.db`を使います。
旧データを残しても、新IDの専用状態は新規で始まる場合があります。
改名マップが移すのは設定キーで、このデータベースではありません。
データベースの自動転送は保証しません。
切替前に会話を終え、保留中の仕事と承認を確認します。
動いているデータベースをそのままコピーしたり、過去の承認を無条件で戻したりはしません。

同じmarketplaceのIDを共有するため、Codex、Cursor、Grokの配布manifestも`harness`に揃えます。
導入方法と対応範囲は変えません。
旧プラグインは実行先が提供する管理方法で無効化か削除してから、新しい配布物を導入します。
有効なコピーが1つだけか確認します。
CursorとGrokのコピー導入先は末尾が`harness`になり、組み立て用の保存先とプロジェクト設定は旧来の名前を保ちます。
`setup-codex.sh --user`でスキルをコピーしている場合は、スキル名と保存先が同じです。

切替のためにキャッシュ、認証情報、記憶を手で削除しません。
新しいClaude Codeでは旧名へ戻せるとは保証しません。
ローカル候補の検査成功は、改名版が公開済みという意味ではありません。
