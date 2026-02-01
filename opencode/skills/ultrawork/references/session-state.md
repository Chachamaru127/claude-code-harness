# Session State Management

ultrawork はセッション継続（compact/resume）後も正しく動作するため、セッション状態を永続化します。

## Phase 1: 初期化時の設定

ultrawork 開始時に以下を実行:

```bash
# 1. ultrawork-active.json を作成
cat > .claude/state/ultrawork-active.json <<EOF
{
  "active": true,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "bypass_guards": ["rm_rf", "git_push"],
  "allowed_rm_paths": ["node_modules", "dist", ".next", ".cache"],
  "review_status": "pending"
}
EOF

# 2. session.json に active_skill を記録（★ 必須）
jq '.active_skill = "ultrawork"' \
  .claude/state/session.json > tmp.$$.json && mv tmp.$$.json .claude/state/session.json
```

> ⚠️ `active_skill` を設定しないと、セッション継続後にスキル再起動の警告が表示されません。

## 完了処理時のクリア

ultrawork 完了時に以下を実行:

```bash
# 1. ultrawork-active.json を削除
rm -f .claude/state/ultrawork-active.json

# 2. session.json から active_skill を削除
jq 'del(.active_skill)' \
  .claude/state/session.json > tmp.$$.json && mv tmp.$$.json .claude/state/session.json
```

## セッション継続時の復元

セッションが継続（compact/resume）した場合、`session-resume.sh` が自動的に:

1. `session.json` の `active_skill` を検出
2. 「`/ultrawork 続きやって` でスキルを再起動してください」と強く促す
3. スキル再起動なしでの実装開始を警告

**これにより、スキル文脈なしでの作業開始を防止します。**

## Progress Display

```text
📊 /ultrawork Progress: Iteration 2/10

Range: Tasks 1-5
Completed: 2/5 tasks
Time elapsed: 2m 15s

├── Task 1: Create Header ✅ (iter 1, 25s)
├── Task 2: Create Footer ✅ (iter 2, 30s) [learned]
├── Task 3: Create Sidebar ⏳ In progress...
├── Task 4: Create Layout 🔜 Waiting
└── Task 5: Create Page 🔜 Waiting

Last iteration result:
├── Build: ✅ Pass
├── Tests: ⚠️ 14/15 pass
└── Review: ✅ No Critical/High
```
