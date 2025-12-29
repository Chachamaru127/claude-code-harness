#!/usr/bin/env node

/**
 * Cursor Hooks - Common Utilities
 *
 * Worker API への記録、プロジェクト名抽出、エラーハンドリング
 */

/**
 * Worker API でセッションを初期化
 *
 * @param {Object} params
 * @param {string} params.sessionId - Cursor の conversation_id
 * @param {string} params.project - プロジェクト名
 * @param {string} params.prompt - ユーザープロンプト
 * @returns {Promise<Object|null>} {sessionDbId, promptNumber} または null（エラー時）
 */
async function initSession({
  sessionId,
  project,
  prompt
}) {
  const port = process.env.CLAUDE_MEM_WORKER_PORT || '37777';
  const host = process.env.CLAUDE_MEM_WORKER_HOST || '127.0.0.1';
  const url = `http://${host}:${port}/api/sessions/init`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        claudeSessionId: sessionId,
        project: project,
        prompt: prompt
      }),
      signal: AbortSignal.timeout(10000) // 10秒タイムアウト
    });

    if (!response.ok) {
      throw new Error(`Worker API returned ${response.status}: ${response.statusText}`);
    }

    const result = await response.json();

    if (result.skipped && result.reason === 'private') {
      console.error(`[cursor-hooks] Session ${result.sessionDbId}, prompt #${result.promptNumber} (fully private - skipped)`);
      return null;
    }

    console.error(`[cursor-hooks] Session ${result.sessionDbId}, prompt #${result.promptNumber} initialized`);
    return result;
  } catch (error) {
    // エラーは stderr に出力するが、フック自体は失敗させない
    console.error(`[cursor-hooks] Failed to initialize session: ${error.message}`);
    console.error(`[cursor-hooks] Session: ${sessionId}`);

    // Cursor の動作を止めないため、エラーを throw しない
    return null;
  }
}

/**
 * Worker API に観測データを記録
 *
 * @param {Object} params
 * @param {string} params.sessionId - Cursor の conversation_id
 * @param {string} params.toolName - ツール名（例: "UserPrompt", "Edit", "SessionStop"）
 * @param {Object|string} params.toolInput - ツール入力データ
 * @param {Object|string|null} params.toolResponse - ツール出力データ
 * @param {string} params.cwd - 作業ディレクトリ
 * @returns {Promise<void>}
 */
async function recordObservation({
  sessionId,
  toolName,
  toolInput,
  toolResponse,
  cwd
}) {
  const port = process.env.CLAUDE_MEM_WORKER_PORT || '37777';
  const host = process.env.CLAUDE_MEM_WORKER_HOST || '127.0.0.1';
  const url = `http://${host}:${port}/api/sessions/observations`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        claudeSessionId: sessionId,
        tool_name: toolName,
        tool_input: typeof toolInput === 'string' ? toolInput : JSON.stringify(toolInput),
        tool_response: toolResponse === null ? null : (typeof toolResponse === 'string' ? toolResponse : JSON.stringify(toolResponse)),
        cwd: cwd
      }),
      signal: AbortSignal.timeout(10000) // 10秒タイムアウト
    });

    if (!response.ok) {
      throw new Error(`Worker API returned ${response.status}: ${response.statusText}`);
    }

    const result = await response.json();

    if (result.status === 'skipped') {
      console.error(`[cursor-hooks] Observation skipped: ${result.reason}`);
      return;
    }

    // 成功時はサイレント
    return;
  } catch (error) {
    // エラーは stderr に出力するが、フック自体は失敗させない
    console.error(`[cursor-hooks] Failed to record observation: ${error.message}`);
    console.error(`[cursor-hooks] Tool: ${toolName}, Session: ${sessionId}`);

    // Cursor の動作を止めないため、エラーを throw しない
    return;
  }
}

/**
 * プロジェクト名を抽出
 *
 * @param {string[]} workspaceRoots - Cursor の workspace_roots 配列
 * @returns {string} プロジェクトのルートディレクトリ
 */
function getProjectCwd(workspaceRoots) {
  // 1. workspace_roots[0] を優先使用
  if (workspaceRoots && workspaceRoots.length > 0 && workspaceRoots[0]) {
    return workspaceRoots[0];
  }

  // 2. フォールバック: 環境変数
  if (process.env.CLAUDE_MEM_PROJECT_CWD) {
    return process.env.CLAUDE_MEM_PROJECT_CWD;
  }

  // 3. 最終フォールバック: process.cwd()
  return process.cwd();
}

/**
 * プロジェクト名を取得（ディレクトリ名のみ）
 *
 * @param {string} cwd - プロジェクトのルートディレクトリ
 * @returns {string} プロジェクト名
 */
function getProjectName(cwd) {
  if (!cwd || cwd.trim() === '') {
    return 'unknown-project';
  }

  const path = require('path');
  const basename = path.basename(cwd);

  if (basename === '') {
    // Root directory detected
    if (process.platform === 'win32') {
      const driveMatch = cwd.match(/^([A-Z]):\\/i);
      if (driveMatch) {
        return `drive-${driveMatch[1].toUpperCase()}`;
      }
    }
    return 'unknown-project';
  }

  return basename;
}

/**
 * stdin から JSON 入力を読み取る
 *
 * @returns {Promise<Object>} パースされた JSON オブジェクト
 */
async function readStdin() {
  return new Promise((resolve, reject) => {
    let data = '';

    process.stdin.on('data', chunk => {
      data += chunk;
    });

    process.stdin.on('end', () => {
      try {
        const parsed = data ? JSON.parse(data) : {};
        resolve(parsed);
      } catch (error) {
        reject(new Error(`Failed to parse hook input: ${error.message}`));
      }
    });

    process.stdin.on('error', error => {
      reject(error);
    });
  });
}

/**
 * 継続レスポンスを出力（Cursor にフックが成功したことを通知）
 */
function outputContinue() {
  console.log(JSON.stringify({ continue: true, suppressOutput: true }));
}

module.exports = {
  initSession,
  recordObservation,
  getProjectCwd,
  getProjectName,
  readStdin,
  outputContinue
};
