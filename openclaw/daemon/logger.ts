import {
  appendFileSync,
  existsSync,
  mkdirSync,
  readFileSync,
  renameSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { dirname } from "node:path";

const LOG_FILE =
  process.env.OPENCLAW_LOG_FILE ?? ".claude/logs/openclaw-daemon.log";

const MAX_LOG_SIZE_BYTES = 5 * 1024 * 1024; // 5 MB
const MAX_ROTATED_FILES = 3;

function ensureDir(path: string) {
  try {
    mkdirSync(dirname(path), { recursive: true });
  } catch {
    /* already exists */
  }
}

function rotateIfNeeded() {
  try {
    if (!existsSync(LOG_FILE)) return;
    const stats = statSync(LOG_FILE);
    if (stats.size < MAX_LOG_SIZE_BYTES) return;

    // Shift existing rotated files: .3 → delete, .2 → .3, .1 → .2
    for (let i = MAX_ROTATED_FILES; i >= 1; i--) {
      const src = i === 1 ? LOG_FILE : `${LOG_FILE}.${i - 1}`;
      const dst = `${LOG_FILE}.${i}`;
      if (existsSync(src)) {
        if (i === MAX_ROTATED_FILES) {
          // Overwrite oldest
          writeFileSync(dst, readFileSync(src));
        } else {
          renameSync(src, dst);
        }
      }
    }

    // Truncate current log
    writeFileSync(LOG_FILE, "");
  } catch {
    /* rotation failure is non-fatal */
  }
}

function write(
  level: string,
  event: string,
  data?: Record<string, unknown>,
) {
  const entry = JSON.stringify({
    ts: new Date().toISOString(),
    level,
    event,
    ...data,
  });
  console.error(`[openclaw] ${entry}`);
  ensureDir(LOG_FILE);
  appendFileSync(LOG_FILE, entry + "\n");
  rotateIfNeeded();
}

export const log = {
  info: (event: string, data?: Record<string, unknown>) =>
    write("info", event, data),
  error: (event: string, data?: Record<string, unknown>) =>
    write("error", event, data),
  warn: (event: string, data?: Record<string, unknown>) =>
    write("warn", event, data),
};
