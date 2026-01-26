#!/usr/bin/env node
/**
 * build-opencode.js
 *
 * Harness コマンドを opencode.ai 互換形式に変換するスクリプト
 *
 * 変換内容:
 * - commands/ → opencode/commands/ にコピー
 * - frontmatter から description-en を削除
 * - CLAUDE.md → AGENTS.md として生成
 *
 * 使用方法:
 *   node scripts/build-opencode.js
 */

const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.join(__dirname, '..');
const COMMANDS_DIR = path.join(ROOT_DIR, 'commands');
const SKILLS_DIR = path.join(ROOT_DIR, 'skills');
const OPENCODE_DIR = path.join(ROOT_DIR, 'opencode');
const OPENCODE_COMMANDS_DIR = path.join(OPENCODE_DIR, 'commands');
const OPENCODE_SKILLS_DIR = path.join(OPENCODE_DIR, 'skills');
const OPENCODE_TEMPLATES_DIR = path.join(ROOT_DIR, 'templates', 'opencode', 'commands');
const OPENCODE_PM_DIR = path.join(OPENCODE_COMMANDS_DIR, 'pm');

/**
 * ディレクトリを再帰的に作成
 */
function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

/**
 * ディレクトリを再帰的にクリア
 */
function clearDir(dir) {
  if (fs.existsSync(dir)) {
    fs.rmSync(dir, { recursive: true, force: true });
  }
}

/**
 * frontmatter を解析
 */
function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) {
    return { frontmatter: null, body: content };
  }

  const frontmatterStr = match[1];
  const body = content.slice(match[0].length);

  const frontmatter = {};
  const lines = frontmatterStr.split('\n');
  for (const line of lines) {
    const colonIndex = line.indexOf(':');
    if (colonIndex > 0) {
      const key = line.slice(0, colonIndex).trim();
      const value = line.slice(colonIndex + 1).trim();
      frontmatter[key] = value;
    }
  }

  return { frontmatter, body };
}

/**
 * frontmatter を文字列に変換
 */
function stringifyFrontmatter(frontmatter) {
  const lines = Object.entries(frontmatter)
    .map(([key, value]) => `${key}: ${value}`);
  return `---\n${lines.join('\n')}\n---\n`;
}

/**
 * Harness コマンドを opencode 形式に変換
 */
function convertCommand(content) {
  const { frontmatter, body } = parseFrontmatter(content);

  if (!frontmatter) {
    // frontmatter がない場合はそのまま返す
    return content;
  }

  // opencode で不要なフィールドを削除
  const opencodeFields = ['description-en', 'name'];
  for (const field of opencodeFields) {
    delete frontmatter[field];
  }

  // frontmatter が空になった場合
  if (Object.keys(frontmatter).length === 0) {
    return body;
  }

  return stringifyFrontmatter(frontmatter) + body;
}

/**
 * ディレクトリ内のファイルを再帰的に処理
 */
function processDirectory(srcDir, destDir) {
  ensureDir(destDir);

  const entries = fs.readdirSync(srcDir, { withFileTypes: true });
  let processedCount = 0;

  for (const entry of entries) {
    const srcPath = path.join(srcDir, entry.name);
    const destPath = path.join(destDir, entry.name);

    if (entry.isDirectory()) {
      processedCount += processDirectory(srcPath, destPath);
    } else if (entry.name.endsWith('.md')) {
      const content = fs.readFileSync(srcPath, 'utf8');
      const converted = convertCommand(content);
      fs.writeFileSync(destPath, converted);
      processedCount++;
      console.log(`  ✓ ${path.relative(ROOT_DIR, destPath)}`);
    }
  }

  return processedCount;
}

/**
 * AGENTS.md を生成（CLAUDE.md の全文コピー）
 *
 * opencode.ai は AGENTS.md をルールファイルとして認識し、
 * CLAUDE.md をフォールバックとしてサポートする。
 * ここでは CLAUDE.md の内容をそのまま AGENTS.md として出力する。
 */
