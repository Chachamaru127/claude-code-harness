#!/usr/bin/env node
/**
 * validate-opencode.js
 *
 * opencode 用に変換されたファイルが正しい形式かを検証
 *
 * 検証内容:
 * - frontmatter に opencode 非対応フィールドがないか
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

// opencode で無効な frontmatter フィールド
const INVALID_FIELDS = ['description-en', 'name'];

// 必須ファイル（v2.17.0+: commands は Skills に移行済み、skills が必須）
const REQUIRED_FILES = [
  'opencode/AGENTS.md',
  'opencode/opencode.json',
  'opencode/README.md',
  'opencode/skills',  // Skills are now the primary mechanism
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
  for (const field of INVALID_FIELDS) {
    if (frontmatter[field]) {
      errors.push(`${relativePath}: Invalid field '${field}' found in frontmatter`);
    }
  }

  // description がない場合は警告
  if (!frontmatter.description) {
    warnings.push(`${relativePath}: Missing 'description' field`);
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

    // mcp 設定の存在確認
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

  // JSON ファイルの検証
  console.log('📋 Validating JSON files...');
  validateJsonFile(path.join(OPENCODE_DIR, 'opencode.json'));
  validateOpencodeConfig();

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
