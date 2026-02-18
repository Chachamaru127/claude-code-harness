export interface ServiceConfig {
  enabled: boolean;
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
    services: {
      gmail: ServiceConfig;
      calendar: ServiceConfig;
      line: ServiceConfig;
      slack: ServiceConfig;
      discord: ServiceConfig;
    };
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
  summary: string;
}
