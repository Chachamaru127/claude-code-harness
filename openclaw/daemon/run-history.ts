import {
  existsSync,
  readFileSync,
  appendFileSync,
  writeFileSync,
  mkdirSync,
} from "node:fs";
import { dirname } from "node:path";
import type { ContextSnapshot, RunHistoryEntry } from "./types";

const MAX_ENTRIES = 500;
const TRIM_TO = 400;

export class RunHistoryManager {
  private historyPath: string;

  constructor(cwd: string) {
    this.historyPath = `${cwd}/.claude/state/openclaw-runs.jsonl`;
    mkdirSync(dirname(this.historyPath), { recursive: true });
  }

  append(entry: RunHistoryEntry): void {
    appendFileSync(this.historyPath, JSON.stringify(entry) + "\n");
    this.rotateIfNeeded();
  }

  getRecentContext(service: string, count = 3): ContextSnapshot[] {
    if (!existsSync(this.historyPath)) return [];

    const lines = readFileSync(this.historyPath, "utf-8").trim().split("\n");
    return lines
      .map((l) => {
        try {
          return JSON.parse(l) as RunHistoryEntry;
        } catch {
          return null;
        }
      })
      .filter(
        (e): e is RunHistoryEntry =>
          e !== null &&
          e.service === service &&
          e.status === "success" &&
          !!e.context,
      )
      .slice(-count)
      .map((e) => e.context!);
  }

  getTodayCost(): number {
    if (!existsSync(this.historyPath)) return 0;

    const today = new Date().toISOString().slice(0, 10);
    const lines = readFileSync(this.historyPath, "utf-8").trim().split("\n");

    return lines.reduce((sum, l) => {
      try {
        const e = JSON.parse(l) as RunHistoryEntry;
        if (e.timestamp.startsWith(today)) return sum + (e.costUsd ?? 0);
      } catch {
        /* skip malformed lines */
      }
      return sum;
    }, 0);
  }

  private rotateIfNeeded(): void {
    if (!existsSync(this.historyPath)) return;

    const lines = readFileSync(this.historyPath, "utf-8").trim().split("\n");
    if (lines.length > MAX_ENTRIES) {
      writeFileSync(this.historyPath, lines.slice(-TRIM_TO).join("\n") + "\n");
    }
  }
}
