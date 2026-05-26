#!/usr/bin/env node
/**
 * validate-opencode.js
 *
 * opencode 用に変換されたファイルが正しい形式かを検証
 *
 * 検証内容:
 * - command / skill frontmatter が opencode 仕様に合っているか
 * - 必須ファイルが存在するか
 * - JSON ファイルが有効か
 *
 * 使用方法:
 *   node scripts/validate-opencode.js
 *
 * 終了コード:
 *   0: 検証成功
 *   1: 検証失敗
 */

const fs = require('fs');
const path = require('path');

const ROOT_DIR = path.join(__dirname, '..');
const OPENCODE_DIR = path.join(ROOT_DIR, 'opencode');

const COMMAND_INVALID_FIELDS = ['description-en', 'name'];
const SKILL_ALLOWED_FIELDS = new Set(['name', 'description', 'license', 'compatibility', 'metadata']);
const SKILL_NAME_PATTERN = /^[a-z0-9]+(-[a-z0-9]+)*$/;

// 必須ファイル（v2.17.0+: commands は Skills に移行済み、skills が必須）
const REQUIRED_FILES = [
  'opencode/AGENTS.md',
  'opencode/opencode.json',
  'opencode/README.md',
  'opencode/skills',  // Skills are now the primary mechanism
  'opencode/plugins/harness-bootstrap.mjs',
];

let errors = [];
let warnings = [];

/**
 * frontmatter を解析
 */
function parseFrontmatter(content) {
  const match = content.match(/^---\n([\s\S]*?)\n---\n/);
  if (!match) {
    return null;
  }

  const frontmatterStr = match[1];
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

  return frontmatter;
}

/**
 * コマンドファイルを検証
 */
function validateCommandFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const frontmatter = parseFrontmatter(content);
  const relativePath = path.relative(ROOT_DIR, filePath);

  if (!frontmatter) {
    // frontmatter がないファイルは警告のみ
    warnings.push(`${relativePath}: No frontmatter found`);
    return;
  }

  // 無効なフィールドをチェック
  for (const field of COMMAND_INVALID_FIELDS) {
    if (frontmatter[field]) {
      errors.push(`${relativePath}: Invalid field '${field}' found in frontmatter`);
    }
  }

  // description がない場合は警告
  if (!frontmatter.description) {
    warnings.push(`${relativePath}: Missing 'description' field`);
  }
}

function validateSkillFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const frontmatter = parseFrontmatter(content);
  const relativePath = path.relative(ROOT_DIR, filePath);
  const skillDirName = path.basename(path.dirname(filePath));

  if (!frontmatter) {
    errors.push(`${relativePath}: Missing required YAML frontmatter`);
    return;
  }

  for (const field of Object.keys(frontmatter)) {
    if (!SKILL_ALLOWED_FIELDS.has(field)) {
      errors.push(`${relativePath}: Unsupported OpenCode skill field '${field}' found in frontmatter`);
    }
  }

  if (!frontmatter.name) {
    errors.push(`${relativePath}: Missing required 'name' field`);
  } else {
    const skillName = frontmatter.name.replace(/^["']|["']$/g, '');
    if (skillName.length < 1 || skillName.length > 64) {
      errors.push(`${relativePath}: Invalid skill name length '${skillName}' (expected 1-64 characters)`);
    }
    if (!SKILL_NAME_PATTERN.test(skillName)) {
      errors.push(`${relativePath}: Invalid skill name '${skillName}' (expected lowercase kebab-case)`);
    }
    if (skillName !== skillDirName) {
      errors.push(`${relativePath}: Skill name '${skillName}' must match directory '${skillDirName}'`);
    }
  }

  if (!frontmatter.description) {
    errors.push(`${relativePath}: Missing required 'description' field`);
  } else {
    const description = frontmatter.description.replace(/^["']|["']$/g, '');
    if (description.length < 1 || description.length > 1024) {
      errors.push(`${relativePath}: Invalid description length (expected 1-1024 characters)`);
    }
  }
}

/**
 * ディレクトリ内のファイルを再帰的に検証
 */
function validateDirectory(dir) {
  if (!fs.existsSync(dir)) {
    errors.push(`Directory not found: ${path.relative(ROOT_DIR, dir)}`);
    return;
  }

  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      validateDirectory(fullPath);
    } else if (entry.name.endsWith('.md')) {
      validateCommandFile(fullPath);
    }
  }
}

function validateSkillsDirectory(dir) {
  if (!fs.existsSync(dir)) {
    errors.push(`Directory not found: ${path.relative(ROOT_DIR, dir)}`);
    return;
  }

  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory()) {
      continue;
    }

    const skillFile = path.join(dir, entry.name, 'SKILL.md');
    if (!fs.existsSync(skillFile)) {
      errors.push(`${path.relative(ROOT_DIR, path.join(dir, entry.name))}: Missing SKILL.md`);
      continue;
    }

    validateSkillFile(skillFile);
  }
}

