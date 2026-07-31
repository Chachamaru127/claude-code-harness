# Governance Rules — Rationale ("なぜこのルールが必要か")

`.claude/rules/` 配下の常時ロード governance ファイルは Phase 124.1 (常時ロード context 棚卸し) で
契約条項（禁止事項・チェックリスト・手順）のみを本文に残し、"なぜこのルールが必要か" の背景説明を
本ファイルへ切り出した。契約そのものは元のファイルに変更なく残っている。本ファイルは補足の
背景資料であり、内容は要約・改変せず元の文章をそのまま移設している。

## self-audit.md

settings.json の deny ルールは「エージェント自身を制約する鎖」。
鎖の本数が減っていたら、意図しない緩和か改ざんの可能性がある。
絶対数ではなく減少方向を検知することで、正当な追加は許容しつつ緩和を捕捉する。

settings.local.json への hook 注入を別建てで監視するのは、deny
（`Write/Edit(.claude/settings*)`）が **ツール経路を塞ぐ preventive 層**であるのに対し、
Bash リダイレクト等の残余経路（guardrail では warn 止まり）に対しては
**detective な backstop** が必要だから。preventive（deny で書かせない）と
detective（後から注入を見つける）の二段で「鎖を外す」改ざんを捕捉する。

## workflow-test-wiring.md

`.github/workflows/` の AI 編集 deny と「新規テストの CI 配線」を両立させるためのルール。
operator 裁定 (2026-07-16): deny の本質は**報酬ハック防止**であって「AI はテスト網に触れない」ではない。

v5.1.0 で新設した 2 テスト（`test-hermes-agent-candidate.sh` / `test-lsp-workflow-wiring.sh`）が
「workflows は AI 編集 deny → operator 手動 patch 待ち」のまま CI 未配線で残った（HG-3。
本ルール制定と同じ batch で `tests/validate-plugin.sh` 配線により解消済み）。
実装した本人（AI セッション）が自分の変更を検査するテストを弱められる状態が報酬ハックであり、
テストを**追加する**方向まで人間の手作業に倒すのは過剰防御。方向で切り分ける。

## autonomous-confirmation-scope.md

自律実行中に本質的でない確認（review 対象の候補選択、commit message の文言選び等）で頻繁に止まると、
ユーザーは「推測すれば決まることまで聞かれている」と感じ、自律実行の価値が失われる。特にこれらの
確認は英語で提示されることが多く、判断材料も乏しいため、ユーザーは正しく答えられない。

確認していいことを絞ることで、本当に停止が必要な場面（外部送信・セキュリティ・依頼の実行可否）だけが
浮き上がるようにする。

## shared-file-discipline.md

Phase 92.1.1 の並列準備で、2 worker が同時に `CHANGELOG.md` を追記しようとすると
cherry-pick 衝突が起きるリスクが顕在化した。Lead は両 worker に CHANGELOG 禁止を指示し、
統合時に 2 エントリをまとめて追記する運用に切り替えた。

同様に `Plans.md` / `spec.md` を複数 worker が同時編集すると、
append-only でも cherry-pick 時に同一行付近の衝突が起きる。
`VERSION` を worktree 内で bump すると trunk との 3 点同期（VERSION / plugin.json / harness.toml）が壊れる。
`bin/harness` や mirror（`opencode/skills/` 等）を worktree ごとに再生成すると、
バイナリ衝突と mirror drift の温床になる。

この 3 つの不変条件（invariant）を Lead / Worker の sprint contract に明記し、
並列実行のたびに再交渉しないようにする。