function generateAgentsMd() {
  const claudeMdPath = path.join(ROOT_DIR, 'CLAUDE.md');

  if (!fs.existsSync(claudeMdPath)) {
    console.log(`  ⚠ CLAUDE.md not found, skipping AGENTS.md generation`);
    return;
  }

  let claudeMdContent = fs.readFileSync(claudeMdPath, 'utf8');

  // タイトルを CLAUDE.md から AGENTS.md に変換
  // "# CLAUDE.md" または "# CLAUDE.md - ..." のパターンに対応
  claudeMdContent = claudeMdContent.replace(
    /^# CLAUDE\.md(\s*-\s*.*)?$/m,
    (match, suffix) => `# AGENTS.md${suffix || ''}`
  );

  // opencode 互換のヘッダーを追加
  const header = `<!-- Generated from CLAUDE.md by build-opencode.js -->
<!-- opencode.ai compatible version of Claude Code Harness -->

`;

  const agentsMd = header + claudeMdContent;

  const destPath = path.join(OPENCODE_DIR, 'AGENTS.md');
  fs.writeFileSync(destPath, agentsMd);
  console.log(`  ✓ ${path.relative(ROOT_DIR, destPath)} (from CLAUDE.md)`);
}

/**
 * opencode.json サンプルを生成
 */
function generateOpencodeJson() {
  const config = {
    "$schema": "https://opencode.ai/config.json",
    "mcp": {
      "harness": {
        "type": "local",
        "enabled": true,
        "command": ["node", "./path/to/claude-code-harness/mcp-server/dist/index.js"]
      }
    }
  };

  const destPath = path.join(OPENCODE_DIR, 'opencode.json');
  fs.writeFileSync(destPath, JSON.stringify(config, null, 2));
  console.log(`  ✓ ${path.relative(ROOT_DIR, destPath)}`);
}

/**
 * README.md を生成（既存の場合はスキップ）
 */
function generateReadme() {
  const destPath = path.join(OPENCODE_DIR, 'README.md');

  // 既存の README.md がある場合はスキップ
  if (fs.existsSync(destPath)) {
    console.log(`  ⏭ ${path.relative(ROOT_DIR, destPath)} (already exists, skipped)`);
    return;
  }

  const readme = `# Harness for OpenCode

Claude Code Harness の opencode.ai 互換版です。

## セットアップ

### 1. コマンドとスキルをプロジェクトにコピー

\`\`\`bash
# Harness をクローン
git clone https://github.com/Chachamaru127/claude-code-harness.git

# opencode 用ファイルをコピー
cp -r claude-code-harness/opencode/commands/ your-project/.opencode/commands/
cp -r claude-code-harness/opencode/skills/ your-project/.claude/skills/
cp claude-code-harness/opencode/AGENTS.md your-project/AGENTS.md
\`\`\`

### 2. MCP サーバーをセットアップ（オプション）

\`\`\`bash
# MCP サーバーをビルド
cd claude-code-harness/mcp-server
npm install
npm run build

# opencode.json をプロジェクトにコピーしてパスを調整
cp claude-code-harness/opencode/opencode.json your-project/
# opencode.json 内のパスを実際のパスに変更
\`\`\`

### 3. 利用開始

\`\`\`bash
cd your-project
opencode
\`\`\`

## 利用可能なコマンド

| コマンド | 説明 |
|----------|------|
| \`/harness-init\` | プロジェクトセットアップ |
| \`/plan-with-agent\` | 開発プラン作成 |
| \`/work\` | タスク実行 |
| \`/harness-review\` | コードレビュー |

## 利用可能なスキル

opencode.ai は \`.claude/skills/\` ディレクトリのスキルを自動認識します：

| スキル | 説明 |
|--------|------|
| \`docs\` | ドキュメント生成（NotebookLM YAML、スライド） |
| \`impl\` | 機能実装 |
| \`review\` | コードレビュー |
| \`verify\` | ビルド検証・エラー復旧 |
| \`auth\` | 認証・決済（Clerk, Stripe） |
| \`deploy\` | デプロイ（Vercel, Netlify） |
| \`ui\` | UIコンポーネント生成 |

## MCP ツール

MCP サーバー経由で以下のツールが利用可能です：

| ツール | 説明 |
|--------|------|
| \`harness_workflow_plan\` | プラン作成 |
| \`harness_workflow_work\` | タスク実行 |
| \`harness_workflow_review\` | コードレビュー |
| \`harness_session_broadcast\` | セッション間通知 |
| \`harness_status\` | 状態確認 |

## 制限事項

- Harness プラグインシステム（\`.claude-plugin/\`）は opencode では使用できません
- フックは opencode 側で別途設定が必要です

## 関連リンク

- [Claude Code Harness](https://github.com/Chachamaru127/claude-code-harness)
- [OpenCode Documentation](https://opencode.ai/docs/)
`;

  fs.writeFileSync(destPath, readme);
  console.log(`  ✓ ${path.relative(ROOT_DIR, destPath)}`);
}

