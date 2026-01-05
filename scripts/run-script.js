#!/usr/bin/env node
/**
 * run-script.js
 * Windows/Mac/Linux クロスプラットフォーム対応 bash スクリプトランナー
 *
 * 目的:
 * - Windows 環境で ${CLAUDE_PLUGIN_ROOT} のパス問題を解決
 * - C:\Users\... → /c/Users/... 形式に変換して bash に渡す
 *
 * 使用方法:
 *   node run-script.js <script-name> [args...]
 *   例: node run-script.js session-init
 *       node run-script.js pretooluse-guard
 *
 * hooks.json での使用:
 *   "command": "node ${CLAUDE_PLUGIN_ROOT}/scripts/run-script.js session-init"
 */

const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

// プラットフォーム検出
const isWindows = process.platform === 'win32';

/**
 * Windows パスを MSYS/Git Bash 形式に変換
 * C:\Users\foo → /c/Users/foo
 * \\server\share → //server/share
 */
function toMsysPath(windowsPath) {
  if (!windowsPath) return windowsPath;

  // バックスラッシュをスラッシュに変換
  let msysPath = windowsPath.replace(/\\/g, '/');

  // ドライブレター変換: C:/ → /c/
  const driveMatch = msysPath.match(/^([A-Za-z]):\//);
  if (driveMatch) {
    msysPath = '/' + driveMatch[1].toLowerCase() + msysPath.slice(2);
  }

  return msysPath;
}

/**
 * bash 実行ファイルのパスを検出
 */
function findBash() {
  if (!isWindows) {
    return 'bash';
  }

  // Windows: Git Bash の bash を探す
  const possiblePaths = [
    'C:\\Program Files\\Git\\bin\\bash.exe',
    'C:\\Program Files (x86)\\Git\\bin\\bash.exe',
    process.env.PROGRAMFILES + '\\Git\\bin\\bash.exe',
    process.env['PROGRAMFILES(X86)'] + '\\Git\\bin\\bash.exe',
    'C:\\msys64\\usr\\bin\\bash.exe',
    'C:\\msys32\\usr\\bin\\bash.exe',
  ];

  for (const bashPath of possiblePaths) {
    if (bashPath && fs.existsSync(bashPath)) {
      return bashPath;
    }
  }

  // フォールバック: PATH から bash を使用
  return 'bash';
}

/**
 * メイン処理
 */
function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    console.error('Usage: node run-script.js <script-name> [args...]');
    console.error('Example: node run-script.js session-init');
    process.exit(1);
  }

  const scriptName = args[0];
  const scriptArgs = args.slice(1);

  // スクリプトディレクトリを取得
  const scriptsDir = __dirname;

  // スクリプトパスを構築
  let scriptPath = path.join(scriptsDir, scriptName);

  // .sh 拡張子がなければ追加
  if (!scriptPath.endsWith('.sh')) {
    scriptPath += '.sh';
  }

  // スクリプトの存在確認
  if (!fs.existsSync(scriptPath)) {
    console.error(`Error: Script not found: ${scriptPath}`);
    process.exit(1);
  }

  // bash 実行ファイルを検出
  const bashPath = findBash();

  // Windows の場合はパスを MSYS 形式に変換
  let bashScriptPath = scriptPath;
  if (isWindows) {
    bashScriptPath = toMsysPath(scriptPath);
  }

  // 環境変数の準備
  const env = { ...process.env };

  if (isWindows) {
    // MSYS のパス変換を無効化（二重変換を防ぐ）
    env.MSYS_NO_PATHCONV = '1';
    env.MSYS2_ARG_CONV_EXCL = '*';

    // CLAUDE_PLUGIN_ROOT も変換
    if (env.CLAUDE_PLUGIN_ROOT) {
      env.CLAUDE_PLUGIN_ROOT = toMsysPath(env.CLAUDE_PLUGIN_ROOT);
    }
  }

  // bash スクリプトを実行
  const child = spawn(bashPath, [bashScriptPath, ...scriptArgs], {
    env,
    stdio: 'inherit',  // stdin/stdout/stderr を透過的に転送
    shell: false,
  });

  child.on('error', (err) => {
    console.error(`Failed to execute bash: ${err.message}`);
    if (isWindows) {
      console.error('Hint: Make sure Git Bash is installed');
    }
    process.exit(1);
  });

  child.on('exit', (code, signal) => {
    if (signal) {
      process.exit(1);
    }
    process.exit(code || 0);
  });
}

main();
