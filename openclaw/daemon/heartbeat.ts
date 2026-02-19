import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";

const HEARTBEAT_FILE = "HEARTBEAT.md";

export interface HeartbeatResult {
  hasWork: boolean;
  tasks: string[];
  rawContent: string;
}

export function checkHeartbeat(cwd: string, file?: string): HeartbeatResult {
  const path = join(cwd, file ?? HEARTBEAT_FILE);
  if (!existsSync(path)) {
    return { hasWork: false, tasks: [], rawContent: "" };
  }

  let raw: string;
  try {
    raw = readFileSync(path, "utf-8");
  } catch {
    // File may have been deleted between existsSync and readFileSync (TOCTOU)
    return { hasWork: false, tasks: [], rawContent: "" };
  }

  if (isEffectivelyEmpty(raw)) {
    return { hasWork: false, tasks: [], rawContent: raw };
  }

  const tasks = extractTasks(raw);
  return { hasWork: tasks.length > 0, tasks, rawContent: raw };
}

/**
 * Determine whether HEARTBEAT.md content is "effectively empty" —
 * containing only headers, separators, empty checkboxes, and blank lines.
 */
function isEffectivelyEmpty(content: string): boolean {
  const meaningful = content.split("\n").filter((line) => {
    const trimmed = line.trim();
    if (!trimmed) return false;
    if (/^#+\s/.test(trimmed)) return false;
    if (trimmed === "---") return false;
    if (/^-\s*\[\s*\]\s*$/.test(trimmed)) return false;
    return true;
  });
  return meaningful.length === 0;
}

function extractTasks(content: string): string[] {
  return content
    .split("\n")
    .filter((line) => {
      const trimmed = line.trim();
      // Skip completed tasks (checked checkboxes)
      if (/^-\s*\[\s*[xX]\s*\]/.test(trimmed)) return false;
      // Match unchecked checkboxes or plain list items with content
      return /^-\s*(\[\s*\]\s*)?.+/.test(trimmed);
    })
    .map((line) => line.replace(/^-\s*(\[\s*\]\s*)?/, "").trim())
    .filter(Boolean);
}
