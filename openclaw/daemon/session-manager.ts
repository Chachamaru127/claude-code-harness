import { existsSync, mkdirSync, writeFileSync, readFileSync } from "node:fs";
import { dirname } from "node:path";

const DEFAULT_STATE_FILE = ".claude/state/openclaw-session.json";

export class SessionManager {
  private sessionId: string | null = null;
  private statePath: string;

  constructor(cwd?: string) {
    this.statePath = cwd
      ? `${cwd}/${DEFAULT_STATE_FILE}`
      : DEFAULT_STATE_FILE;
    this.load();
  }

  private load() {
    try {
      if (existsSync(this.statePath)) {
        const data = JSON.parse(readFileSync(this.statePath, "utf-8"));
        this.sessionId = data.sessionId ?? null;
      }
    } catch {
      /* first run */
    }
  }

  save() {
    try {
      mkdirSync(dirname(this.statePath), { recursive: true });
    } catch {
      /* already exists */
    }
    writeFileSync(
      this.statePath,
      JSON.stringify(
        {
          sessionId: this.sessionId,
          updatedAt: new Date().toISOString(),
        },
        null,
        2,
      ),
    );
  }

  getLastSessionId(): string | undefined {
    return this.sessionId ?? undefined;
  }

  setLastSessionId(id: string) {
    this.sessionId = id;
    this.save();
  }

  clearLastSessionId() {
    this.sessionId = null;
    this.save();
  }
}
