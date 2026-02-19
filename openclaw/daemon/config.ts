import { parse as parseYaml } from "yaml";
import { existsSync, readFileSync } from "node:fs";
import type { OpenClawConfig, HeartbeatConfig, DeliveryConfig, ServiceConfig } from "./types";

const CONFIG_PATH = ".claude-code-harness.config.yaml";

function findHarnessPath(): string {
  const candidates = [
    `${process.env.HOME}/.claude/plugins/claude-code-harness`,
    `${process.cwd()}/node_modules/claude-code-harness`,
    `${process.cwd()}`,
  ];
  return candidates.find(existsSync) ?? candidates[0];
}

const DEFAULT_HEARTBEAT: HeartbeatConfig = {
  enabled: true,
  file: "HEARTBEAT.md",
  skip_when_empty: true,
};

const DEFAULT_DELIVERY: DeliveryConfig = {
  enabled: false,
  channel: "line",
  only_when_actions: true,
};

const DEFAULTS: OpenClawConfig["openclaw"] = {
  enabled: false,
  cron_interval: "*/30 * * * *",
  max_turns: 20,
  max_budget_usd: 1.0,
  project_cwd: process.cwd(),
  harness_path: findHarnessPath(),
  pid_file: "/tmp/openclaw-daemon.pid",
  log_file: ".claude/logs/openclaw-daemon.log",
  heartbeat: DEFAULT_HEARTBEAT,
  delivery: DEFAULT_DELIVERY,
  services: {
    gmail: { enabled: false },
    calendar: { enabled: false },
    line: { enabled: false },
    slack: { enabled: false },
    discord: { enabled: false },
  },
};

export function loadConfig(): OpenClawConfig {
  const configPath = `${process.cwd()}/${CONFIG_PATH}`;
  if (!existsSync(configPath)) {
    return { openclaw: DEFAULTS };
  }

  const raw = parseYaml(readFileSync(configPath, "utf-8")) as Record<
    string,
    unknown
  >;
  const userConfig = (raw?.openclaw ?? {}) as Partial<
    OpenClawConfig["openclaw"]
  >;

  // Deep-merge services: preserve per-service defaults, overlay user values
  const mergedServices: Record<string, ServiceConfig> = {
    ...DEFAULTS.services,
  };
  if (userConfig.services) {
    for (const [name, svcConfig] of Object.entries(userConfig.services)) {
      mergedServices[name] = {
        ...(mergedServices[name] ?? { enabled: false }),
        ...svcConfig,
      };
    }
  }

  return {
    openclaw: {
      ...DEFAULTS,
      ...userConfig,
      heartbeat: {
        ...DEFAULT_HEARTBEAT,
        ...((userConfig.heartbeat ?? {}) as Partial<HeartbeatConfig>),
      },
      delivery: {
        ...DEFAULT_DELIVERY,
        ...((userConfig.delivery ?? {}) as Partial<DeliveryConfig>),
      },
      services: mergedServices,
    },
  };
}
