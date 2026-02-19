import type { OpenClawConfig, CronRunResult } from "./types";

export function buildDeliveryPrompt(
  result: CronRunResult,
  config: OpenClawConfig,
): string | null {
  const delivery = config.openclaw.delivery;
  if (!delivery?.enabled) return null;

  const channel = delivery.channel;
  if (!channel) return null;

  const actionCount = result.actions_taken.length;
  const pendingCount = result.pending_human_review.length;

  if (delivery.only_when_actions && actionCount === 0 && pendingCount === 0) {
    return null;
  }

  const summaryText = result.summary;
  const pendingItems = result.pending_human_review
    .map((p) => `- [${p.service}] ${p.reason}: ${p.subject ?? ""}`)
    .join("\n");

  return `以下のレポートを ${channel} に送信してください:

## OpenClaw 定期レポート

${summaryText}

${pendingCount > 0 ? `### 確認待ち (${pendingCount}件)\n${pendingItems}` : ""}

送信先: ${channel}
送信方法: ${getDeliveryInstruction(channel)}`;
}

function getDeliveryInstruction(channel: string): string {
  switch (channel) {
    case "line":
      return "mcp__line-bot__push_text_message を使ってユーザーに送信";
    case "slack":
      return "mcp__slack__slack_post_message を使って指定チャンネルに投稿";
    case "discord":
      return "mcp__discord__discord_send を使って指定チャンネルに送信";
    case "gmail":
      return "mcp__google-workspace__gmail_send でサマリーメール送信";
    default:
      return "適切な MCP ツールで送信";
  }
}
