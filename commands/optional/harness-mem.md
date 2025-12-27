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

### Step 0: OS 検出

```bash
# OS を検出
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ -n "$WINDIR" ]]; then
  OS_TYPE="windows"
elif [[ "$OSTYPE" == "darwin"* ]]; then
  OS_TYPE="mac"
else
  OS_TYPE="linux"
fi
echo "検出された OS: $OS_TYPE"
```

**Windows が検出された場合**:

```bash
# claude-mem のバージョンを確認
cat ~/.claude/plugins/marketplaces/thedotmack/plugin/package.json | grep version
```

> **claude-mem のバージョンによって推奨が異なります**
>
> | バージョン | 推奨 |
> |-----------|------|
> | **v7.3.7 以降** | ✅ Windows ネイティブでも動作可能（改善済み） |
> | **v7.3.6 以前** | ⚠️ WSL を強く推奨（port 37777 問題が頻発） |
>
> ---
>
> ### v7.3.7 以降の場合
>
> Windows ネイティブでの動作が大幅に改善されました:
> - ゾンビプロセスの自動排除
> - ワーカー起動タイムアウトの延長（30秒）
> - Bun ベースのワーカーラッパー
>
> **→ Step 3.5（Windows 設定）へ進んでください。**
>
> ---
>
> ### v7.3.6 以前の場合
>
> **WSL の使用を強く推奨します。**
>
> **根本原因**:
> - PowerShell スクリプト（.ps1）の実行問題
> - ファイル関連付けの破損
> - ゾンビプロセスがポートを占有
>
> **WSL では発生しない理由**:
> - シェルスクリプトがネイティブ実行される
> - ファイル関連付けに依存しない
> - Unix 標準のプロセス管理
>
> | 選択肢 | 推奨度 |
> |--------|--------|
> | **WSL で Claude Code を実行** | ⭐⭐⭐ 強く推奨 |
> | Windows ネイティブ | ⚠️ 問題発生リスク高 |
>
> **→ Step 3.6（WSL セットアップ）へ進んでください。**
>
> ---
>
> ### アップグレード推奨
>
> v7.3.6 以前を使用中の場合は、最新版へのアップグレードを推奨:
>
> ```bash
> /plugin marketplace remove thedotmack/claude-mem
> /plugin marketplace add thedotmack/claude-mem
> /plugin install claude-mem
> ```

---

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

### Step 3.5: Windows 固有設定（Windows のみ）

> **claude-mem v7.3.7 以降**: Windows ネイティブでの動作が改善されました ✅
>
> **v7.3.6 以前**: 以下の問題が発生する可能性があります ⚠️
>
> | 問題 | 原因 | v7.3.7 での対応 |
> |------|------|----------------|
> | ワーカー起動失敗 | PowerShell (.ps1) の実行問題 | Bun ラッパーに移行 |
> | port 37777 タイムアウト | ゾンビプロセス | 自動プロセス排除 |
> | 起動待機タイムアウト | 短すぎるタイムアウト | 30秒に延長 |
>
> **v7.3.6 以前を使用中の場合**: 最新版へのアップグレードまたは Step 3.6（WSL）を推奨

Windows では `.sh` ファイルを直接実行できない問題があるため、追加設定が必要です。

> ⚠️ **Windows 環境を検出しました**
>
> Claude-mem が正しく動作するために、以下の設定を行います:
>
> 1. **MCP 設定の調整**: `cmd /c` ラッパーを使用
> 2. **パス形式の変換**: Windows パス形式に対応

**設定ファイルの更新**:

プロジェクトの `.mcp.json` または `~/.claude/mcp.json` に以下を追加:

```json
{
  "mcpServers": {
    "claude-mem": {
      "command": "cmd",
      "args": ["/c", "npx", "-y", "claude-mem-mcp"],
      "env": {
        "CLAUDE_MEM_MODE": "harness"
      }
    }
  }
}
```

**代替設定（npx フルパス指定）**:

npx が見つからない場合は、フルパスを指定:

```json
{
  "mcpServers": {
    "claude-mem": {
      "command": "C:\\Program Files\\nodejs\\npx.cmd",
      "args": ["-y", "claude-mem-mcp"],
      "env": {
        "CLAUDE_MEM_MODE": "harness"
      }
    }
  }
}
```

**WSL を使用する場合（推奨）**:

WSL 環境で Claude Code を実行している場合は、Unix 設定がそのまま使用できます。

```json
{
  "mcpServers": {
    "claude-mem": {
      "command": "npx",
      "args": ["-y", "claude-mem-mcp"],
      "env": {
        "CLAUDE_MEM_MODE": "harness"
      }
    }
  }
}
```

---

### Step 3.6: WSL 環境セットアップ（Windows + WSL の場合）

Windows ネイティブではなく WSL で Claude Code を実行する場合の詳細設定です。

#### 前提条件の確認

```bash
# 1. WSL2 がインストールされているか確認（PowerShell で実行）
wsl --version

# 2. WSL 内で Node.js が Linux 版か確認
wsl -e bash -c "which node && which npm"
# 正しい例: /usr/bin/node, /usr/bin/npm
# 問題あり: /mnt/c/Program Files/nodejs/node（Windows 版を参照している）
```

