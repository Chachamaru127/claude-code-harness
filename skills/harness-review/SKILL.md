---
name: harness-review
description: "HAR: Multi-angle code, plan, scope review. Security/quality check. Trigger: review, code review, plan review, scope analysis. Do NOT load for: implementation, new features, bugfix, setup, release."
description-en: "HAR: Multi-angle code, plan, scope review. Security/quality check. Trigger: review, code review, plan review, scope analysis. Do NOT load for: implementation, new features, bugfix, setup, release."
description-ja: "HAR:コード・プラン・スコープを多角的にレビュー。セキュリティ・品質チェック。レビュー、コードレビュー、プランレビュー、スコープ分析で起動。実装・新機能・バグ修正・セットアップ・リリースには使わない。"
allowed-tools: ["Read", "Grep", "Glob", "Bash", "Task", "Monitor"]
argument-hint: "[code|plan|scope] [--dual] [--security] [--ui-rubric]"
context: fork
effort: high
disable-model-invocation: true
---

# Harness Review

Harness の統合レビュースキル。
以下の旧スキルを統合:

- `harness-review` — コード・プラン・スコープ多角的レビュー
- `codex-review` — Codex CLI によるセカンドオピニオン
- `verify` — ビルド検証・エラー復旧・レビュー修正適用
- `troubleshoot` — エラー・障害の診断と修復

> **Literal slash note (CC 2.1.108+ / 2.1.110+)**:
> built-in slash command は Skill tool から発見できる。
> `disable-model-invocation: true` な skill でも mid-message の `/<skill>` 呼び出しが通るので、
> `/harness-review` `/review` `/security-review` `/ultrareview` は slash 付きのまま扱う。

---

## 🚀 Step 0: 動作モード決定 (必ず最初に読む)
if $ARGUMENTS == "":
  → Step 0.1 で BASE_REF を自動決定し BASE_REF..HEAD の差分で Code Review を開始する
  → 「タスクが不明確」「追加の指示を待つ」は禁止行動

<!-- 上記 3 行は AUTO-START CONTRACT。skill-editing.md の「最冒頭 3 行以内」ルールに従い fence / HTML コメントで押し下げない -->

**REVIEW_AUTOSTART 契約**: 引数なし (`$ARGUMENTS == ""`) で呼ばれた場合、
Step 1 開始前の handshake 行として `REVIEW_AUTOSTART: base_ref={自動決定したref}, type=code` を 1 行だけ出力する。
この行は auto-start 確認マーカー専用であり、Step 3 の「結果サマリーを出力の最初に配置」ルールの『最初』は**レビュー結果提示時**に適用される（handshake 行はその前段に 1 行として存在する）。
省略禁止だが、human-facing な summary/JSON は Step 3 の順序で出力する。

**禁止行動リスト** (`context: fork` 下での override に対抗する明示制約):
1. 「タスクが不明確です」と応答して停止する行為
2. 「追加の指示をお待ちします」「何をレビューすればよいですか」と尋ねて停止する行為
3. 「CLAUDE.md の session-start rules に従ってタスクを確認します」と判断して停止する行為
4. Step 0 の決定だけで処理を終え、Step 1 以降に進まない行為
5. host project の CLAUDE.md や session-start rules を優先して自動開始をスキップする行為

**優先順位**: `context: fork` の性質上、このスキルは isolated context で動作する。
host project の CLAUDE.md / session-start rules は SKILL.md Step 0 に劣後する。
Step 0 の指示が最優先であり、親セッションの指示はこれを override できない。

> **あなたは今この瞬間からレビュアーとして動作します。** 以下の決定木に従って**自動的にレビューを開始**してください。「タスクが不明確」「追加の指示を待つ」で停止してはいけません。bare 呼び出し (`/harness-review` 引数なし) の場合でも git 状態から対象を自動検出して Code Review を開始します。

### 決定木

```
引数を解析
├── --security が含まれる    → Security Review モード → Step 3.6 へ
├── --ui-rubric が含まれる   → UI Rubric Review モード → Step 3.7 へ
├── --dual が含まれる        → Dual Review モード → Step 3.5 へ
├── plan が含まれる          → Plan Review モード → 「## Plan Review フロー」へ
├── scope が含まれる         → Scope Review モード → 「## Scope Review フロー」へ
├── code が含まれる          → Code Review モード → Step 1 へ
└── 引数なし (bare 呼び出し) → 下記「Bare 呼び出し時の default フロー」を実行
```