/**
 * JSON ファイルを検証
 */
function validateJsonFile(filePath) {
  const relativePath = path.relative(ROOT_DIR, filePath);

  if (!fs.existsSync(filePath)) {
    errors.push(`File not found: ${relativePath}`);
    return;
  }

  try {
    const content = fs.readFileSync(filePath, 'utf8');
    JSON.parse(content);
  } catch (e) {
    errors.push(`${relativePath}: Invalid JSON - ${e.message}`);
  }
}

/**
 * 必須ファイルの存在を確認
 */
function validateRequiredFiles() {
  for (const file of REQUIRED_FILES) {
    const fullPath = path.join(ROOT_DIR, file);
    if (!fs.existsSync(fullPath)) {
      errors.push(`Required file/directory not found: ${file}`);
    }
  }
}

/**
 * opencode.json の構造を検証
 */
function validateOpencodeConfig() {
  const configPath = path.join(OPENCODE_DIR, 'opencode.json');

  if (!fs.existsSync(configPath)) {
    return; // 既に必須ファイルチェックでエラー出力済み
  }

  try {
    const content = fs.readFileSync(configPath, 'utf8');
    const config = JSON.parse(content);

    // $schema の存在確認
    if (!config.$schema) {
      warnings.push('opencode/opencode.json: Missing $schema field');
    }

    if (!Array.isArray(config.instructions) || !config.instructions.includes('AGENTS.md')) {
      errors.push('opencode/opencode.json: Missing instructions entry for AGENTS.md');
    }

    const skillPermission = config.permission && config.permission.skill;
    if (!skillPermission || skillPermission['*'] !== 'allow') {
      errors.push('opencode/opencode.json: Missing permission.skill wildcard allow');
    }

    const serialized = JSON.stringify(config);
    if (serialized.includes('mcp-server')) {
      errors.push('opencode/opencode.json: Must not default to a development-only mcp-server path');
    }

    // mcp 設定の存在確認。OpenCode sample config may include custom MCP, but
    // the generated default must not point at development-only mcp-server.
    if (config.mcp && config.mcp.harness) {
      const harness = config.mcp.harness;
      if (harness.type !== 'local' && harness.type !== 'remote') {
        errors.push('opencode/opencode.json: Invalid mcp.harness.type (must be "local" or "remote")');
      }
    }
  } catch (e) {
    // JSON パースエラーは既に出力済み
  }
}

