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

function readLines(path: string): string[] {
  if (!existsSync(path)) return [];
  const raw = readFileSync(path, "utf-8").trim();
  return raw === "" ? [] : raw.split("\n");
}

export class RunHistoryManager {
  private historyPath: string;

  constructor(cwd: string) {
    this.historyPath = `${cwd}/.claude/state/openclaw-runs.jsonl`;
    mkdirSync(dirname(this.historyPath), { recursive: true });
  }

  append(entry: RunHistoryEntry): void {
    try {
      appendFileSync(this.historyPath, JSON.stringify(entry) + "\n");
      this.rotateIfNeeded();
    } catch {
      // History persistence is non-critical — don't propagate
      console.error("[openclaw] Failed to append run history");
    }
  }

  getRecentContext(service: string, count = 3): ContextSnapshot[] {
    const lines = readLines(this.historyPath);
    return lines
      .map((l) => {
        try {
          const parsed = JSON.parse(l);
          if (typeof parsed !== "object" || parsed === null) return null;
          return parsed as RunHistoryEntry;
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
    const lines = readLines(this.historyPath);
    const today = new Date().toISOString().slice(0, 10);

    return lines.reduce((sum, l) => {
      try {
        const e = JSON.parse(l) as RunHistoryEntry;
        if (e.timestamp?.startsWith(today)) return sum + (e.costUsd ?? 0);
      } catch {
        /* skip malformed lines */
      }
      return sum;
    }, 0);
  }

  private rotateIfNeeded(): void {
    const lines = readLines(this.historyPath);
    if (lines.length > MAX_ENTRIES) {
      writeFileSync(this.historyPath, lines.slice(-TRIM_TO).join("\n") + "\n");
    }
  }
}