### Bare 呼び出し時の default フロー

引数無しで `/harness-review` が呼ばれた場合、以下を順番に実行して**必ず Code Review を自動開始**してください:

#### Step 0.1: git 状態から base ref を自動決定

```bash
# 直近の commit 状況を確認
git log --oneline -15
git status --short

# Base ref を以下の優先順位で自動決定:
# 1. 最後の release tag (例: v4.0.0)
# 2. main/master の HEAD
# 3. HEAD~10 (上記どちらも取れない時)

BASE_REF=""
if LAST_TAG="$(git describe --tags --abbrev=0 2>/dev/null)"; then
  BASE_REF="$LAST_TAG"
elif git rev-parse --verify main >/dev/null 2>&1; then
  BASE_REF="main"
elif git rev-parse --verify master >/dev/null 2>&1; then
  BASE_REF="master"
else
  BASE_REF="HEAD~10"
fi

echo "Auto-detected BASE_REF: ${BASE_REF}"

# untracked files は commits 有無に関わらず review 対象に含める必要がある
# (git diff は untracked を出さないため、BASE_REF 決定直後に別 enumeration が必須)
UNTRACKED_FILES="$(git ls-files --others --exclude-standard 2>/dev/null || true)"
UNTRACKED_COUNT=0
if [ -n "$UNTRACKED_FILES" ]; then
  UNTRACKED_COUNT="$(printf '%s\n' "$UNTRACKED_FILES" | wc -l | tr -d ' ')"
  echo "ℹ️ untracked files ${UNTRACKED_COUNT} 件を review scope に含めます:"
  printf '%s\n' "$UNTRACKED_FILES" | sed 's/^/  - /'
fi

# 差分が存在することを確認 & スコープ上限チェック
CHANGED_COUNT="$(git log --oneline "${BASE_REF}..HEAD" 2>/dev/null | wc -l | tr -d ' ')"

# 下限フォールバック: commit 差分ゼロの時は working tree の未コミット変更を確認
if [ "$CHANGED_COUNT" -eq 0 ]; then
  # staged または unstaged の変更が working tree にあるか
  HAS_UNCOMMITTED=0
  if ! git diff --quiet HEAD 2>/dev/null; then
    HAS_UNCOMMITTED=1
  fi
  if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    HAS_UNCOMMITTED=1
  fi

  if [ "$HAS_UNCOMMITTED" -eq 1 ] || [ "$UNTRACKED_COUNT" -gt 0 ]; then
    echo "ℹ️ ${BASE_REF}..HEAD にコミット差分はありませんが、working tree に未コミット変更があります。それをレビュー対象にします。"
    # BASE_REF=HEAD のまま維持。後段の git diff は引数なし (working tree 対比) で動作する
    BASE_REF="HEAD"
    CHANGED_COUNT=1
    # UNTRACKED_FILES / UNTRACKED_COUNT は既に計算済みなので再計算不要
  else
    echo "⚠️ ${BASE_REF}..HEAD に差分がなく、working tree も clean です。HEAD~5..HEAD にフォールバックします。"
    BASE_REF="HEAD~5"
    CHANGED_COUNT="$(git log --oneline "${BASE_REF}..HEAD" 2>/dev/null | wc -l | tr -d ' ')"
    # UNTRACKED_FILES は既に空文字 / UNTRACKED_COUNT は 0
  fi
fi

# 上限フォールバック: commits が 10 を超える時は HEAD~10 に絞る
# (最後のリリースタグから多数のコミットが積まれた状態で bare 呼び出し
#  されると、レビュースコープが過大になりレビュー品質が落ちるため)
if [ "$CHANGED_COUNT" -gt 10 ]; then
  echo "⚠️ ${BASE_REF}..HEAD に ${CHANGED_COUNT} commits あります。スコープを HEAD~10 に絞ります。"
  echo "   (フル範囲をレビューしたい場合は明示的に 'code' を指定するか、より古い ref を argument で渡してください)"
  BASE_REF="HEAD~10"
fi
```

#### Step 0.2: レビュータイプを自動判定

base ref から HEAD までのコミットメッセージを調べて、最適なレビュータイプを選ぶ:

