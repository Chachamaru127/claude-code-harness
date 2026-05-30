# MessageDisplay Hook Policy (Claude Code 2.1.152+)

CC `2.1.152` で `MessageDisplay` hook event が追加された。
hook は assistant message が表示される直前に text を transform または hide できる。

Harness は **audit 付き opt-in 表示補助** に限定し、assistant output の黙示改変は禁止する。

## 適用範囲

| 対象 | 方針 |
|------|------|
| Harness 配布 hooks (`.claude-plugin/hooks.json`, `hooks/hooks.json`) | Phase 80 時点では **MessageDisplay hook を追加しない** |
| Operator / project custom hooks | この policy に従う場合のみ opt-in |
| Codex | 対象外 (Claude Code hook surface) |

## 許可される用途 (opt-in)

- ローカル locale 向けの **非セキュリティ** 表示整形 (例: 既知の status marker をユーザー向け文言に置換)
- 重複 footer / debug banner の hide (**guard rail や deny 理由は hide しない**)
- operator が明示的に有効化した `HARNESS_MESSAGE_DISPLAY=1` 配下の notification 整形

## 禁止

- Permission deny / ask 理由、R01-R13 guard rail 出力、secret 値、`.env` 内容の hide または rewrite
- Reviewer `REQUEST_CHANGES` / Worker `advisor-request` 等の **証跡メッセージ** の transform
- ユーザー未承認の assistant 回答の意味変更 (要約で事実を欠落させる rewrite)
- Auto mode classifier 出力の hide による risk 隠蔽

## Audit 要件

MessageDisplay hook を project に追加する場合:

1. hook script 名と trigger 条件を `.claude/rules/hooks-2.1.152-plus.md` または project rules に 1 行記載
2. transform 前後を jsonl に記録するか、`/doctor` で hook が登録されていることを確認可能にする
3. hide 対象は allowlist (固定 prefix / 既知 debug tag) に限定する

## Auto mode consent との関係

upstream で Auto mode の opt-in consent が廃止されても、Harness は
`MessageDisplay` を Auto mode 有効化の代替手段にしない。
`--auto-mode` default 化や `autoMode.hard_deny` 緩和の理由にも使わない。

## 関連

- `docs/upstream-adoption-plan-2026-05-27.md`
- `.claude/rules/hooks-2.1.152-plus.md`
- `templates/claude/settings.security.json.template` (`autoMode.hard_deny`)
