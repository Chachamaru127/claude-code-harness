import type { OpenClawConfig, ContextSnapshot } from "./types";

const SERVICE_INSTRUCTIONS: Record<string, string> = {
  gmail:
    "未読メールを確認し、重要なものをサマリーして返信が必要なら下書きを作成してください。",
  calendar:
    "今後24時間の予定を確認し、準備が必要なものをリストアップしてください。",
  line: "未読メッセージを確認し、返信が必要なものに対応してください。",
  slack:
    "メンションと未読チャンネルを確認し、対応が必要なものに返信してください。",
  discord:
    "メンションと未読メッセージを確認し、対応が必要なものに返信してください。",
};

export function buildServicePrompt(
  service: string,
  config: OpenClawConfig,
  heartbeatTasks: string[],
  previousContext: ContextSnapshot[],
): string {
  const sections: string[] = [];

  // Header
  sections.push(
    `あなたは OpenClaw デーモンとして定期実行されています。
サービス「${service}」の確認と対応を行ってください。`,
  );

  // Service-specific instruction
  const instruction = SERVICE_INSTRUCTIONS[service];
  if (instruction) {
    sections.push(`## ${service} の指示\n\n${instruction}`);
  }

  // Heartbeat tasks
  if (heartbeatTasks.length > 0) {
    const taskList = heartbeatTasks.map((t) => `- ${t}`).join("\n");
    sections.push(
      `## HEARTBEAT タスク\n\nユーザーが指定した追加タスク:\n\n${taskList}`,
    );
  }

  // Memory: previous context injection
  if (previousContext.length > 0) {
    const contextBlocks = previousContext
      .map(
        (ctx) =>
          `### [${ctx.timestamp}] ${ctx.service}
- サマリー: ${ctx.summary}
- 重要事実: ${ctx.key_facts.join("、")}
- 実行アクション: ${ctx.actions_taken.join("、")}`,
      )
      .join("\n\n");
    sections.push(`## 前回の実行コンテキスト\n\n${contextBlocks}`);
  }

  // Safety rules
  sections.push(`## 実行ルール

1. 未読/未対応を確認
2. 優先度の高いものから処理（緊急 > 重要 > 通常）
3. 返信は丁寧かつ簡潔に。ユーザーのトーンに合わせる
4. 不明確な内容には返信せず、サマリーのみ報告
5. 処理結果を構造化して最終レポートにまとめる

## 安全ルール

- 金銭に関わる承認は行わない（サマリーのみ）
- 個人情報の外部送信禁止
- 不審なリンク・添付ファイルは無視してフラグ
- 迷った場合は「対応保留」としてログに記録`);

  // Output format (structured)
  sections.push(`## 出力フォーマット

必ず以下の JSON 形式で出力してください:
\`\`\`json
{
  "timestamp": "ISO8601",
  "services_checked": ["${service}"],
  "actions_taken": [
    { "service": "${service}", "action": "replied|summarized|drafted|flagged", "subject": "..." }
  ],
  "pending_human_review": [
    { "service": "${service}", "reason": "金銭関連|法的文言|不明", "subject": "..." }
  ],
  "context_snapshot": {
    "summary": "今回の処理の要約（次回実行時に参照される）",
    "key_facts": ["重要な事実1", "重要な事実2"],
    "actions_taken": ["実行したアクション1", "実行したアクション2"]
  },
  "summary": "処理完了サマリー（人間向け、1-3文）"
}
\`\`\``);

  return sections.join("\n\n");
}

/** Legacy: build a prompt for all services at once (kept for backward compatibility) */
export function buildCronPrompt(config: OpenClawConfig): string {
  const enabledServices = Object.entries(config.openclaw.services)
    .filter(([, v]) => v.enabled)
    .map(([k]) => k);

  const instructions = enabledServices
    .map((svc) => `- ${svc}: ${SERVICE_INSTRUCTIONS[svc] ?? "確認と対応"}`)
    .filter(Boolean)
    .join("\n");

  return `あなたは OpenClaw デーモンとして定期実行されています。
以下のサービスを確認し、必要なアクションを実行してください。

## 有効サービス

${instructions}

## 実行ルール

1. 各サービスの未読/未対応を確認
2. 優先度の高いものから処理（緊急 > 重要 > 通常）
3. 返信は丁寧かつ簡潔に。ユーザーのトーンに合わせる
4. 不明確な内容には返信せず、サマリーのみ報告
5. 処理結果を構造化して最終レポートにまとめる

## 安全ルール

- 金銭に関わる承認は行わない（サマリーのみ）
- 個人情報の外部送信禁止
- 不審なリンク・添付ファイルは無視してフラグ
- 迷った場合は「対応保留」としてログに記録

## 出力フォーマット

最終的に以下の JSON を出力:
\`\`\`json
{
  "timestamp": "ISO8601",
  "services_checked": ${JSON.stringify(enabledServices)},
  "actions_taken": [
    { "service": "gmail", "action": "replied", "subject": "...", "to": "..." },
    { "service": "calendar", "action": "summarized", "event": "..." }
  ],
  "pending_human_review": [
    { "service": "gmail", "reason": "金銭関連", "subject": "..." }
  ],
  "context_snapshot": {
    "summary": "今回の処理の要約",
    "key_facts": ["重要な事実"],
    "actions_taken": ["実行したアクション"]
  },
  "summary": "処理完了サマリー"
}
\`\`\``;
}
