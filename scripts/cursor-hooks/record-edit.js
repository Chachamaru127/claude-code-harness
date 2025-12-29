#!/usr/bin/env node

// Node.js v24+ が stdin を TypeScript として評価するのを防ぐ
process.stdin.setEncoding('utf8');
process.stdin.resume();

/**
 * Cursor Hook: afterFileEdit
 *
 * ファイル編集後にファイルパスと編集内容を記録
 *
 * 入力例:
 * {
 *   "conversation_id": "uuid",
 *   "file_path": "/path/to/file",
 *   "edits": [
 *     {
 *       "old_string": "...",
 *       "new_string": "..."
 *     }
 *   ],
 *   "workspace_roots": ["/path/to/workspace"]
 * }
 */

const { recordObservation, getProjectCwd, readStdin, outputContinue } = require('./utils.js');

async function main() {
  try {
    const input = await readStdin();

    if (!input.conversation_id) {
      throw new Error('Missing conversation_id in hook input');
    }

    const cwd = getProjectCwd(input.workspace_roots);

    // ファイルパスと編集内容を記録
    await recordObservation({
      sessionId: input.conversation_id,
      toolName: 'Edit',
      toolInput: {
        file_path: input.file_path || '',
        edits: input.edits || []
      },
      toolResponse: 'Success', // 編集成功
      cwd: cwd
    });

    // Cursor に継続を通知
    outputContinue();
  } catch (error) {
    // エラーが発生してもCursorの動作を止めない
    console.error(`[record-edit] Error: ${error.message}`);
    outputContinue();
  }
}

main();
