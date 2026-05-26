#!/usr/bin/env node
/**
 * build-opencode.js
 *
 * Harness コマンドとスキルを opencode.ai 互換形式に変換するスクリプト
 *
 * 変換内容:
 * - skills/ → opencode/skills/ にコピー
 * - commands/ → opencode/commands/ にコピー（存在する場合のみ）
 * - command frontmatter から description-en/name を削除
 * - skill frontmatter を OpenCode の認識フィールドへ正規化
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

function normalizeSkillName(name) {
  return String(name || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .replace(/-{2,}/g, '-');
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

function convertSkill(content, skillName) {
  const { frontmatter, body } = parseFrontmatter(content);
  const normalizedName = normalizeSkillName(skillName);

  if (!frontmatter) {
    return content;
  }

  const opencodeFrontmatter = {
    name: normalizedName,
    description: frontmatter.description || `${normalizedName} skill`,
  };

  for (const field of ['license', 'compatibility', 'metadata']) {
    if (frontmatter[field]) {
      opencodeFrontmatter[field] = frontmatter[field];
    }
  }

  return stringifyFrontmatter(opencodeFrontmatter) + body;
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
    "instructions": [
      "AGENTS.md"
    ],
    "permission": {
      "skill": {
        "*": "allow"
      }
    }
  };

  const destPath = path.join(OPENCODE_DIR, 'opencode.json');
  fs.writeFileSync(destPath, `${JSON.stringify(config, null, 2)}\n`);
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

This directory contains the opencode.ai-compatible distribution of Claude Code
Harness.

## Setup

### skills-primary Manual Setup

\`\`\`bash
git clone https://github.com/Chachamaru127/claude-code-harness.git

mkdir -p your-project/.opencode/skills
cp -r claude-code-harness/opencode/skills/* your-project/.opencode/skills/
cp claude-code-harness/opencode/AGENTS.md your-project/AGENTS.md
cp claude-code-harness/opencode/opencode.json your-project/opencode.json
\`\`\`

Commands are compatibility helpers only. Copy \`opencode/commands/\` to
\`.opencode/commands/\` only if you still use the older slash-command workflow.

## MCP Server Status

\`mcp-server/\` is development-only and distribution-excluded. It is not part of
the default OpenCode consumer setup, and this generated fallback README does
not document a default MCP build path.

Only add an MCP entry to \`opencode.json\` when you are developing that optional
server from a source checkout and can provide the actual command path yourself.

## Usage

\`\`\`bash
cd your-project
opencode
\`\`\`

Ask OpenCode to use the installed skills:

- Use the harness-plan skill to create a plan
- Use the harness-work skill to execute the next task
- Use the harness-review skill to review code

## Compatibility Commands

| Command | Description |
|----------|------|
| \`/harness-init\` | プロジェクトセットアップ |
| \`/plan-with-agent\` | 開発プラン作成 |
| \`/work\` | タスク実行 |
| \`/harness-review\` | コードレビュー |

## Skills

OpenCode discovers native skills from
\`.opencode/skills/<name>/SKILL.md\`.

| スキル | 説明 |
|--------|------|
| \`notebookLM\` | ドキュメント生成（NotebookLM YAML、スライド） |
| \`impl\` | 機能実装 |
| \`harness-review\` | コードレビュー |
| \`verify\` | ビルド検証・エラー復旧 |
| \`auth\` | 認証・決済（Clerk, Stripe） |
| \`deploy\` | デプロイ（Vercel, Netlify） |
| \`ui\` | UIコンポーネント生成 |

## 制限事項

- Harness プラグインシステム（\`.claude-plugin/\`）は opencode では使用できません
- \`mcp-server/\` は development-only and distribution-excluded です

## 関連リンク

- [Claude Code Harness](https://github.com/Chachamaru127/claude-code-harness)
- [OpenCode Documentation](https://opencode.ai/docs/)
`;

  fs.writeFileSync(destPath, readme);
  console.log(`  ✓ ${path.relative(ROOT_DIR, destPath)}`);
}

/**
 * スキルをコピー（OpenCode native skills 形式）
 *
 * opencode.ai は .opencode/skills/<name>/SKILL.md を認識する。
 * harness のスキルを OpenCode frontmatter に変換してコピーする。
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

  const skipSkills = new Set([
    'allow1',
    'cc-update-review',
    'claude-codex-upstream-update',
    'harness-release-internal',
    'zz-review-empty',
    'zz-review-escape',
  ]);

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;

    const skillName = entry.name;
    const opencodeSkillName = normalizeSkillName(skillName);
    const srcSkillDir = path.join(SKILLS_DIR, skillName);
    const destSkillDir = path.join(OPENCODE_SKILLS_DIR, opencodeSkillName);

    // テスト用・開発用・opencode 非対応スキルはスキップ
    if (skillName.startsWith('test-') || skillName.startsWith('x-') || skipSkills.has(skillName)) {
      console.log(`  ⏭ ${skillName}/ (dev/test/unsupported skill, skipped)`);
      continue;
    }

    if (!opencodeSkillName) {
      console.log(`  ⏭ ${skillName}/ (invalid opencode skill name, skipped)`);
      continue;
    }

    // SKILL.md が存在するか確認
    const skillMdPath = path.join(srcSkillDir, 'SKILL.md');
    if (!fs.existsSync(skillMdPath)) {
      console.log(`  ⏭ ${skillName}/ (no SKILL.md, skipped)`);
      continue;
    }

    // スキルディレクトリを再帰的にコピー
    copyDirectoryRecursive(srcSkillDir, destSkillDir, {
      convertSkillMd: true,
      skillName: opencodeSkillName,
    });
    copiedCount++;
    if (skillName === opencodeSkillName) {
      console.log(`  ✓ ${skillName}/`);
    } else {
      console.log(`  ✓ ${skillName}/ → ${opencodeSkillName}/`);
    }
  }

  return copiedCount;
}

/**
 * ディレクトリを再帰的にコピー
 */
