# /harness-mem - Claude-mem 統合セットアップ

Claude-mem をハーネス仕様にカスタマイズし、セッション跨ぎの品質・文脈維持を強化します。

---

## こう言えばOK

- 「**Claude-mem と連携させて**」→ このコマンド
- 「**セッション跨ぎの記憶を有効化**」→ このコマンド
- 「**harness-mem をセットアップ**」→ このコマンド

## できること（成果物）

- **Claude-mem のハーネス専用モード設定**: ガードレール発動、Plans.md 更新、SSOT 変更を自動記録
- **セッション跨ぎの学習**: 過去のミスや解決策を次回セッションで活用
- **日本語化オプション**: 観測値とサマリーを日本語で記録

---

## 前提条件

Claude-mem プラグインがインストールされている必要があります。
未インストールの場合は、このコマンドがインストールをサポートします。

---

## 実行フロー

### Step 1: Claude-mem インストール検出

```bash
# Claude-mem プラグインの存在確認
ls ~/.claude/plugins/marketplaces/thedotmack 2>/dev/null
```

**インストール済みの場合**: Step 2 へ

**未インストールの場合**:

> ⚠️ **Claude-mem がインストールされていません**
>
> セッション跨ぎの品質・文脈維持機能を利用するには
> Claude-mem のインストールが必要です。
>
> **Claude-mem とは？**
> - セッション間でコンテキストを永続化するプラグイン
> - 過去の作業履歴を自動記録・検索可能に
> - ハーネスと組み合わせると品質が累積的に向上
>
> インストールしますか？
> 1. **はい** - 今すぐインストール（推奨）
> 2. **いいえ** - Claude-mem なしで継続

**「はい」の場合**:

```bash
# マーケットプレイスから追加
/plugin marketplace add thedotmack/claude-mem

# インストール
/plugin install claude-mem
```

成功したら Step 2 へ。失敗した場合はエラーメッセージと手動インストール手順を表示。

---

### Step 2: 日本語化オプション確認

> 🌐 **Claude-mem の記録を日本語化しますか？**
>
> | オプション | 説明 |
> |-----------|------|
> | **日本語** | 観測値、サマリー、検索結果が日本語で記録されます |
> | **英語** | デフォルト設定（英語での記録） |
>
> 1. **日本語化する**（推奨：日本語環境の場合）
> 2. **英語のまま**

**選択結果を記録**: `$HARNESS_MEM_LANG` = `ja` or `en`

---

### Step 3: モードファイルの配置

ハーネス専用のモードファイルを Claude-mem に配置します。

```bash
# モードファイルのコピー先
CLAUDE_MEM_MODES_DIR="$HOME/.claude/plugins/marketplaces/thedotmack/plugin/modes"

# harness.json をコピー
cp templates/modes/harness.json "$CLAUDE_MEM_MODES_DIR/"

# 日本語版を選択した場合
if [ "$HARNESS_MEM_LANG" = "ja" ]; then
  cp templates/modes/harness--ja.json "$CLAUDE_MEM_MODES_DIR/"
fi
```

---

### Step 4: settings.json の更新

Claude-mem の設定ファイルを更新します。

```bash
# settings.json のパス
CLAUDE_MEM_SETTINGS="$HOME/.claude-mem/settings.json"

# 設定ファイルがない場合は作成
if [ ! -f "$CLAUDE_MEM_SETTINGS" ]; then
  mkdir -p "$HOME/.claude-mem"
  echo '{}' > "$CLAUDE_MEM_SETTINGS"
fi
```

**設定内容**:

```json
{
  "CLAUDE_MEM_MODE": "harness"  // または "harness--ja"
}
```

日本語を選択した場合は `"harness--ja"` を設定。

---

### Step 5: 完了確認

