#!/usr/bin/env node
/**
 * emit-agent-trace.js
 * PostToolUse hook for recording Agent Trace entries
 *
 * Usage (from hooks.json):
 *   "command": "node \"${CLAUDE_PLUGIN_ROOT}/scripts/emit-agent-trace.js\""
 *
 * Environment variables (set by Claude Code hooks):
 *   CLAUDE_TOOL_NAME - Name of the tool (Edit, Write, etc.)
 *   CLAUDE_TOOL_INPUT - JSON string of tool input
 *   CLAUDE_SESSION_ID - Current session ID
 *
 * Output:
 *   Appends JSONL record to .claude/state/agent-trace.jsonl
 */

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const crypto = require('crypto');

// Configuration
const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
const MAX_GENERATIONS = 3;
const TRACE_VERSION = '0.1.0';
const CACHE_TTL_MS = 60000; // 1 minute cache for project info

// In-memory cache for project metadata (persists across hook invocations within same process)
let projectCache = null;
let projectCacheTime = 0;

/**
 * Log error to stderr (non-blocking)
 */
function logError(context, error) {
  const msg = error instanceof Error ? error.message : String(error);
  process.stderr.write(`[agent-trace] ${context}: ${msg}\n`);
}

/**
 * Generate UUID v4
 */
function generateUUID() {
  return crypto.randomUUID();
}

/**
 * Get current timestamp in ISO8601 UTC format
 */
function getTimestamp() {
  return new Date().toISOString();
}

// Repo root cache (key: cwd, value: repo root)
let repoRootCache = null;
let repoRootCwd = null;

/**
 * Find repository root by walking up directory tree
 * Avoids git process spawn for better performance
 * Returns cwd if not in a git repo
 */
function findRepoRoot() {
  const cwd = process.cwd();

  // Return cached value if cwd hasn't changed
  if (repoRootCache && repoRootCwd === cwd) {
    return repoRootCache;
  }

  try {
    let dir = cwd;
    const fsRoot = path.parse(dir).root;

    while (dir !== fsRoot) {
      const gitDir = path.join(dir, '.git');
      if (fs.existsSync(gitDir)) {
        // Verify .git is a directory (not a file for submodules)
        const stat = fs.lstatSync(gitDir);
        if (stat.isDirectory() || stat.isFile()) {
          // .git file indicates submodule, still valid
          repoRootCache = dir;
          repoRootCwd = cwd;
          return dir;
        }
      }
      dir = path.dirname(dir);
    }
  } catch (err) {
    logError('findRepoRoot', err);
  }

  // Not in a git repo, use cwd
  repoRootCache = cwd;
  repoRootCwd = cwd;
  return cwd;
}

// VCS cache (persists within process, refreshed by TTL)
let vcsCache = null;
let vcsCacheTime = 0;
const VCS_CACHE_TTL_MS = 5000; // 5 seconds cache for VCS info

/**
 * Get VCS (Git) information with single git call for performance
 * Uses `git status --porcelain=2 -b -uno` to get branch, revision, and dirty status
 * -uno: Exclude untracked files for much faster execution on large repos
 * Returns null if not in a Git repository
 */
function getVcsInfo() {
  const now = Date.now();

  // Return cached if still valid (dirty status may change but branch/revision rarely do)
  if (vcsCache && (now - vcsCacheTime) < VCS_CACHE_TTL_MS) {
    return vcsCache;
  }

  try {
    // Single git call to get all VCS info
    // -uno: Skip untracked files for performance
    const output = execFileSync('git', [
      'status', '--porcelain=2', '-b', '-uno'
    ], {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe']
    }).trim();

    const lines = output.split('\n');
    let revision = '';
    let branch = '';
    let dirty = false;

    for (const line of lines) {
      if (line.startsWith('# branch.oid ')) {
        revision = line.slice(13);
      } else if (line.startsWith('# branch.head ')) {
        branch = line.slice(14);
      } else if (line && !line.startsWith('#')) {
        // Any non-header line indicates modified files (untracked excluded by -uno)
        dirty = true;
      }
    }

    if (!revision || !branch) {
      return null;
    }

    vcsCache = { revision, branch, dirty };
    vcsCacheTime = now;
    return vcsCache;
  } catch (err) {
    logError('getVcsInfo', err);
    return null;
  }
}

