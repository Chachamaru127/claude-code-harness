---
name: claude-codex-upstream-update
description: "Claude Code changelog と Codex releases を調査し、Harness に実装価値のある差分だけを取り込むためのローカル専用スキル。Use when checking upstream updates, integrating Claude updates into Harness, comparing Claude vs Codex upgrade impact, or preparing the next upstream adaptation cycle. Do NOT use for public release copy or generic changelog summarization."
description-ja: "Claude Code changelog と Codex releases を調査し、Harness に実装価値のある差分だけを取り込むためのローカル専用スキル。公開配布しない。"
description-en: "Local-only skill for researching Claude Code and Codex upstream releases, selecting high-value adaptations, and implementing meaningful Harness upgrades. Not for distribution."
allowed-tools: ["Read", "Write", "Edit", "Bash", "Grep", "Glob", "WebSearch"]
user-invocable: false
---

# Claude / Codex Upstream Update

Claude Code と OpenAI Codex の upstream 更新を、Harness の実装差分まで落とし込むためのローカル専用スキル。
目的は「更新を紹介すること」ではなく、「Harness を実際に強くすること」。

## 使う場面

- Claude Code の changelog を見て、Harness に取り込むべき更新を選びたいとき
- Codex releases を見て、Claude から使う場合 / Codex から使う場合の差を整理したいとき
- docs の追記だけで終わらせず、hooks / settings / Go / scripts / skills / tests / Plans / CHANGELOG まで反映したいとき

## 使わない場面

- 公開向けの単純なリリースまとめ
- ただの changelog 要約
- 実装差分または将来タスク化を伴わない宣伝文

## 絶対ゲート

実装に入る前に、必ず upstream をバージョン単位で分解する。
「目についた 1 件を先に実装してから調査する」は禁止。

必須の出力表:

| Version | Upstream item | Category | Harness surface | Action |
|---------|---------------|----------|-----------------|--------|
| 2.x.x / 0.x.x | 公式項目 | A / C / P | hooks / settings / Go / skills / tests / docs / Plans | 実装 / 自動継承 / 将来タスク |

カテゴリ:

- `A`: Harness で実装または検証強化まで行う
- `C`: Claude Code / Codex 本体の修正を自動継承し、Harness 側の変更は不要
- `P`: 今回は実装しないが、Plans に次回候補として切る

`B: Feature Table に書いただけ` は不可。`cc-update-review` の基準で必ず潰す。

## 一次情報

最初に公式情報を確認する。

- Claude Code changelog: `https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md`
- Claude Code docs changelog: `https://code.claude.com/docs/en/changelog`
- OpenAI Codex releases: `https://github.com/openai/codex/releases`
- OpenAI Codex product updates: `https://openai.com/index/codex-for-almost-everything/`

## Harness surface

更新候補は、次のどこに入るかを必ず決める。

- `hooks/hooks.json`
- `.claude-plugin/hooks.json`
- `.claude-plugin/settings.json`
- `go/internal/guardrail/`
- `go/internal/hookhandler/`
- `scripts/hook-handlers/`
- `skills/`
- `codex/.codex/skills/`
- `.agents/skills/`
- `agents/`
- `tests/test-claude-upstream-integration.sh`
- `tests/validate-plugin.sh`
- `docs/CLAUDE-feature-table.md`
- `CHANGELOG.md`
- `Plans.md`

存在しない旧パスを前提にしない。旧 TypeScript guardrail path、旧 Codex feature-table 名、旧 Codex plugin directory 名、旧 Codex upstream test 名は現行 surface ではない。

## 実行フロー

### 1. 公式更新を分解する

- Claude 側は「新機能」「運用改善」「安全性」「修正」「自動継承」に分ける
- Codex 側は「今すぐ比較軸になるもの」と「将来タスク」を分ける
- Harness が増幅できるかどうかを基準にする

判断の目安:

- 実装対象
  - hook / settings / Go guardrail / script / skill / agent / validate に落とせる
  - 体験改善を「今まで / 今後」で説明できる
- 比較軸
  - 今回は実装しないが、Claude と Codex の差を埋める価値が高い
- 自動継承
  - upstream の修正だけで恩恵を受け、Harness の surface が変わらない

### 2. Claude hardening を優先確認する

Claude Code の permission / sandbox / Bash hardening は、CC 本体の自動継承だけで終わらせない。
Harness 独自の settings / guardrail / tests に影響がないか必ず見る。