> ✅ **Claude-mem 統合が完了しました！**
>
> **設定内容:**
> - モード: `harness` (または `harness--ja`)
> - モードファイル: `~/.claude/plugins/marketplaces/thedotmack/plugin/modes/harness.json`
> - 設定ファイル: `~/.claude-mem/settings.json`
>
> **次回セッションから有効になります。**
>
> **確認方法:**
> - 次回セッション開始時に Claude-mem が harness モードで起動
> - `/sync-status` で Claude-mem の状態を確認
>
> **活用方法:**
> - `mem-search` スキルで過去の作業履歴を検索
> - session-init で過去のガードレール発動履歴を表示
> - `/sync-ssot-from-memory` で重要な観測値を SSOT に昇格

---

## ハーネスモードで記録される内容

### observation_types（観測タイプ）

| タイプ | 説明 | 絵文字 |
|-------|------|--------|
| `plan` | Plans.md へのタスク追加・更新 | 📋 |
| `implementation` | ハーネスルールに従った実装 | 🛠️ |
| `guard` | ガードレール発動（test-quality, implementation-quality） | 🛡️ |
| `review` | コードレビュー実施 | 🔍 |
| `ssot` | decisions.md/patterns.md 更新 | 📚 |
| `handoff` | PM ↔ Impl 役割移行 | 🤝 |
| `workflow` | ワークフロー改善・自動化 | ⚙️ |

### observation_concepts（観測コンセプト）

| コンセプト | 説明 |
|-----------|------|
| `test-quality` | テスト改ざん防止・品質強制 |
| `implementation-quality` | スタブ/モック/ハードコード防止 |
| `harness-pattern` | ハーネス特有の再利用パターン |
| `2-agent` | PM/Impl 協働パターン |
| `quality-gate` | 品質ゲート発動点 |
| `ssot-decision` | SSOT への決定記録 |

---

## ユースケース

### 1. セッション跨ぎガードレール

```
Day 1: テスト改ざんをブロック
Claude-mem: 記録「guard: it.skip() をブロック」

Day 3 (別セッション):
session-init: 「このプロジェクトでは過去2回テスト改ざんを防止」
→ 同じミスを事前に警告
```

### 2. 長期タスクの文脈維持

```
Week 1: Feature X の設計完了
Claude-mem: 記録「plan: Feature X 設計完了、RBAC採用」

Week 2 (別セッション):
session-init: 「前回: Feature X 設計完了。次: 実装フェーズ」
→ 即座に続きから開始
```

### 3. デバッグパターン学習

```
過去: CORS エラーを解決
Claude-mem: 記録「bugfix: CORS - Access-Control-Allow-Origin 追加」

現在: 同様のエラー発生
mem-search: 過去の解決策をヒット
→ 5分で解決（前回30分）
```

---

## トラブルシューティング

### Claude-mem が動作しない

```bash
# プラグイン一覧を確認
/plugin list

# Claude-mem の状態確認
ls ~/.claude/plugins/marketplaces/thedotmack

# 再インストール
/plugin uninstall claude-mem
/plugin install claude-mem
```

### モードが適用されない

```bash
# settings.json を確認
cat ~/.claude-mem/settings.json

# CLAUDE_MEM_MODE が設定されているか確認
# 正しい例: {"CLAUDE_MEM_MODE": "harness"}
```

### 日本語で記録されない

```bash
# harness--ja モードになっているか確認
cat ~/.claude-mem/settings.json
# → {"CLAUDE_MEM_MODE": "harness--ja"} であるべき

# モードファイルが存在するか確認
ls ~/.claude/plugins/marketplaces/thedotmack/plugin/modes/harness--ja.json
```

---

## 無効化

Claude-mem のハーネスモードを無効化する場合:

```bash
# settings.json を編集
# CLAUDE_MEM_MODE を "code" に戻す、または削除
```

```json
{
  "CLAUDE_MEM_MODE": "code"
}
```

---

## 関連コマンド・スキル

| コマンド/スキル | 用途 |
|---------------|------|
| `/sync-ssot-from-memory` | Claude-mem の重要な観測値を SSOT に昇格 |
| `mem-search` | 過去の作業履歴を検索 |
| `session-init` | セッション開始時に過去の文脈を表示（Claude-mem 統合時） |
| `/harness-init` | プロジェクト初期化（Claude-mem 統合は別途 `/harness-mem` で） |