```bash
RECENT_TYPES="$(git log --oneline "${BASE_REF}..HEAD" --pretty='%s' | head -20)"

# 判定ロジック:
# - "plan:" で始まる commit が多い → Plan Review
# - "feat|fix|refactor|test|chore|docs|perf|style" 系 → Code Review (default)
# - よくわからない → Code Review (default)

if echo "$RECENT_TYPES" | grep -c '^plan:' | awk '$1 > 2 {exit 0} {exit 1}'; then
  REVIEW_TYPE="plan"
else
  REVIEW_TYPE="code"  # Default
fi

echo "Auto-detected review type: ${REVIEW_TYPE}"
```

#### Step 0.3: 該当のレビューフローへ遷移

- `REVIEW_TYPE=code` → **Step 1 (変更差分を収集) へ進む**。`BASE_REF` 環境変数は Step 0.1 で決定したものを使用
- `REVIEW_TYPE=plan` → **「## Plan Review フロー」セクションへ進む**

**⚠️ 重要**: Step 0 を実行したら、**必ず Step 1 以降に処理を進める**こと。「モードを決定した」だけで停止せず、決定したモードの全フローを最後まで実行してください。

### 出力言語・フォーマット (絶対遵守)

**このスキルは `context: fork` で動作し、親セッションの言語文脈を継承しません。CLAUDE.md の "All responses must be in Japanese (including context: fork skills)" ルールに従い、以下を徹底してください:**

#### ルール 1: 出力は必ず日本語

- 見出し、本文、説明、観点評価、結論、次のアクションすべて日本語で書く
- 例外として英語のまま保つもの:
  - コード識別子、ファイルパス (`skills/harness-review/SKILL.md` など)
  - `verdict` 値 (`APPROVE` / `REQUEST_CHANGES`) — 機械可読形式
  - JSON のフィールド名 (`critical_issues`, `observations` など)
  - ログ出力、コマンド例、エラーメッセージ原文

#### ルール 2: 結果サマリーを出力の最初に配置

> **注**: bare `/harness-review` 時の `REVIEW_AUTOSTART` handshake 行は本ルールの『最初』の対象外（Step 0 の auto-start マーカー契約を参照）。handshake 行を 1 行出力した後、本セクションで指定する結果サマリーを human-facing 出力の最初に置く。

