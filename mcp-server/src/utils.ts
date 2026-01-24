/**
 * Shared Utilities for Harness MCP Server
 *
 * Common functions used across multiple tool modules.
 */

import * as fs from "fs";
import * as path from "path";
import { exec } from "child_process";
import { promisify } from "util";

// Promisified exec for async operations
export const execAsync = promisify(exec);

// ===== Configuration Constants =====

/** Session is considered stale after this many seconds (1 hour) */
export const STALE_THRESHOLD_SECONDS = 3600;

/** Maximum number of broadcast messages to retain */
export const MAX_BROADCAST_MESSAGES = 100;

/** Directory for session state files */
export const SESSIONS_DIR = ".claude/sessions";

/** Active sessions file path */
export const ACTIVE_SESSIONS_FILE = `${SESSIONS_DIR}/active.json`;

/** Broadcast messages file path */
export const BROADCAST_FILE = `${SESSIONS_DIR}/broadcast.json`;

// ===== File System Utilities =====

/**
 * Find the project root by looking for common markers.
 * Traverses up the directory tree until a marker is found.
 *
 * @returns The project root path, or current working directory if not found
 */
export function getProjectRoot(): string {
  const markers = [".git", "package.json", "Plans.md", ".claude"];
  let current = process.cwd();

  while (current !== "/") {
    for (const marker of markers) {
      if (fs.existsSync(path.join(current, marker))) {
        return current;
      }
    }
    current = path.dirname(current);
  }

  return process.cwd();
}

/**
 * Ensure a directory exists, creating it if necessary.
 *
 * @param dirPath - The directory path to ensure exists
 */
export function ensureDir(dirPath: string): void {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

/**
 * Safely parse JSON from a file with error logging.
 *
 * @param filePath - Path to the JSON file
 * @param defaultValue - Default value if file doesn't exist or parse fails
 * @returns Parsed JSON or default value
 */
export function safeReadJSON<T>(filePath: string, defaultValue: T): T {
  if (!fs.existsSync(filePath)) {
    return defaultValue;
  }

  try {
    const content = fs.readFileSync(filePath, "utf-8");
    return JSON.parse(content) as T;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[harness-mcp] Failed to parse JSON from ${filePath}: ${message}`);
    return defaultValue;
  }
}

/**
 * Safely write JSON to a file with error logging.
 *
 * @param filePath - Path to write the JSON file
 * @param data - Data to serialize and write
 * @returns true if successful, false otherwise
 */
export function safeWriteJSON<T>(filePath: string, data: T): boolean {
  try {
    ensureDir(path.dirname(filePath));
    fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
    return true;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`[harness-mcp] Failed to write JSON to ${filePath}: ${message}`);
    return false;
  }
}

// ===== Git Utilities =====

/**
 * Get list of recently changed files using git diff (async).
 *
 * @param basePath - The repository path
 * @returns Array of changed file paths
 */
export async function getRecentChangesAsync(basePath?: string): Promise<string[]> {
  const cwd = basePath || getProjectRoot();

  try {
    const { stdout } = await execAsync("git diff --name-only HEAD~1", {
      cwd,
      encoding: "utf-8",
    });
    return stdout.trim().split("\n").filter(Boolean);
  } catch {
    return [];
  }
}

// ===== Time Utilities =====

/**
 * Format a duration in seconds to a human-readable string.
 *
 * @param seconds - Duration in seconds
 * @returns Human-readable duration (e.g., "5m ago", "2h ago")
 */
export function formatTimeAgo(seconds: number): string {
  if (seconds < 60) {
    return `${seconds}s ago`;
  }
  if (seconds < 3600) {
    return `${Math.floor(seconds / 60)}m ago`;
  }
  return `${Math.floor(seconds / 3600)}h ago`;
}
