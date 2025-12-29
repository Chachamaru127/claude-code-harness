#!/usr/bin/env node

// Node.js v24+ が stdin を TypeScript として評価するのを防ぐ
process.stdin.setEncoding('utf8');
process.stdin.resume();

/**
 * Cursor Hook: stop
 *
 * エージェント完了時にセッション完了状態を記録
 *
 * 入力例:
 * {
 *   "conversation_id": "uuid",
 *   "status": "completed|aborted|error",
 *   "loop_count": 5,
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

    // セッション完了状態を記録
    await recordObservation({
      sessionId: input.conversation_id,
      toolName: 'SessionStop',
      toolInput: {
        status: input.status || 'unknown',
        loop_count: input.loop_count || 0
      },
      toolResponse: null, // セッション停止なのでレスポンスはnull
      cwd: cwd
    });

    // Cursor に継続を通知
    outputContinue();
  } catch (error) {
    // エラーが発生してもCursorの動作を止めない
    console.error(`[record-stop] Error: ${error.message}`);
    outputContinue();
  }
}

main();