/**
 * Detect project type from file patterns
 * Uses existsSync with early termination for better performance
 * Avoids reading entire directory on large monorepos
 */
function detectProjectType(repoRoot) {
  // Priority-ordered list: more specific frameworks first, generic last
  const checks = [
    ['next.config.js', 'nextjs'],
    ['next.config.ts', 'nextjs'],
    ['next.config.mjs', 'nextjs'],
    ['nuxt.config.js', 'nuxt'],
    ['nuxt.config.ts', 'nuxt'],
    ['svelte.config.js', 'svelte'],
    ['astro.config.mjs', 'astro'],
    ['astro.config.ts', 'astro'],
    ['Cargo.toml', 'rust'],
    ['go.mod', 'go'],
    ['pyproject.toml', 'python'],
    ['setup.py', 'python'],
    ['requirements.txt', 'python'],
    ['Gemfile', 'ruby'],
    ['composer.json', 'php'],
    ['package.json', 'node'],
  ];

  try {
    for (const [file, type] of checks) {
      if (fs.existsSync(path.join(repoRoot, file))) {
        return type;
      }
    }
  } catch (err) {
    logError('detectProjectType', err);
  }

  return 'unknown';
}

/**
 * Get project name from package.json or directory name
 */
function getProjectName(repoRoot) {
  try {
    const pkgPath = path.join(repoRoot, 'package.json');
    if (fs.existsSync(pkgPath)) {
      const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
      if (pkg.name) return pkg.name;
    }
  } catch (err) {
    logError('getProjectName', err);
  }
  return path.basename(repoRoot);
}

/**
 * Get cached project metadata or compute it
 */
function getProjectMetadata(repoRoot) {
  const now = Date.now();

  // Return cached if still valid
  if (projectCache && (now - projectCacheTime) < CACHE_TTL_MS) {
    return projectCache;
  }

  // Compute and cache
  projectCache = {
    project: getProjectName(repoRoot),
    projectType: detectProjectType(repoRoot)
  };
  projectCacheTime = now;

  return projectCache;
}

/**
 * Validate that a path is within the repository
 * Security: Prevents recording paths outside the repo
 * Handles both existing and non-existing paths safely
 */
function isPathWithinRepo(filePath, repoRoot) {
  try {
    // Reject paths with '..' to prevent traversal
    if (filePath.includes('..')) {
      logError('isPathWithinRepo', `Path contains '..': ${filePath}`);
      return false;
    }

    // Resolve to absolute path
    const absolutePath = path.isAbsolute(filePath)
      ? filePath
      : path.resolve(repoRoot, filePath);

    // Resolve repo root (must succeed)
    const resolvedRepo = fs.realpathSync(repoRoot);

    // Use realpath to resolve symlinks
    let resolvedPath;
    try {
      resolvedPath = fs.realpathSync(absolutePath);
    } catch {
      // File doesn't exist yet (Write operation)
      // Security: Resolve parent directory if it exists, then append basename
      const parentDir = path.dirname(absolutePath);
      const baseName = path.basename(absolutePath);

      try {
        // Check if parent is a symlink pointing outside repo
        const resolvedParent = fs.realpathSync(parentDir);
        if (!resolvedParent.startsWith(resolvedRepo + path.sep) &&
            resolvedParent !== resolvedRepo) {
          logError('isPathWithinRepo', `Parent dir outside repo: ${parentDir}`);
          return false;
        }
        resolvedPath = path.join(resolvedParent, baseName);
      } catch {
        // Parent doesn't exist either - use normalized path but be strict
        resolvedPath = path.normalize(absolutePath);
        // Additional check: normalized path should not escape repo
        const relativePath = path.relative(resolvedRepo, resolvedPath);
        if (relativePath.startsWith('..') || path.isAbsolute(relativePath)) {
          logError('isPathWithinRepo', `Normalized path escapes repo: ${resolvedPath}`);
          return false;
        }
      }
    }

    // Check if path starts with repo root (with separator to avoid /repo vs /repo2)
    return resolvedPath.startsWith(resolvedRepo + path.sep) ||
           resolvedPath === resolvedRepo;
  } catch (err) {
    logError('isPathWithinRepo', err);
    return false;
  }
}