- ユーザーが最も知りたい情報 (**判定・主要指摘 3 件・次のアクション**) を**冒頭に日本語で** 出力
- JSON 詳細や技術的根拠はサマリーの**後**に補足として配置
- JSON を最初に出す、観点別評価の後に結論を添える、英語で書く — これらは**すべて NG**
- 詳細な結果サマリーテンプレートは [Step 3: レビュー結果出力](#step-3-レビュー結果出力) を参照

**この 2 つのルールが満たされない出力はレビュー失敗として扱います。**

---

## Quick Reference

| ユーザー入力 | サブコマンド | 動作 |
|------------|------------|------|
| "レビューして" / `/harness-review` / `/review` | `code`（自動） | コードレビュー（直近の変更） |
| "`harness-plan` 実行後" | `plan`（自動） | 計画レビュー |
| "スコープ確認" | `scope`（自動） | スコープ分析 |
| `/harness-review code` | `code` | コードレビュー強制 |
| `/harness-review plan` | `plan` | 計画レビュー強制 |
| `/harness-review scope` | `scope` | スコープ分析強制 |
| `/harness-review --dual` | `code`（自動） + Codex 並行 | Claude + Codex dual review |
| `/harness-review --security` | Security Review | OWASP Top 10 専用セキュリティレビュー（read-only） |
| `/harness-review --ui-rubric` | UI Rubric Review | デザイン品質の 4 軸採点レビュー |
| `/ultrareview` | built-in slash | CC ネイティブのアドホックレビュー。**Harness flow 内では呼ばない**（後述参照） |

## PR host boundary

Claude Code `2.1.119` の `prUrlTemplate` と `--from-pr` により、human-facing な review URL は multi-host に寄せられる余地がある。
ただし Harness の review automation は今も GitHub-first であり、owner / branch / CI metadata の自動取得までは抽象化していない。
そのため multi-host は docs-only follow-up とし、automation の primary path は GitHub のまま維持する。

## オプション

| オプション | デフォルト | 説明 |
|-----------|-----------|------|
| `--dual` | なし | Claude Reviewer と Codex Reviewer を並行実行し verdict をマージ。Codex 不可時は自動フォールバック。詳細: [`${CLAUDE_SKILL_DIR}/references/dual-review.md`](${CLAUDE_SKILL_DIR}/references/dual-review.md) |
| `--security` | なし | OWASP Top 10 ベースのセキュリティ専用レビューを実行。read-only（Write/Edit/Bash 書き込み不可）。詳細: [`${CLAUDE_SKILL_DIR}/references/security-profile.md`](${CLAUDE_SKILL_DIR}/references/security-profile.md) |
| `--ui-rubric` | なし | Design Quality / Originality / Craft / Functionality の 4 軸で採点し、`rubric_target` との比較で判定。詳細: [`${CLAUDE_SKILL_DIR}/references/ui-rubric.md`](${CLAUDE_SKILL_DIR}/references/ui-rubric.md) |
| `--no-commit` | なし | APPROVE 時の自動コミットを無効化 |

## レビュータイプ自動判定

| 直前のアクティビティ | レビュータイプ | 観点 |
|--------------------|--------------|------|
| `harness-work` 後 | **Code Review** | Security, Performance, Quality, Accessibility, AI Residuals |
| `harness-plan` 後 | **Plan Review** | Clarity, Feasibility, Dependencies, Acceptance |
| タスク追加後 | **Scope Review** | Scope-creep, Priority, Feasibility, Impact |

## Code Review フロー

### Step 1: 変更差分を収集

> **`BASE_REF=HEAD` fallback 時の注意**:
> Step 0.1 で `BASE_REF=HEAD` に設定されたパスに入ったときは、`git diff HEAD` が tracked 変更だけを返し untracked files を落とす。
> このステップの change enumeration と Step 1.5 の residual scan は、`git diff HEAD` の結果に加えて
> `${UNTRACKED_FILES}` (= `git ls-files --others --exclude-standard` の出力) のファイルも
> **個別に `cat` して review scope に含めること**。untracked ファイルの行数は `wc -l` で
> CHANGED_COUNT 上限チェックには含めず、レビュー本文だけに含める。
> `UNTRACKED_COUNT=0` の場合はこの手順をスキップしてよい。

```bash
# BASE_REF が harness-work から渡された場合はそれを使用、なければ HEAD~1 にフォールバック
CHANGED_FILES="$(git diff --name-only --diff-filter=ACMR "${BASE_REF:-HEAD~1}")"
git diff ${BASE_REF:-HEAD~1} --stat
git diff ${BASE_REF:-HEAD~1} -- ${CHANGED_FILES}

# BASE_REF=HEAD の場合: untracked files も個別に取得してレビュー範囲に含める
if [ "${BASE_REF}" = "HEAD" ] && [ -n "${UNTRACKED_FILES:-}" ]; then
  echo "--- untracked files (レビュー対象に追加) ---"
  printf '%s\n' "$UNTRACKED_FILES" | while IFS= read -r f; do
    echo "=== $f (untracked) ==="
    cat "$f" 2>/dev/null || echo "(読み取り不可)"
  done
fi
```

### Step 1.5: AI Residuals を静的走査

LLM の印象だけで判定せず、再実行できる形で残骸候補を拾う。`scripts/review-ai-residuals.sh` は stable な JSON を返すので、その結果をレビュー根拠として使う。

```bash
# 差分ベース
AI_RESIDUALS_JSON="$(bash scripts/review-ai-residuals.sh --base-ref "${BASE_REF:-HEAD~1}")"

# 対象ファイルを明示したい場合
bash scripts/review-ai-residuals.sh path/to/file.ts path/to/config.sh
```

#### Step 1.5.b: untracked files を AI residuals 観点で追加スキャン

`scripts/review-ai-residuals.sh` は `git diff --name-only` ベースで動作するため untracked files を走査しない。
PR 途中で作成したが stage していないファイルに残る `TODO` / `test.skip` / ハードコード秘密値が
「AI residuals なし」と誤判定されるのを防ぐため、Step 1.5.b で個別スキャンを実施する。

```bash
# Step 1.5.b: untracked files を AI residuals 観点で手動スキャン
# (review-ai-residuals.sh は git diff ベースのため untracked を含まない)
if [ "$UNTRACKED_COUNT" -gt 0 ]; then
  echo "🔍 untracked files ${UNTRACKED_COUNT} 件を AI residuals 観点で追加スキャン"
  # スキャンパターン: TODO/FIXME/XXX, test.skip/it.skip/describe.skip,
  # eslint-disable, ハードコード秘密値 (sk-*, AKIA*, BEGIN PRIVATE KEY, password = "...")
  UNTRACKED_RESIDUALS="$(printf '%s\n' "$UNTRACKED_FILES" | while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ ! -f "$f" ] && continue
    grep -nE 'TODO|FIXME|XXX|\.skip\(|\.only\(|eslint-disable|sk-[A-Za-z0-9]{20,}|AKIA[A-Z0-9]{16}|BEGIN [A-Z ]*PRIVATE KEY|password[[:space:]]*=[[:space:]]*"[^"]+"' "$f" 2>/dev/null \
      | sed "s|^|$f:|"
  done || true)"
  if [ -n "$UNTRACKED_RESIDUALS" ]; then
    echo "⚠️ untracked files に AI residuals 候補が見つかりました:"
    echo "$UNTRACKED_RESIDUALS"
    echo ""
    echo "上記ヒットは Step 2.2 の severity 判定表に従って critical/major/minor に分類し、"
    echo "verdict に反映してください（major 以上が 1 件でも → REQUEST_CHANGES）。"
  fi
fi
```

### Step 2: 5観点でレビュー

| 観点 | チェック内容 |
|------|------------|
| **Security** | SQLインジェクション, XSS, 機密情報露出, 入力バリデーション |
| **Performance** | N+1クエリ, 不要な再レンダリング, メモリリーク |
| **Quality** | 命名, 単一責任, テストカバレッジ, エラーハンドリング |
| **Accessibility** | ARIA属性, キーボードナビ, カラーコントラスト |
| **AI Residuals** | `mockData`, `dummy`, `fake`, `localhost`, `TODO`, `FIXME`, `it.skip`, `describe.skip`, `test.skip`, ハードコードされた秘密情報/環境依存 URL, 明らかな仮実装コメント |

### Step 2.2: AI Residuals の severity 判定表

`AI Residuals` は、まず `scripts/review-ai-residuals.sh` の JSON を確認し、その後に diff 文脈で「本当に出荷リスクか」を最終判断する。

| 重要度 | 代表例 | 判定の考え方 |
|--------|--------|-------------|
| **major** | `localhost` / `127.0.0.1` / `0.0.0.0` の接続先、`it.skip` / `describe.skip` / `test.skip`、ハードコードされた秘密情報っぽい値、dev/staging 固定 URL | 本番事故、誤設定、検証抜けに直結しやすい。1 件でも `REQUEST_CHANGES` |
| **minor** | `mockData`, `dummy`, `fakeData`, `TODO`, `FIXME` | 残骸の可能性は高いが、即事故とは限らない。修正推奨だが verdict は変えない |
| **recommendation** | `temporary implementation`, `replace later`, `placeholder implementation` のような仮実装コメント | コメント単体では即バグ断定できないが、追跡・明確化を促したい |

### Step 2.5: 閾値基準による verdict 判定

各指摘を以下の重要度に分類し、**この基準のみ**で verdict を決定する。

| 重要度 | 定義 | verdict への影響 |
|--------|------|-----------------|
| **critical** | セキュリティ脆弱性、データ損失リスク、本番障害の可能性 | 1 件でも → REQUEST_CHANGES |
| **major** | 既存機能の破壊、仕様との明確な矛盾、テスト不通過 | 1 件でも → REQUEST_CHANGES |
| **minor** | 命名改善、コメント不足、スタイル不統一 | verdict に影響しない |
| **recommendation** | ベストプラクティス提案、将来の改善案 | verdict に影響しない |

> **重要**: minor / recommendation のみの場合は **必ず APPROVE** を返すこと。
> 「あったほうが良い改善」は REQUEST_CHANGES の理由にならない。
> `AI Residuals` でも同じ。`major` に入るのは「出荷事故や誤設定に直結しやすいもの」だけで、単なる残骸候補は `minor` または `recommendation` に留める。

### Step 3: レビュー結果出力

#### 出力順序 (絶対遵守)

レビュー結果は**必ず以下の順序で出力**する:

> **注**: bare 呼び出し時の `REVIEW_AUTOSTART` handshake 行（Step 0 の auto-start マーカー）は Step 3 の出力順序の対象外。handshake 行（1 行）を出力した後、以下の順序でレビュー結果を出力する。

1. **🎯 結果サマリー** (日本語、レビュー結果の最初に出力)
2. JSON 出力 (機械可読 schema-v1 形式、サマリーの後)
3. 観点別評価の詳細 (任意、日本語)

#### 1. 結果サマリーテンプレート (必須、最初に出力)

**設計方針**: 非専門家にもわかるように、**情報粒度 MID / 認知負荷 MIN** を意識。結論を最上段、安心材料(良かったこと)を先、問題点は日本語タイトル→平易な説明→アクション→技術詳細の 4 段で隔離。

以下のテンプレートで出力する:

```markdown
## 🎯 レビュー結果

### {✅ 合格 (APPROVE) | ❌ 要修正 (REQUEST_CHANGES)} — {1 行の日本語結論}

例: ✅ 合格 (APPROVE) — 10 commits 全てがテストを通過し、リリース可能な品質です

**対象**: `{BASE_REF}..HEAD` の {N} commits、{M} ファイル変更 (+{INS}/-{DEL} 行)
**レビュー種別**: コードレビュー / プランレビュー / スコープレビュー / セキュリティレビュー / デュアルレビュー

---

### ✨ 良かったところ

{2〜3 件、非専門家にもわかる日本語で。何が良かったか 1 行ずつ}

- {ポイント 1: 具体的に評価できる変更点を平易に}
- {ポイント 2}
- {ポイント 3}

### ⚠️ 気になったところ ({X} 件)

{0 件なら「特になし — すべてクリーンです 🎉」と 1 行で明記して次のセクションへ}

{1 件以上ある場合、重要度順に最大 3 件。各項目は以下の 4 段構造を厳守}

#### 1. {日本語のタイトル: 技術用語を避け、何が問題か一読でわかる表現}

**問題**: {技術用語を使わず、何が起きているか・起きうる影響を 1〜2 文で説明}

**対応**: {具体的な次のステップを日本語で。動詞で始める。例: 「〜を修正する」「〜を別タスクとして起票する」}

**重要度**: {🔴 致命的 | 🟠 重要 | 🟡 軽微 | 🟢 推奨}

**技術的位置 (開発者向け)**: `{file_path}:{line}` — {1 行の技術要約}

#### 2. ...

### 🎬 次のアクション

{1〜3 項目、日本語、動詞で始める。リリース可否の判断もここに含める}

1. {アクション 1}
2. {アクション 2}
3. {アクション 3}

### 📊 自動検証の結果

{チェックリスト形式、日本語表記}

- ✅ Go テスト ({N} packages): 全パス
- ✅ プラグイン検証: {合格数} 件合格 / {失敗数} 件失敗
- ✅ 整合性チェック: 全パス
- ✅ AI 残骸スキャナ: {件数} 件

---

### 📦 詳細データ (開発者・ツール連携向け、非専門家は読み飛ばし可)

<!-- ここから先は任意。JSON・観点別評価・ファイル一覧などを配置 -->
```

**禁止事項 (非専門家向け UX を守るため)**:
- ❌ JSON 出力を最初に出すこと — 必ず結果サマリーより後、「📦 詳細データ」セクション内に配置
- ❌ 結果サマリー本文を英語で書くこと — 見出し・説明・アクションすべて日本語
- ❌ 判定や主要指摘を JSON の中に埋めてサマリーを省略すること
- ❌ 観点別評価の後に結論を添えること — 結論は必ず最初
- ❌ 「気になったところ」の **本文**(問題・対応の説明) で技術用語を説明なしに使うこと
  - 例の悪い書き方: 「`validTargets` が kebab-case を期待しているため `HookEventName` と一致しない」
  - 例の良い書き方: 「フック名の大文字小文字が揃わず、機能が動いていない可能性があります」
  - 技術用語は「技術的位置 (開発者向け)」欄に隔離すれば OK
- ❌ `critical` / `major` / `minor` / `recommendation` の英単語を本文で使うこと
  - 代わりに「🔴 致命的」「🟠 重要」「🟡 軽微」「🟢 推奨」の日本語+絵文字表記を使用
- ❌ 「良かったところ」セクションを省略すること — APPROVE 時は必ず 2〜3 件の具体的な評価点を列挙(安心材料として非専門家に必要)

**ベースリファレンス透明性**: bare 呼び出しで Step 0.1 の上限フォールバックが発動した場合 (`>10 commits → HEAD~10`)、「対象」行には元の候補 ref と絞込後を併記すること。例: `対象: HEAD~10..HEAD (v4.0.0 から 21 commits のうち直近 10 を対象)`

#### 2. JSON 出力 (schema-v1、「📦 詳細データ」セクション内)

```json
{
  "schema_version": "review-result.v1",
  "verdict": "APPROVE | REQUEST_CHANGES",
  "reviewer_profile": "static | runtime | browser | security | ui-rubric",
  "calibration": {
    "label": "false_positive | false_negative | missed_bug | overstrict_rule",
    "source": "manual | post-review | retrospective",
    "notes": "観察メモ",
    "prompt_hint": "few-shot に使う要点",
    "few_shot_ready": true
  },
  "critical_issues": [],
  "major_issues": [],
  "observations": [
    {
      "severity": "critical | major | minor | recommendation",
      "category": "Security | Performance | Quality | Accessibility | AI Residuals",
      "location": "ファイル名:行番号",
      "issue": "問題の説明",
      "suggestion": "修正案"
    }
  ],
  "recommendations": ["必須ではない改善提案"]
}
```

browser review の場合は `scripts/generate-browser-review-artifact.sh` が `browser_mode` と route / required artifacts を決め、その後に `scripts/write-review-result.sh` で `.claude/state/review-result.json` に正規化して保存する。
このファイルは commit guard と後続フローの共通入力になる。
`calibration` が付くレビュー結果は `scripts/record-review-calibration.sh` で
`.claude/state/review-calibration.jsonl` に追記し、`scripts/build-review-few-shot-bank.sh`
で few-shot bank を更新する。

### Step 3.5: --dual フラグ時の Codex 並行レビュー

`--dual` フラグが指定されている場合、Step 3 の Claude レビューと並行して Codex レビューを実行し、結果をマージする。

1. Codex の利用可否を確認する（`scripts/codex-companion.sh setup --json`）
2. 利用可能であれば `scripts/codex-companion.sh review --base "${BASE_REF:-HEAD~1}"` を起動
3. 両方の verdict を Verdict マージルールで統合する
4. 最終レビュー結果に `dual_review` フィールドを付加する

詳細な手順・出力スキーマ・フォールバック仕様は [`${CLAUDE_SKILL_DIR}/references/dual-review.md`](${CLAUDE_SKILL_DIR}/references/dual-review.md) を参照。

### Step 3.6: --security フラグ時のセキュリティ専用レビュー

`--security` フラグが指定された場合、通常の 5 観点レビューを **スキップ**し、セキュリティ専用フローを実行する。

**Read-only 制約**: このフロー中は Write / Edit / 書き込み系 Bash を一切実行しない。

1. セキュリティプロファイルを読み込む:
   ```
   Read: ${CLAUDE_SKILL_DIR}/references/security-profile.md
   ```
2. OWASP Top 10 全カテゴリを変更差分・関連ファイルに対して確認する
3. 認証・認可フロー、秘密情報取り扱い、依存パッケージ脆弱性をチェックする
4. `reviewer_profile: "security"` を設定して結果を出力する（Step 3 の JSON スキーマに準拠）
5. Security モードの verdict 判定基準（security-profile.md 末尾参照）を適用する

通常の Code Review と `--security` の使い分け:

| | 通常の Code Review | `--security` |
|---|---|---|
| 観点 | Security, Performance, Quality, Accessibility, AI Residuals | Security のみ（OWASP Top 10 全項目） |
| 深度 | セキュリティは概要チェック | 認証・認可・暗号化・依存関係まで網羅 |
| ツール制限 | なし | Read / Grep / Glob / 読み取り Bash のみ |
| 用途 | PR マージ前の総合確認 | セキュリティ集中監査・リリース前の追加確認 |

### Step 3.7: --ui-rubric フラグ時の 4 軸デザインレビュー

`--ui-rubric` フラグが指定された場合、通常の 5 観点レビューを **スキップ**し、UI/デザイン品質に特化した 4 軸レビューを実行する。

1. UI rubric プロファイルを読み込む:
   ```
   Read: ${CLAUDE_SKILL_DIR}/references/ui-rubric.md
   ```
2. `Design Quality / Originality / Craft / Functionality` の 4 軸を 0-10 で採点する
3. `review.rubric_target` がある場合はその閾値と比較し、無ければ 4 軸すべての default threshold=6 を使う
4. 1 軸でも target 未達なら `REQUEST_CHANGES`、全軸到達で `APPROVE`
5. `reviewer_profile: "ui-rubric"` を設定して Step 3 の JSON スキーマで結果を出力する

通常の Code Review と `--ui-rubric` の使い分け:

| | 通常の Code Review | `--ui-rubric` |
|---|---|---|
| 観点 | Security, Performance, Quality, Accessibility, AI Residuals | Design Quality, Originality, Craft, Functionality |
| 判定方法 | 問題の重みで verdict 決定 | 4 軸の点数と threshold 比較 |
| 向いている対象 | 実装全般、PR 総合確認 | UI・スタイリング・レイアウト・見た目品質 |
| 用途 | 仕様逸脱やバグの洗い出し | 体験品質と見た目の完成度評価 |

### Step 4: コミット判定

- **APPROVE**: 自動コミット実行（`--no-commit` でなければ）
- **REQUEST_CHANGES**: critical/major の指摘箇所と修正方針を提示。`harness-work` の修正ループで自動修正後に再レビュー（最大 3 回）

## Plan Review フロー

1. Plans.md を読み込む
2. 以下の **5 観点** でレビュー:
   - **Clarity**: タスク説明が明確か
   - **Feasibility**: 技術的に実現可能か
   - **Dependencies**: タスク間の依存関係が正しいか（Depends カラムと実際の依存が一致しているか）
   - **Acceptance**: 完了条件（DoD カラム）が定義され、検証可能か
   - **Value**: このタスクはユーザー課題を解くか？
     - 「誰の、どんな問題」が明示されているか
     - 代替手段（作らない選択肢）は検討されたか
     - Elephant（全員気づいているが放置されている問題）はないか
3. DoD / Depends カラムの品質チェック:
   - DoD が空欄のタスク → 警告（「完了条件が未定義です」）
   - DoD が検証不能（「いい感じ」「ちゃんと動く」等） → 警告 + 具体化提案
   - Depends に存在しないタスク番号 → エラー
   - 循環依存 → エラー
4. 改善提案を提示

## Scope Review フロー

1. 追加されたタスク/機能をリスト化
2. 以下の観点で分析:
   - **Scope-creep**: 当初スコープからの逸脱
   - **Priority**: 優先度は適切か
   - **Feasibility**: 現在のリソースで実現可能か
   - **Impact**: 既存機能への影響
3. リスクと推奨アクションを提示

## 異常検知

| 状況 | アクション |
|------|----------|
| セキュリティ脆弱性 | 即座に REQUEST_CHANGES |
| テスト改ざん疑い | 警告 + 修正要求 |
| force push 試み | 拒否 + 代替案提示 |

## Codex Environment

Codex CLI 環境（`CODEX_CLI=1`）では一部ツールが利用不可のため、以下のフォールバックを使用する。

| 通常環境 | Codex フォールバック |
|---------|-------------------|
| `TaskList` でタスク一覧取得 | Plans.md を `Read` して WIP/TODO タスクを確認 |
| `TaskUpdate` でステータス更新 | Plans.md のマーカーを `Edit` で直接更新（例: `cc:WIP` → `cc:完了`） |
| レビュー結果を Task に書き込み | レビュー結果を stdout に出力 |

### 検出方法

```bash
if [ "${CODEX_CLI:-}" = "1" ]; then
  # Codex 環境: Plans.md ベースのフォールバック
fi
```

### Codex 環境でのレビュー出力

Task ツール非対応のため、レビュー結果は標準出力にマークダウン形式で出力する。
Lead エージェントまたはユーザーが結果を読み取り、次のアクションを判断する。

## `/ultrareview` との関係（方針 B: Harness flow 内では呼ばない）

CC 2.1.111 で追加された built-in `/ultrareview` は、ユーザーが CC に直接アドホックなレビューを
求める operator entrypoint として設計されている（`.claude/rules/opus-4-7-prompt-audit.md` ルール 5 参照）。

Harness の自動レビューフローは `/ultrareview` を**呼び出さない**。理由は以下の通り:

- `/ultrareview` の出力スキーマは `review-result.v1` と非互換であり、Harness の修正ループ・
  commit guard・sprint-contract 検証に接続できない
- Harness flow 内のレビューは `codex-companion.sh review`（優先）と `reviewer` agent
  （`review-result.v1` 出力・フォールバック）でカバーしており、追加の呼び出しパスは不要
- `/ultrareview` を Harness 内部で呼ぶと `review-result.v1` の機械可読保証が失われる

ユーザーがアドホックなレビューに `/ultrareview` を使う場合、Harness は干渉しない。
詳細な差分・使い分けガイドは [`docs/ultrareview-policy.md`](../../docs/ultrareview-policy.md) を参照。

## 関連スキル

- `harness-work` — レビュー後に修正を実装
- `harness-plan` — 計画を作成・修正
- `harness-release` — レビュー通過後にリリース
