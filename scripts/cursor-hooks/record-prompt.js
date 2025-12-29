#!/usr/bin/env node

// Node.js v24+ が stdin を TypeScript として評価するのを防ぐ
process.stdin.setEncoding('utf8');
process.stdin.resume();

/**
 * Cursor Hook: beforeSubmitPrompt
 *
 * プロンプト送信前にセッションを初期化し、ユーザープロンプトを Worker に登録
 *
 * 入力例:
 * {
 *   "conversation_id": "uuid",
 *   "prompt": "user prompt text",
 *   "attachments": [...],
 *   "workspace_roots": ["/path/to/workspace"]
 * }
 */

const { initSession, getProjectCwd, getProjectName, readStdin, outputContinue } = require('./utils.js');

async function main() {
  try {
    const input = await readStdin();

    if (!input.conversation_id) {
      throw new Error('Missing conversation_id in hook input');
    }

    const cwd = getProjectCwd(input.workspace_roots);
    const project = getProjectName(cwd);
    const prompt = input.prompt || '';

    // セッションを初期化（プロンプトを Worker に登録）
    // これにより user_prompts テーブルにプロンプトが保存され、
    // 後続の observation 記録が "private" でスキップされなくなる
    await initSession({
      sessionId: input.conversation_id,
      project: project,
      prompt: prompt
    });

    // Cursor に継続を通知
    outputContinue();
  } catch (error) {
    // エラーが発生してもCursorの動作を止めない
    console.error(`[record-prompt] Error: ${error.message}`);
    outputContinue();
  }
}

main();
