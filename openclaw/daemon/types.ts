export interface ServiceConfig {
  enabled: boolean;
  model?: "opus" | "sonnet" | "haiku";
  max_turns?: number;
  max_budget_usd?: number;
  priority?: "high" | "medium" | "low";
}

export interface HeartbeatConfig {
  enabled: boolean;
  file: string;
  skip_when_empty: boolean;
}

export interface DeliveryConfig {
  enabled: boolean;
  channel: "line" | "slack" | "discord" | "gmail";
  only_when_actions: boolean;
}

export interface ContextSnapshot {
  service?: string;
  timestamp?: string;
  summary: string;
  key_facts: string[];
  actions_taken: string[];
}

export interface RunHistoryEntry {
  runId: string;
  timestamp: string;
  service: string;
  costUsd: number;
  turns: number;
  durationMs: number;
  status: "success" | "error" | "skipped";
  context?: ContextSnapshot;
}

export interface OpenClawConfig {
  openclaw: {
    enabled: boolean;
    cron_interval: string;
    max_turns: number;
    max_budget_usd: number;
    project_cwd: string;
    harness_path: string;
    pid_file: string;
    log_file: string;
    heartbeat: HeartbeatConfig;
    delivery: DeliveryConfig;
    services: Record<string, ServiceConfig>;
  };
}

export interface CronRunResult {
  timestamp: string;
  services_checked: string[];
  actions_taken: Array<{
    service: string;
    action: string;
    subject?: string;
    to?: string;
    event?: string;
  }>;
  pending_human_review: Array<{
    service: string;
    reason: string;
    subject?: string;
  }>;
  context_snapshot: ContextSnapshot;
  summary: string;
}