function copyDirectoryRecursive(src, dest, options = {}) {
  ensureDir(dest);

  const entries = fs.readdirSync(src, { withFileTypes: true });

  // 除外するディレクトリ/ファイルパターン
  const excludePatterns = [
    'CLAUDE.md',           // 自動生成されるメモリコンテキスト
    'node_modules',        // npm 依存関係
    'coverage',            // テストカバレッジ
    '.claude',             // Claude セッション状態
  ];

  // 除外するファイル名パターン（startsWith）
  const excludePrefixes = [
    'IMPLEMENTATION_',     // 開発途中ドキュメント
    'TASK_',               // タスク関連ドキュメント
  ];

  for (const entry of entries) {
    const srcPath = path.join(src, entry.name);
    const destPath = path.join(dest, entry.name);

    // 完全一致で除外
    if (excludePatterns.includes(entry.name)) {
      continue;
    }

    // プレフィックスで除外
    if (excludePrefixes.some(prefix => entry.name.startsWith(prefix))) {
      continue;
    }

    if (entry.isDirectory()) {
      copyDirectoryRecursive(srcPath, destPath, options);
    } else {
      if (options.convertSkillMd && entry.name === 'SKILL.md') {
        const content = fs.readFileSync(srcPath, 'utf8');
        fs.writeFileSync(destPath, convertSkill(content, options.skillName));
      } else {
        fs.copyFileSync(srcPath, destPath);
      }
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

  // コマンドを変換（v2.17.0+: commands/ は Skills に移行済み、存在する場合のみ処理）
  console.log('📁 Converting commands:');
  let commandCount = 0;
  if (fs.existsSync(COMMANDS_DIR)) {
    const commandEntries = fs.readdirSync(COMMANDS_DIR);
    if (commandEntries.length === 0) {
      console.log('  ⏭ commands/ is empty (migrated to skills in v2.17.0+)');
    } else {
      commandCount = processDirectory(COMMANDS_DIR, OPENCODE_COMMANDS_DIR);
    }
  } else {
    console.log('  ⏭ commands/ not found (migrated to skills in v2.17.0+)');
  }

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
