import type { OpenClawConfig } from "./types";

const SERVICE_INSTRUCTIONS: Record<string, string> = {
  gmail:
    "- Gmail: 未読メールを確認し、重要なものをサマリーして返信が必要なら下書きを作成",
  calendar:
    "- Calendar: 今後24時間の予定を確認し、準備が必要なものをリストアップ",
  line: "- LINE: 未読メッセージを確認し、返信が必要なものに対応",
  slack:
    "- Slack: メンションと未読チャンネルを確認し、対応が必要なものに返信",
  discord:
    "- Discord: メンションと未読メッセージを確認し、対応が必要なものに返信",
};

export function buildCronPrompt(config: OpenClawConfig): string {
  const enabledServices = Object.entries(config.openclaw.services)
    .filter(([, v]) => v.enabled)
    .map(([k]) => k);

  const instructions = enabledServices
    .map((svc) => SERVICE_INSTRUCTIONS[svc] ?? "")
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
  "summary": "処理完了サマリー"
}
\`\`\``;
}