/**
 * スキルをコピー（.claude/skills/ 互換形式）
 *
 * opencode.ai は .claude/skills/<name>/SKILL.md を認識する。
 * harness のスキルをそのままコピーする。
 */
function copySkills() {
  if (!fs.existsSync(SKILLS_DIR)) {
    console.log(`  ⚠ skills/ directory not found, skipping`);
    return 0;
  }

  // 既存のスキルディレクトリをクリア
  clearDir(OPENCODE_SKILLS_DIR);
  ensureDir(OPENCODE_SKILLS_DIR);

  const entries = fs.readdirSync(SKILLS_DIR, { withFileTypes: true });
  let copiedCount = 0;

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;

    const skillName = entry.name;
    const srcSkillDir = path.join(SKILLS_DIR, skillName);
    const destSkillDir = path.join(OPENCODE_SKILLS_DIR, skillName);

    // テスト用・開発用スキルはスキップ
    if (skillName.startsWith('test-') || skillName.startsWith('x-')) {
      console.log(`  ⏭ ${skillName}/ (dev/test skill, skipped)`);
      continue;
    }

    // SKILL.md が存在するか確認
    const skillMdPath = path.join(srcSkillDir, 'SKILL.md');
    if (!fs.existsSync(skillMdPath)) {
      console.log(`  ⏭ ${skillName}/ (no SKILL.md, skipped)`);
      continue;
    }

    // スキルディレクトリを再帰的にコピー
    copyDirectoryRecursive(srcSkillDir, destSkillDir);
    copiedCount++;
    console.log(`  ✓ ${skillName}/`);
  }

  return copiedCount;
}

/**
 * ディレクトリを再帰的にコピー
 */
function copyDirectoryRecursive(src, dest) {
  ensureDir(dest);

  const entries = fs.readdirSync(src, { withFileTypes: true });

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    // CLAUDE.md はスキップ（claude-mem の自動生成ファイル）
    if (entry.name === 'CLAUDE.md') {
      continue;
    }

    if (entry.isDirectory()) {
      copyDirectoryRecursive(srcPath, destPath);
    } else {
      fs.copyFileSync(srcPath, destPath);
    }
  }
}

/**
 * メイン処理
 */
function main() {
  console.log('🔄 Building opencode version...\n');

  // opencode ディレクトリをクリア
  clearDir(OPENCODE_COMMANDS_DIR);
  clearDir(OPENCODE_SKILLS_DIR);
  ensureDir(OPENCODE_DIR);

  // コマンドを変換
  console.log('📁 Converting commands:');
  const commandCount = processDirectory(COMMANDS_DIR, OPENCODE_COMMANDS_DIR);

  // PM コマンドを変換（templates/opencode/commands/ から）
  console.log('\n📁 Processing PM commands (from templates/opencode/):');
  let pmCount = 0;
  if (fs.existsSync(OPENCODE_TEMPLATES_DIR)) {
    pmCount = processDirectory(OPENCODE_TEMPLATES_DIR, OPENCODE_PM_DIR);
    console.log(`   PM Commands: ${pmCount} files`);
  } else {
    console.log('   ⚠ templates/opencode/commands/ not found, skipping PM commands');
  }

  // スキルをコピー
  console.log('\n📁 Copying skills:');
  const skillCount = copySkills();

  // 追加ファイルを生成
  console.log('\n📄 Generating additional files:');
  generateAgentsMd();
  generateOpencodeJson();
  generateReadme();

  console.log(`\n✅ Done!`);
  console.log(`   Commands: ${commandCount} files`);
  console.log(`   PM Commands: ${pmCount} files`);
  console.log(`   Skills: ${skillCount} directories`);
  console.log(`   Output: ${path.relative(process.cwd(), OPENCODE_DIR)}/`);
}

main();