Claude Code `2.1.113` で必ず確認する項目:

- `sandbox.network.deniedDomains`
- Bash deny rule が `env`, `sudo`, `watch`, `ionice`, `setsid` などの wrapper 経由でも効くか
- `find -exec` / `find -delete` が broad allow で自動承認されないか
- macOS の `/private/etc`, `/private/var`, `/private/tmp`, `/private/home` など危険削除パス
- native Claude Code binary spawn による plugin install / update / smoke 影響
- `/loop` の wakeup / cancel 改善と Harness loop の役割分担
- `/ultrareview` と `/harness-review` の役割分担
- stalled subagent timeout と Harness の advisor / reviewer drift 検知

### 3. Codex は比較軸として残す

Codex 側は、安定版と alpha を分けて扱う。
alpha release は release body が薄い場合、compare から推測実装せず `P` に留める。

Codex `0.121.0` 以降で確認する項目:

- marketplace / app-server source
- MCP Apps tool calls / namespaced MCP / parallel-call opt-in
- memory reset / deletion / extension cleanup と `harness-mem` の責務境界
- sandbox-state metadata / secure devcontainer / bubblewrap
- subagent token budget / effort defaults
- resume summaries / MCP status endpoints
- app-server / realtime / transcript / thread lifecycle

### 4. 実装と記録を同期する

最低限、次を更新する。

- `Plans.md`
- `docs/CLAUDE-feature-table.md`
- `CHANGELOG.md`
- `tests/test-claude-upstream-integration.sh`
- 実装対象の hook / settings / Go / script / skill
- 必要なら `tests/validate-plugin.sh`

書き方の基準:

- 何が upstream で増えたか
- Harness は何を取り込んだか
- ユーザー体験がどう変わるか
- `A / C / P` のどれか

## Mirror ルール

このスキルはローカル専用で、公開パッケージ前提ではない。
ただし repo 内で同名 mirror が存在する場合は、Claude / Codex どちらで使っても同じ判断になるように同期する。

更新対象:

- `skills/claude-codex-upstream-update/SKILL.md`
- `codex/.codex/skills/claude-codex-upstream-update/SKILL.md`
- `.agents/skills/claude-codex-upstream-update/SKILL.md` が存在する場合

禁止:

- `Claude/Codex` を機械置換して `Codex/Codex` にする
- 存在しない Anthropic 側 Codex repo URL を入れる
- 旧 Codex plugin directory / state directory を現行正本として扱う

## 完了条件

- Claude / Codex の一次情報確認が済んでいる
- バージョン別分解表がある
- Claude 側で少なくとも 1 件は実装または検証強化まで終わっている
- Feature Table と CHANGELOG が「意味のある改善」として読める
- Plans に将来対応が残っている
- `validate-plugin` 系または対象テストを実行している

## 保存しておく実装メモ

### `PreToolUse updatedInput` を使った AskUserQuestion 自動補完・入力正規化

Claude Code 側で `PreToolUse updatedInput` が安定して使える場面では、`AskUserQuestion` の入力を「質問前に軽く整える」設計が有効。
ここでの正規化は、ユーザーの意図を書き換えることではなく、選択肢の補完や曖昧表現の整列を先に済ませて、質問のやり直し回数を減らすことを指す。

#### 狙い

- 同じ質問を言い換えて何度も聞き直す回数を減らす
- `harness-plan create` のような対話フローで、短い回答からでも安全に次の質問へ進める
- `solo / team`, `patch / minor / major`, `scripted / exploratory` のような既知の選択肢を早い段階でそろえる

#### 向いている surface

- `harness-plan create`
- `harness-release`
- 将来 `request_user_input` 相当を持つ対話型 setup / review 導線

#### 正規化してよいもの

- `solo`, `single`, `個人` -> `solo`
- `team`, `issue`, `github issue` -> `team`
- `browser exploratory`, `探索`, `触って確認` -> `exploratory`
- `browser scripted`, `playwright`, `手順固定` -> `scripted`

#### 正規化してはいけないもの

- ユーザーが自由入力した固有名詞
- スコープの広さを変える要約
- セキュリティや権限に関わる yes/no 判断

#### Done の目安

- `updatedInput` で補完された値と元入力の両方が追跡できる
- 意図を書き換えず、既知の選択肢の整列だけに作用する
- 対話回数が減る一方で、誤変換時は元入力へ安全に戻せる
