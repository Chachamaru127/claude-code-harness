---
name: japanese-writing-drafter
description: "Detect when the operator corrects the agent's Japanese phrasing mid-conversation (rewrites a sentence, calls out a style problem, says 'this wording is bad, say it like X instead') and draft a pending writing-rule proposal into ~/.claude/writing-lint/proposals.jsonl for later human review. This skill is the ONLY writer of proposals.jsonl — it never edits rules.jsonl and never sets status to anything but pending. Promotion to rules.jsonl only happens via the human-run scripts/writing-rule-approve.sh. Use when user mentions writing-rule proposal, 表現を直して, 文体を直して, その言い方はNG, writing lint 提案, 指摘をルール化して. Do NOT load for: approving or rejecting proposals (use scripts/writing-rule-approve.sh), listing pending proposals (use scripts/writing-rule-list.sh), or scanning text against the existing dictionary (the writinglint engine / PostToolUse hook does that)."
description-en: "Detect when the operator corrects the agent's Japanese phrasing mid-conversation (rewrites a sentence, calls out a style problem, says 'this wording is bad, say it like X instead') and draft a pending writing-rule proposal into ~/.claude/writing-lint/proposals.jsonl for later human review. This skill is the ONLY writer of proposals.jsonl — it never edits rules.jsonl and never sets status to anything but pending. Promotion to rules.jsonl only happens via the human-run scripts/writing-rule-approve.sh. Use when user mentions writing-rule proposal, 表現を直して, 文体を直して, その言い方はNG, writing lint 提案, 指摘をルール化して. Do NOT load for: approving or rejecting proposals (use scripts/writing-rule-approve.sh), listing pending proposals (use scripts/writing-rule-list.sh), or scanning text against the existing dictionary (the writinglint engine / PostToolUse hook does that)."
description-ja: "会話内で operator が agent の日本語表現を直した（文を書き直した、文体を明示的に指摘した、「その言い方じゃなくてこう書いて」と言った）ことを検知し、~/.claude/writing-lint/proposals.jsonl へ pending の writing-rule 提案を追記する。このskillだけが proposals.jsonl に書き込み、rules.jsonl は一切編集せず、status は pending 以外にしない。rules.jsonl への昇格は人間が実行する scripts/writing-rule-approve.sh 経由のみ。Use when user mentions 表現を直して, 文体を直して, その言い方はNG, writing lint 提案, 指摘をルール化して. Do NOT load for: 提案の承認/却下 (scripts/writing-rule-approve.sh を使う), pending 一覧表示 (scripts/writing-rule-list.sh を使う), 既存辞書での文章スキャン (writinglint エンジン / PostToolUse hook の役割)。"
allowed-tools: ["Read", "Bash"]
user-invocable: true
---

# japanese-writing-drafter

会話内で operator が agent の日本語表現を直したときだけ、その指摘を pending の writing-rule 提案として `~/.claude/writing-lint/proposals.jsonl` に追記する。**提案の追記のみ**を行い、承認・却下・rules.jsonl への昇格は一切行わない。

## 核心契約

- **書き込みはこの skill 経由のみ**: `proposals.jsonl` に status: pending の行を追記できるのはこの skill だけ。他のどのスクリプト・hook もこのファイルに書き込まない。
- **自動昇格経路は存在しない**: `rules.jsonl` を更新できるのは人間が手で実行する `scripts/writing-rule-approve.sh --id <id>` だけ。この skill からも、他のどの hook からも `writing-rule-approve.sh` を自動起動しない。
- 1 回の検知につき 1 提案。status は常に `"pending"` で書く。

## トリガー条件

会話の中で、次のいずれかが起きたときだけ発動する（雑談・通常の作業指示では発動しない）。

- operator が直前の agent 発言・生成物の日本語表現をそのまま書き直した
- operator が「その言い方はNG」「〜じゃなくて…と書いて」のように文体・言い回しを名指しで指摘した
- operator が明示的に「これルール化して」「writing-lint に登録して」と言った

## 手順

1. **before / after を確定する**: 直された元の表現 (before) と、operator が示した / 暗に求めた書き直し後の表現 (after) を会話から抽出する。before が具体的な語句・言い回しに絞れないほど曖昧なら、提案せずに終える（無理に一般化しない）。
2. **pattern を作る**: before の該当フラグメントを Go 正規表現 (RE2) として書く。特殊文字はエスケープする。ヒット範囲を広げすぎない（`writing-rule.v1` の `pattern` は文全体ではなく該当箇所のみでよい）。
3. **good を作る**: after をそのまま、または要点を保った短い言い換えとして書く。
4. **scenes を決める**: 会話の文脈から分かるときだけ `["external"]` / `["chat"]` / `["docs"]` 等を付ける。不明なら省略する（省略は「全シーン適用」の意味になる。無理に推測しない）。
5. **id を作る**: 内容が分かる kebab-case スラッグに 8 桁の一意サフィックスを付ける（例: `no-meta-narration-a1b2c3d4`）。
6. **追記する**: 以下のコマンドで `templates/schemas/writing-rule-proposal.v1.json` に対する手書きバリデーション（必須キー + `additionalProperties: false`）を通してから 1 行追記する。`CLAUDE_WRITING_LINT_PROPOSALS` が設定されていればそのパスを、無ければ `~/.claude/writing-lint/proposals.jsonl` を使う。

```bash
python3 - <<'PY'
import json, os, sys, uuid
from datetime import datetime, timezone

repo_root = "REPO_ROOT"  # 呼び出し時に実際のリポジトリルートへ置き換える
schema_path = os.path.join(repo_root, "templates/schemas/writing-rule-proposal.v1.json")
proposals_path = os.environ.get("CLAUDE_WRITING_LINT_PROPOSALS") or os.path.join(
    os.path.expanduser("~"), ".claude/writing-lint/proposals.jsonl"
)

with open(schema_path, encoding="utf-8") as f:
    schema = json.load(f)

record = {
    "id": "SLUG-" + uuid.uuid4().hex[:8],
    "pattern": "PATTERN_HERE",
    "good": "GOOD_HERE",
    "status": "pending",
    "evidence": "EVIDENCE_HERE",
    "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
# scenes / severity は分かるときだけ足す:
# record["scenes"] = ["external"]
# record["severity"] = "warning"


def validate(data, sch):
    required = set(sch.get("required", []))
    props = sch.get("properties", {})
    if sch.get("additionalProperties") is False:
        extra = set(data.keys()) - set(props.keys())
        if extra:
            raise ValueError(f"additional properties not allowed: {sorted(extra)}")
    for key in required:
        if key not in data:
            raise ValueError(f"missing required property: {key}")


validate(record, schema)

os.makedirs(os.path.dirname(proposals_path) or ".", exist_ok=True)
with open(proposals_path, "a", encoding="utf-8") as f:
    f.write(json.dumps(record, ensure_ascii=False) + "\n")

print(f"drafted pending proposal: {record['id']}")
PY
```

7. **operator に伝える**: 追記した `id` と、確認・承認コマンド (`scripts/writing-rule-list.sh` / `scripts/writing-rule-approve.sh --id <id>`) を短く伝える。承認するかどうかは operator の判断であり、この skill は待たない。

## 関連

- 承認 / 却下: `scripts/writing-rule-approve.sh --id <id>` (`--reject` で却下)
- pending 一覧: `scripts/writing-rule-list.sh`
- スキーマ: `templates/schemas/writing-rule-proposal.v1.json` (提案) / `templates/schemas/writing-rule.v1.json` (承認後のルール)
- スキャンエンジン: `go/internal/writinglint/` (Phase 135.1)