#### /bin/bash が見つからない問題の解決

**症状**:
```
/bin/bash: line 1: sh: command not found
```

**原因**: WSL の PATH に Windows の Node.js/npm が優先されている

**解決策**:

```bash
# 1. WSL 内で実行 - Windows PATH を無効化
echo '[interop]
appendWindowsPath = false' | sudo tee -a /etc/wsl.conf

# 2. WSL を再起動（PowerShell で実行）
wsl --shutdown

# 3. WSL 内で Node.js をインストール（nvm 推奨）
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
source ~/.bashrc
nvm install --lts
nvm use --lts

# 4. 確認
which node  # → /home/user/.nvm/versions/node/v20.x.x/bin/node
which npm   # → /home/user/.nvm/versions/node/v20.x.x/bin/npm
```

#### ワーカーが port 37777 で起動しない問題の解決

**症状**:
```
Worker service failed to start on port 37777
Worker failed to start (readiness check timed out after 20000ms)
```

**原因**: ゾンビプロセスがポートを占有、または前回のワーカーが正常終了しなかった

**解決策**:

```bash
# 1. ポート 37777 の使用状況を確認
# WSL 内
lsof -i :37777
# または Windows（PowerShell）
netstat -ano | findstr 37777

# 2. ゾンビプロセスを終了
# WSL 内
pkill -f "claude-mem"
pkill -f "bun"

# Windows（PowerShell - 管理者権限）
taskkill /F /IM bun.exe
taskkill /F /IM node.exe

# 3. ワーカーログを確認
cat ~/.claude-mem/logs/worker.log

# 4. ワーカーを手動で再起動
cd ~/.claude/plugins/marketplaces/thedotmack
npm run worker:restart

# 5. Claude Code を再起動
```

#### WSL でのファイルパフォーマンス最適化

```bash
# プロジェクトは WSL ファイルシステム内に配置（推奨）
# ✅ 良い例
cd ~/projects/my-app

# ❌ 悪い例（遅い）
cd /mnt/c/Users/username/projects/my-app
```

> ⚠️ `/mnt/c/` 配下はパフォーマンスが大幅に低下します。
> プロジェクトは `~/` 配下に配置してください。

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

### WSL: /bin/bash が見つからない

```
/bin/bash: line 1: sh: command not found
```

**原因**: WSL が Windows の PATH を継承し、Windows 版の Node.js を参照している

**解決策**: Step 3.6 の「/bin/bash が見つからない問題の解決」を参照