/**
 * Parse tool input to extract file information
 */
function parseToolInput(toolName, toolInput, repoRoot) {
  const files = [];

  try {
    const input = typeof toolInput === 'string' ? JSON.parse(toolInput) : toolInput;

    if (toolName === 'Edit') {
      if (input.file_path) {
        // Security: Validate path is within repo
        if (isPathWithinRepo(input.file_path, repoRoot)) {
          files.push({
            path: input.file_path,
            action: 'modify',
            range: 'unknown'
          });
        } else {
          logError('parseToolInput', `Path outside repo: ${input.file_path}`);
        }
      }
    } else if (toolName === 'Write') {
      if (input.file_path) {
        // Security: Validate path is within repo
        if (isPathWithinRepo(input.file_path, repoRoot)) {
          // Use absolute path for exists check to avoid cwd dependency
          const absolutePath = path.isAbsolute(input.file_path)
            ? input.file_path
            : path.resolve(repoRoot, input.file_path);
          const exists = fs.existsSync(absolutePath);
          files.push({
            path: input.file_path,
            action: exists ? 'modify' : 'create',
            range: 'unknown'
          });
        } else {
          logError('parseToolInput', `Path outside repo: ${input.file_path}`);
        }
      }
    }
  } catch (err) {
    logError('parseToolInput', err);
  }

  return files;
}

/**
 * Make path relative to repo root
 */
function makeRelativePath(filePath, repoRoot) {
  if (path.isAbsolute(filePath)) {
    return path.relative(repoRoot, filePath);
  }
  return filePath;
}

/**
 * Rotate trace file if it exceeds size limit
 * Uses lock file to prevent concurrent rotation
 */
function rotateIfNeeded(tracePath) {
  // Skip rotation if file doesn't exist
  if (!fs.existsSync(tracePath)) return;

  try {
    const stats = fs.statSync(tracePath);
    if (stats.size < MAX_FILE_SIZE) return;

    // Use lock file to prevent concurrent rotation
    const lockPath = `${tracePath}.lock`;
    let lockFd;
    try {
      // O_CREAT | O_EXCL equivalent: fails if lock exists
      lockFd = fs.openSync(lockPath, 'wx');
    } catch {
      // Lock exists, another process is rotating - skip rotation
      return;
    }

    try {
      // Re-check size after acquiring lock (another process may have rotated)
      if (!fs.existsSync(tracePath)) {
        return;
      }
      const currentStats = fs.statSync(tracePath);
      if (currentStats.size < MAX_FILE_SIZE) {
        return;
      }

      for (let i = MAX_GENERATIONS - 1; i >= 1; i--) {
        const oldPath = `${tracePath}.${i}`;
        const newPath = `${tracePath}.${i + 1}`;
        if (fs.existsSync(oldPath)) {
          if (i === MAX_GENERATIONS - 1) {
            fs.unlinkSync(oldPath);
          } else {
            fs.renameSync(oldPath, newPath);
          }
        }
      }
      fs.renameSync(tracePath, `${tracePath}.1`);
    } finally {
      // Release lock
      fs.closeSync(lockFd);
      try { fs.unlinkSync(lockPath); } catch { /* ignore */ }
    }
  } catch (err) {
    logError('rotateIfNeeded', err);
  }
}