function validateOpenCodeSetupSurface() {
  const readmePath = path.join(OPENCODE_DIR, 'README.md');
  const localSetupPath = path.join(ROOT_DIR, 'scripts', 'opencode-setup-local.sh');
  const remoteSetupPath = path.join(ROOT_DIR, 'scripts', 'setup-opencode.sh');
  const buildPath = path.join(ROOT_DIR, 'scripts', 'build-opencode.js');
  const bootstrapPluginPath = path.join(OPENCODE_DIR, 'plugins', 'harness-bootstrap.mjs');

  const readText = (filePath) => {
    if (!fs.existsSync(filePath)) {
      errors.push(`File not found: ${path.relative(ROOT_DIR, filePath)}`);
      return '';
    }
    return fs.readFileSync(filePath, 'utf8');
  };

  const readme = readText(readmePath);
  if (!readme.includes('.opencode/skills')) {
    errors.push('opencode/README.md: Must document .opencode/skills as the primary setup path');
  }
  if (!readme.includes('.opencode/plugins/harness-bootstrap.mjs')) {
    errors.push('opencode/README.md: Must document the Harness bootstrap plugin');
  }
  if (!readme.includes('AGENTS.md') || !readme.includes('opencode.json')) {
    errors.push('opencode/README.md: Must document AGENTS.md and opencode.json setup');
  }
  if (!readme.includes('development-only and distribution-excluded')) {
    errors.push('opencode/README.md: Must describe mcp-server/ as development-only and distribution-excluded');
  }

  const forbiddenConsumerDefaults = [
    'cp -r claude-code-harness/opencode/commands/ your-project/.opencode/commands/',
    'cp -r claude-code-harness/opencode/skills/ your-project/.claude/skills/',
    'cd claude-code-harness/mcp-server',
    'mcp-server/dist/index.js',
  ];

  for (const pattern of forbiddenConsumerDefaults) {
    if (readme.includes(pattern)) {
      errors.push(`opencode/README.md: Stale consumer-default setup found: ${pattern}`);
    }
  }

  const setupFiles = [
    ['scripts/opencode-setup-local.sh', readText(localSetupPath)],
    ['scripts/setup-opencode.sh', readText(remoteSetupPath)],
  ];

  for (const [label, content] of setupFiles) {
    if (!content.includes('.opencode/skills')) {
      errors.push(`${label}: Must install skills into .opencode/skills`);
    }
    if (!content.includes('.opencode/plugins/harness-bootstrap.mjs')) {
      errors.push(`${label}: Must install the OpenCode bootstrap plugin`);
    }
    if (!content.includes('AGENTS.md')) {
      errors.push(`${label}: Must verify or install AGENTS.md`);
    }
    if (!content.includes('opencode.json')) {
      errors.push(`${label}: Must verify or install opencode.json`);
    }
    if (content.includes('PROJECT_DIR/.claude/skills') || content.includes('Skills copied to .claude/skills')) {
      errors.push(`${label}: Must not install OpenCode skills into .claude/skills by default`);
    }
    if (content.includes('opencode/commands not found in Harness')) {
      errors.push(`${label}: Must not require opencode/commands for skills-primary setup`);
    }
    if (content.includes('cd claude-code-harness/mcp-server') || content.includes('npm run build')) {
      errors.push(`${label}: Must not document mcp-server build as consumer default`);
    }
  }

  const buildContent = readText(buildPath);
  const fallbackStart = buildContent.indexOf('const readme = `# Harness for OpenCode');
  const fallbackReadme = fallbackStart >= 0 ? buildContent.slice(fallbackStart) : buildContent;
  if (!fallbackReadme.includes('.opencode/skills')) {
    errors.push('scripts/build-opencode.js: Generated README fallback must document .opencode/skills');
  }
  for (const pattern of forbiddenConsumerDefaults) {
    if (fallbackReadme.includes(pattern)) {
      errors.push(`scripts/build-opencode.js: Stale generated README fallback found: ${pattern}`);
    }
  }

  const bootstrapPlugin = readText(bootstrapPluginPath);
  if (!bootstrapPlugin.includes('export const HarnessBootstrapPlugin')) {
    errors.push('opencode/plugins/harness-bootstrap.mjs: Missing HarnessBootstrapPlugin export');
  }
  if (!bootstrapPlugin.includes('experimental.chat.messages.transform')) {
    errors.push('opencode/plugins/harness-bootstrap.mjs: Missing bootstrap transform hook');
  }
  if (!bootstrapPlugin.includes('HARNESS_BOOTSTRAP')) {
    errors.push('opencode/plugins/harness-bootstrap.mjs: Missing bootstrap marker');
  }
  if (!bootstrapPlugin.includes('not_observed != absent')) {
    errors.push('opencode/plugins/harness-bootstrap.mjs: Missing unknown-data boundary');
  }
}

/**
 * メイン処理
 */
function main() {
  console.log('🔍 Validating opencode files...\n');

  // 必須ファイルの存在確認
  console.log('📁 Checking required files...');
  validateRequiredFiles();

  // コマンドファイルの検証
  console.log('📄 Validating command files...');
  const commandsDir = path.join(OPENCODE_DIR, 'commands');
  if (fs.existsSync(commandsDir)) {
    validateDirectory(commandsDir);
  }

  // スキルファイルの検証
  console.log('🧩 Validating skill files...');
  validateSkillsDirectory(path.join(OPENCODE_DIR, 'skills'));

  // JSON ファイルの検証
  console.log('📋 Validating JSON files...');
  validateJsonFile(path.join(OPENCODE_DIR, 'opencode.json'));
  validateOpencodeConfig();

  // OpenCode setup surface の検証
  console.log('🧭 Validating setup surface...');
  validateOpenCodeSetupSurface();

  // 結果出力
  console.log('\n' + '='.repeat(50));

  if (warnings.length > 0) {
    console.log('\n⚠️  Warnings:');
    for (const warning of warnings) {
      console.log(`   ${warning}`);
    }
  }

  if (errors.length > 0) {
    console.log('\n❌ Errors:');
    for (const error of errors) {
      console.log(`   ${error}`);
    }
    console.log(`\n❌ Validation failed with ${errors.length} error(s).`);
    process.exit(1);
  }

  console.log('\n✅ Validation passed!');
  if (warnings.length > 0) {
    console.log(`   (${warnings.length} warning(s))`);
  }
  process.exit(0);
}

main();