**関連 Issue**: [GitHub Issue #210](https://github.com/thedotmack/claude-mem/issues/210)

---

### WSL/Windows: ワーカーが port 37777 で起動しない

```
Worker service failed to start on port 37777
Worker failed to start (readiness check timed out after 20000ms)
```

> **まず claude-mem のバージョンを確認してください**
>
> ```bash
> cat ~/.claude/plugins/marketplaces/thedotmack/plugin/package.json | grep version
> ```
>
> | バージョン | 対応 |
> |-----------|------|
> | **v7.3.7 以降** | 下記のトラブルシューティングで解決可能 |
> | **v7.3.6 以前** | 最新版へのアップグレードを強く推奨 |

**v7.3.7 以降で問題が発生する場合**:

```bash
# 1. ゾンビプロセスを終了
taskkill /F /IM bun.exe       # Windows
taskkill /F /IM node.exe      # Windows

# 2. PID ファイルを削除
del %USERPROFILE%\.claude-mem\worker.pid

# 3. Claude Code を再起動
```

---

**v7.3.6 以前の場合（根本原因）**:

| 原因 | 詳細 |
|------|------|
| **PowerShell 実行問題** | `.ps1` ファイルが Notepad で開かれる、または実行ポリシー制限 |
| **ファイル関連付け破損** | `bun.ps1` ラッパーが正しく実行されない |
| **ゾンビプロセス** | 前回の `bun.exe` / `node.exe` がポートを占有 |
| **PID ファイル陳腐化** | `~/.claude-mem/worker.pid` が古いプロセス情報を保持 |

**なぜ WSL では発生しないか**:
- シェルスクリプトがネイティブ実行される
- ファイル関連付けに依存しない
- Unix 標準のプロセス管理（シグナル処理が確実）

**推奨解決策**:
1. **最新版へアップグレード**（推奨）
2. **WSL に移行する**（Step 3.6 参照）

**v7.3.6 以前での一時的な回避策**（効果は限定的）:

```bash
# 1. ポートの使用状況を確認
netstat -ano | findstr 37777  # Windows
lsof -i :37777                 # WSL/Linux

# 2. ゾンビプロセスを終了
taskkill /F /IM bun.exe       # Windows
taskkill /F /IM node.exe      # Windows
pkill -f "claude-mem"          # WSL/Linux

# 3. PID ファイルを削除
del %USERPROFILE%\.claude-mem\worker.pid  # Windows
rm ~/.claude-mem/worker.pid                # WSL/Linux

# 4. ワーカーを手動で再起動
cd ~/.claude/plugins/marketplaces/thedotmack
npm run worker:restart

# 5. または bun.exe を直接実行（PowerShell バイパス）
%USERPROFILE%\.bun\bin\bun.exe plugin/scripts/worker-service.cjs
```

> ⚠️ **注意**: 上記の回避策は一時的なもので、根本解決にはなりません。
> **WSL への移行を強く推奨します。**

**関連 Issue**:
- [Issue #380](https://github.com/thedotmack/claude-mem/issues/380) - Windows 11 port 37777 エラー
- [Issue #209](https://github.com/thedotmack/claude-mem/issues/209) - Windows でワーカーが起動しない

---

### Windows: ENOENT エラーが発生する

```
ENOENT: no such file or directory
C:\Users\user\AppData\Local\claude-cli-nodejs\Cache\...
```

**原因**: Windows のパス処理に関する既知の問題（[Issue #229](https://github.com/thedotmack/claude-mem/issues/229)）

**解決策**:

1. **WSL を使用する**（推奨）
   ```bash
   # WSL 内で Claude Code を実行
   wsl
   claude
   ```

2. **手動でディレクトリを作成**
   ```powershell
   mkdir -p $env:LOCALAPPDATA\claude-cli-nodejs\Cache
   ```

3. **Issue の修正を待つ**
   - [Issue #229](https://github.com/thedotmack/claude-mem/issues/229) をウォッチ

---

### Windows: npx が見つからない

**原因**: PATH に Node.js が含まれていない

**解決策**:

```json
// .mcp.json で絶対パスを指定
{
  "mcpServers": {
    "claude-mem": {
      "command": "C:\\Program Files\\nodejs\\npx.cmd",
      "args": ["-y", "claude-mem-mcp"]
    }
  }
}
```

---

### Windows: VSCode/Cursor で .sh が開いてしまう

**原因**: Windows のファイル関連付けの問題（[Issue #9758](https://github.com/anthropics/claude-code/issues/9758)）

**解決策**: hooks.json で `bash` プレフィックスを使用

```json
// 修正前
"command": "${CLAUDE_PLUGIN_ROOT}/scripts/example.sh"

// 修正後
"command": "bash ${CLAUDE_PLUGIN_ROOT}/scripts/example.sh"
```

> ⚠️ **harness v2.6.7 以降では自動適用済み**

---

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

## Cursor 統合（オプション）

### 概要

Cursor IDE から Claude-mem の MCP サーバーにアクセスし、過去のセッション記録を検索・新しい観測を記録できます。

### メリット

- **PM（Cursor）と実装（Claude Code）の役割分担**: 設計判断はCursorで記録、実装はClaude Codeが過去の判断を参照
- **双方向のデータ共有**: 同じメモリデータベースを共有（WALモードで並行書き込み対応）
- **クロスツール検索**: Cursorで記録した内容をClaude Codeで検索、その逆も可能

### セットアップ手順

詳細は [docs/guides/cursor-mem-integration.md](../../docs/guides/cursor-mem-integration.md) を参照してください。

#### 簡易手順

1. **MCPラッパースクリプトの配置**
   ```bash
   # claude-code-harness プラグインがインストール済みであれば、
   # scripts/claude-mem-mcp が既に存在します
   find ~/.claude/plugins/cache -name "claude-mem-mcp" -type f | grep claude-code-harness
   ```

2. **Cursor MCP設定**
   プロジェクトルートに `.cursor/mcp.json` を作成：
   ```json
   {
     "mcpServers": {
       "claude-mem": {
         "type": "stdio",
         "command": "/absolute/path/to/claude-code-harness/scripts/claude-mem-mcp"
       }
     }
   }
   ```

3. **Cursor再起動**
   設定後、Cursorを再起動してMCPサーバーを認識させます。

### 使用例

#### Cursorで過去の決定を検索

```
Cursor Composer: 「認証方式の選定理由を教えて」
→ mcp__claude-mem__search を使用
→ 過去の決定記録を取得
```

#### Cursorでレビュー結果を記録

```
Cursor Composer: 「このRLSポリシーのパターンを記録」
→ mcp__claude-mem__add_observations を使用
→ タグ: source:cursor, review, pattern
```

### 推奨ワークフロー

```
1. Cursor（PM役）: 設計判断やレビュー結果を記録
2. Claude Code（実装役）: 過去の判断を参照しながら実装
3. 双方向検索: どちらからでも過去の記録を検索可能
```

### トラブルシューティング

詳細は [docs/guides/cursor-mem-integration.md#トラブルシューティング](../../docs/guides/cursor-mem-integration.md#トラブルシューティング) を参照。

---

## 関連コマンド・スキル

| コマンド/スキル | 用途 |
|---------------|------|
| `/sync-ssot-from-memory` | Claude-mem の重要な観測値を SSOT に昇格 |
| `mem-search` | 過去の作業履歴を検索 |
| `session-init` | セッション開始時に過去の文脈を表示（Claude-mem 統合時） |
| `/harness-init` | プロジェクト初期化（Claude-mem 統合は別途 `/harness-mem` で） |
| `cursor-mem` | Cursor から Claude-mem を活用（統合セットアップ後） |
