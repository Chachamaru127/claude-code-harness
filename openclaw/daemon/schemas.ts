import { z } from "zod";

export const ContextSnapshotSchema = z.object({
  service: z.string().optional(),
  timestamp: z.string().optional(),
  summary: z.string(),
  key_facts: z.array(z.string()),
  actions_taken: z.array(z.string()),
});

export const CronRunResultSchema = z.object({
  timestamp: z.string(),
  services_checked: z.array(z.string()),
  actions_taken: z.array(
    z.object({
      service: z.string(),
      action: z.string(),
      subject: z.string().optional(),
      to: z.string().optional(),
      event: z.string().optional(),
    }),
  ),
  pending_human_review: z.array(
    z.object({
      service: z.string(),
      reason: z.string(),
      subject: z.string().optional(),
    }),
  ),
  context_snapshot: ContextSnapshotSchema,
  summary: z.string(),
});

export type CronRunResultParsed = z.infer<typeof CronRunResultSchema>;

export const cronRunResultJsonSchema = {
  type: "object" as const,
  properties: {
    timestamp: { type: "string" as const },
    services_checked: {
      type: "array" as const,
      items: { type: "string" as const },
    },
    actions_taken: {
      type: "array" as const,
      items: {
        type: "object" as const,
        properties: {
          service: { type: "string" as const },
          action: { type: "string" as const },
          subject: { type: "string" as const },
          to: { type: "string" as const },
          event: { type: "string" as const },
        },
        required: ["service", "action"] as const,
      },
    },
    pending_human_review: {
      type: "array" as const,
      items: {
        type: "object" as const,
        properties: {
          service: { type: "string" as const },
          reason: { type: "string" as const },
          subject: { type: "string" as const },
        },
        required: ["service", "reason"] as const,
      },
    },
    context_snapshot: {
      type: "object" as const,
      properties: {
        service: { type: "string" as const },
        timestamp: { type: "string" as const },
        summary: { type: "string" as const },
        key_facts: {
          type: "array" as const,
          items: { type: "string" as const },
        },
        actions_taken: {
          type: "array" as const,
          items: { type: "string" as const },
        },
      },
      required: ["summary", "key_facts", "actions_taken"] as const,
    },
    summary: { type: "string" as const },
  },
  required: [
    "timestamp",
    "services_checked",
    "actions_taken",
    "pending_human_review",
    "context_snapshot",
    "summary",
  ] as const,
};