/**
 * Main function
 */
function main() {
  const toolName = process.env.CLAUDE_TOOL_NAME;
  const toolInput = process.env.CLAUDE_TOOL_INPUT;
  const sessionId = process.env.CLAUDE_SESSION_ID || '';

  if (!toolName || !['Edit', 'Write'].includes(toolName)) {
    process.exit(0);
  }

  const repoRoot = findRepoRoot();
  const files = parseToolInput(toolName, toolInput, repoRoot);

  if (files.length === 0) {
    process.exit(0);
  }

  files.forEach(f => {
    f.path = makeRelativePath(f.path, repoRoot);
  });

  const record = {
    version: TRACE_VERSION,
    id: generateUUID(),
    timestamp: getTimestamp(),
    tool: toolName,
    files: files
  };

  const vcs = getVcsInfo();
  if (vcs) {
    record.vcs = vcs;
  }

  const metadata = getProjectMetadata(repoRoot);
  record.metadata = { ...metadata };
  if (sessionId) {
    record.metadata.sessionId = sessionId;
  }

  const stateDir = path.join(repoRoot, '.claude', 'state');
  const tracePath = path.join(stateDir, 'agent-trace.jsonl');

  try {
    const claudeDir = path.join(repoRoot, '.claude');
    const resolvedRepo = fs.realpathSync(repoRoot);

    // Security: Verify .claude is not a symlink pointing outside repo
    if (fs.existsSync(claudeDir)) {
      const claudeDirStat = fs.lstatSync(claudeDir);
      if (claudeDirStat.isSymbolicLink()) {
        const resolvedClaudeDir = fs.realpathSync(claudeDir);
        if (!resolvedClaudeDir.startsWith(resolvedRepo + path.sep) &&
            resolvedClaudeDir !== resolvedRepo) {
          logError('main', '.claude symlink points outside repo');
          process.exit(0);
        }
      }
    }

    // Security: Verify stateDir BEFORE creating/modifying
    if (fs.existsSync(stateDir)) {
      // Existing stateDir: verify it's within repo BEFORE chmod
      const stateDirLstat = fs.lstatSync(stateDir);
      if (stateDirLstat.isSymbolicLink()) {
        logError('main', 'stateDir is a symlink, refusing to modify');
        process.exit(0);
      }
      const resolvedStateDir = fs.realpathSync(stateDir);
      if (!resolvedStateDir.startsWith(resolvedRepo + path.sep) &&
          resolvedStateDir !== resolvedRepo) {
        logError('main', 'stateDir resolves outside repo');
        process.exit(0);
      }
      // Now safe to chmod
      fs.chmodSync(stateDir, 0o700);
    } else {
      // Create directory with restricted permissions (owner only)
      fs.mkdirSync(stateDir, { recursive: true, mode: 0o700 });
    }

    // Security: Verify tracePath is not a symlink and is a regular file
    if (fs.existsSync(tracePath)) {
      const tracePathStat = fs.lstatSync(tracePath);
      if (tracePathStat.isSymbolicLink()) {
        logError('main', 'tracePath is a symlink, refusing to write');
        process.exit(0);
      }
      if (!tracePathStat.isFile()) {
        logError('main', 'tracePath is not a regular file');
        process.exit(0);
      }
    }

    rotateIfNeeded(tracePath);

    // Security: Write with restricted permissions (owner read/write only)
    const fd = fs.openSync(tracePath, 'a', 0o600);
    // Verify opened file is regular file (post-open check)
    const fdStat = fs.fstatSync(fd);
    if (!fdStat.isFile()) {
      fs.closeSync(fd);
      logError('main', 'opened fd is not a regular file');
      process.exit(0);
    }
    fs.fchmodSync(fd, 0o600);
    fs.writeSync(fd, JSON.stringify(record) + '\n');
    fs.closeSync(fd);
  } catch (err) {
    logError('main', err);
  }

  process.exit(0);
}

main();
