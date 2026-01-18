import { readFile, readdir } from 'fs/promises';
import { homedir } from 'os';
import { join } from 'path';
import { ptyManager } from './services/pty-manager';
import { PlansParser } from './services/plans-parser';
import { commandCatalog } from './services/command-catalog';
import { discoverProjects } from './services/project-discovery';
import type {
  WSMessage,
  SessionsListPayload,
  SessionUpdatePayload,
  LogChunkPayload,
  SendInputPayload,
  CreateSessionPayload,
  DestroySessionPayload,
  ResizeTerminalPayload,
  PlansData,
  Project,
  ProjectsData,
  SessionArchive,
  SessionArchivesData,
} from '@shared/types';

const PORT = parseInt(process.env.PORT || '3001', 10);
const DEFAULT_PLANS_PATH = process.env.PLANS_PATH || join(process.cwd(), '..', 'Plans.md');
const DEFAULT_COMMANDS_PATH = join(process.cwd(), '..', 'commands', 'core');
const DEFAULT_DISCOVERY_ROOT = join(homedir(), 'Desktop', 'Code');

// Initialize command catalog
commandCatalog.setCommandsPath(DEFAULT_COMMANDS_PATH);
commandCatalog.reload().then(() => {
  console.log(`Loaded ${commandCatalog.getCommands().length} commands from ${DEFAULT_COMMANDS_PATH}`);
});

// Multi-project management (in-memory store)
let projectsData: ProjectsData = {
  projects: [],
  activeProjectId: null,
};

// Plans parsers per project
const plansParsers = new Map<string, PlansParser>();
let discoveryPromise: Promise<void> | null = null;

// Initialize default project
function initDefaultProject(): void {
  const defaultProject: Project = {
    id: 'default',
    name: 'Current Project',
    path: join(process.cwd(), '..'),
    plansPath: DEFAULT_PLANS_PATH,
    worktreePaths: [],
    isActive: true,
  };
  projectsData.projects.push(defaultProject);
  projectsData.activeProjectId = 'default';
  plansParsers.set('default', new PlansParser(DEFAULT_PLANS_PATH));
}

function syncActiveProjectSettings(projectId: string | null): void {
  if (!projectId) return;
  const project = projectsData.projects.find((p) => p.id === projectId);
  if (!project) return;

  const current = ptyManager.getSettings();
  ptyManager.setSettings({
    project: {
      ...current.project,
      mainPath: project.path,
      worktreePaths: project.worktreePaths ?? [],
    },
  });
}

function mergeDiscoveredProjects(discovered: Project[]): void {
  const existingPaths = new Set(projectsData.projects.map((p) => p.path));
  for (const project of discovered) {
    if (existingPaths.has(project.path)) continue;
    projectsData.projects.push(project);
  }
}

async function ensureDiscoveredProjects(): Promise<void> {
  if (!discoveryPromise) {
    discoveryPromise = (async () => {
      const discovered = await discoverProjects({ rootPath: DEFAULT_DISCOVERY_ROOT });
      mergeDiscoveredProjects(discovered);
    })();
  }
  await discoveryPromise;
}

function ensurePlansParser(projectId: string): PlansParser | undefined {
  const existing = plansParsers.get(projectId);
  if (existing) return existing;

  const project = projectsData.projects.find((p) => p.id === projectId);
  if (!project) return undefined;

  const parser = new PlansParser(project.plansPath);
  plansParsers.set(projectId, parser);
  setupPlansParserCallback(projectId, parser);
  parser.startWatching();
  return parser;
}

// Get active Plans parser
function getActivePlansParser(): PlansParser | undefined {
  if (!projectsData.activeProjectId) return undefined;
  return ensurePlansParser(projectsData.activeProjectId);
}

initDefaultProject();
syncActiveProjectSettings('default');

syncActiveProjectSettings('default');

// WebSocket clients
const clients = new Set<WebSocket>();

// Broadcast to all clients
function broadcast<T>(message: WSMessage<T>): void {
  const data = JSON.stringify(message);
  for (const client of clients) {
    if (client.readyState === WebSocket.OPEN) {
      client.send(data);
    }
  }
}

// Setup PlansParser callback for a project
function setupPlansParserCallback(projectId: string, parser: PlansParser): void {
  parser.setUpdateCallback((data) => {
    broadcast<PlansData>({
      type: 'plans_update',
      payload: { ...data, projectId },
    });
  });
}

// Initialize default project's parser callback
const defaultParser = plansParsers.get('default');
if (defaultParser) {
  setupPlansParserCallback('default', defaultParser);
}

// Set up PTY callbacks
ptyManager.setMessageCallback((sessionId, data) => {
  broadcast<LogChunkPayload>({
    type: 'log_chunk',
    payload: { sessionId, data },
  });
});

ptyManager.setUpdateCallback((session) => {
  broadcast<SessionUpdatePayload>({
    type: 'session_update',
    payload: { session },
  });
});


// Handle WebSocket messages
async function handleMessage(ws: WebSocket, message: string): Promise<void> {
  try {
    const msg = JSON.parse(message) as WSMessage;

    switch (msg.type) {
      case 'send_input': {
        const { sessionId, data } = msg.payload as SendInputPayload;
        ptyManager.sendInput(sessionId, data);
        break;
      }

      case 'create_session': {
        const { projectId, worktreePath } = (msg.payload as CreateSessionPayload) || {};
        const effectiveProjectId = projectId || projectsData.activeProjectId || 'default';
        const project = projectsData.projects.find((p) => p.id === effectiveProjectId);
        const fallbackPath = project?.path || ptyManager.getSettings().project.mainPath;
        const resolvedWorktreePath = worktreePath || fallbackPath;
        const session = await ptyManager.createSession(effectiveProjectId, resolvedWorktreePath);
        ws.send(
          JSON.stringify({
            type: 'session_update',
            payload: { session },
          } as WSMessage<SessionUpdatePayload>)
        );
        break;
      }

      case 'destroy_session': {
        const { sessionId } = msg.payload as DestroySessionPayload;
        ptyManager.destroySession(sessionId);
        break;
      }

      case 'resize_terminal': {
        const { sessionId, cols, rows } = msg.payload as ResizeTerminalPayload;
        ptyManager.resizeTerminal(sessionId, cols, rows);
        break;
      }

      default:
        console.warn(`Unknown message type: ${msg.type}`);
    }
  } catch (error) {
    console.error(`Error handling message: ${error}`);
  }
}

// Serve static files
async function serveStatic(path: string): Promise<Response> {
  const distDir = join(import.meta.dir, '..', '..', 'dist', 'client');

  let filePath = path === '/' ? '/index.html' : path;
  const fullPath = join(distDir, filePath);

  try {
    const file = await readFile(fullPath);
    const contentType = getContentType(filePath);
    return new Response(file, {
      headers: { 'Content-Type': contentType },
    });
  } catch {
    // SPA fallback
    try {
      const indexPath = join(distDir, 'index.html');
      const file = await readFile(indexPath);
      return new Response(file, {
        headers: { 'Content-Type': 'text/html' },
      });
    } catch {
      return new Response('Not Found', { status: 404 });
    }
  }
}

function getContentType(path: string): string {
  const ext = path.split('.').pop()?.toLowerCase();
  const types: Record<string, string> = {
    html: 'text/html',
    css: 'text/css',
    js: 'application/javascript',
    json: 'application/json',
    png: 'image/png',
    svg: 'image/svg+xml',
    ico: 'image/x-icon',
  };
  return types[ext || ''] || 'application/octet-stream';
}

// Start server
const server = Bun.serve({
  port: PORT,

  async fetch(req, server) {
    const url = new URL(req.url);

    // WebSocket upgrade
    if (url.pathname === '/ws') {
      const success = server.upgrade(req);
      if (success) return undefined;
      return new Response('WebSocket upgrade failed', { status: 400 });
    }

    // API endpoints
    if (url.pathname === '/api/sessions') {
      const projectId = url.searchParams.get('projectId');
      const sessions = projectId
        ? ptyManager.getSessionsByProject(projectId)
        : ptyManager.getAllSessions();
      return Response.json({ sessions });
    }

    if (url.pathname === '/api/commands') {
      return Response.json({ commands: commandCatalog.getCommands() });
    }

    if (url.pathname === '/api/commands/reload' && req.method === 'POST') {
      const commands = await commandCatalog.reload();
      return Response.json({ success: true, count: commands.length });
    }

    if (url.pathname === '/api/projects') {
      if (req.method === 'GET') {
        await ensureDiscoveredProjects();
        return Response.json(projectsData);
      }
      if (req.method === 'POST') {
        const body = await req.json() as { action: string; project?: Project; projectId?: string };
        if (body.action === 'add' && body.project) {
          const newProject: Project = {
            ...body.project,
            id: `proj_${Date.now()}`,
            isActive: false,
          };
          projectsData.projects.push(newProject);
          const newParser = new PlansParser(newProject.plansPath);
          plansParsers.set(newProject.id, newParser);
          setupPlansParserCallback(newProject.id, newParser);
          // Start watching the new project's Plans.md
          newParser.startWatching();
          console.log(`Started watching Plans.md for project ${newProject.id}`);
          return Response.json({ success: true, project: newProject });
        }
        if (body.action === 'activate' && body.projectId) {
          projectsData.projects.forEach(p => p.isActive = p.id === body.projectId);
          projectsData.activeProjectId = body.projectId;
          syncActiveProjectSettings(body.projectId);
          ensurePlansParser(body.projectId);
          return Response.json({ success: true });
        }
        if (body.action === 'remove' && body.projectId) {
          projectsData.projects = projectsData.projects.filter(p => p.id !== body.projectId);
          plansParsers.delete(body.projectId);
          if (projectsData.activeProjectId === body.projectId) {
            projectsData.activeProjectId = projectsData.projects[0]?.id || null;
          }
          syncActiveProjectSettings(projectsData.activeProjectId);
          return Response.json({ success: true });
        }
        return Response.json({ error: 'Invalid action' }, { status: 400 });
      }
    }

    if (url.pathname === '/api/plans') {
      const projectId = url.searchParams.get('projectId');
      const projectPath = url.searchParams.get('projectPath');
      let parser: PlansParser | undefined;

      if (projectId) {
        // Find project by ID (preferred)
        parser = ensurePlansParser(projectId);
      } else if (projectPath) {
        // Find project by path (fallback)
        const project = projectsData.projects.find(p => p.path === projectPath);
        if (project) {
          parser = ensurePlansParser(project.id);
        }
      } else {
        // Use active project
        parser = getActivePlansParser();
      }

      if (!parser) {
        return Response.json({ sections: [], summary: { total: 0, pending: 0, inProgress: 0, completed: 0, blocked: 0, progressPercent: 0 } });
      }
      const data = await parser.parse();
      return Response.json(data);
    }

    // Session archives API for resume/fork UX
    if (url.pathname === '/api/session-archives') {
      const projectPath = url.searchParams.get('projectPath');
      const basePath = projectPath || join(process.cwd(), '..');
      const stateDir = join(basePath, '.claude', 'state');
      const archiveDir = join(stateDir, 'sessions');
      const currentFile = join(stateDir, 'session.json');

      const result: SessionArchivesData = { archives: [], current: null };

      // Read current session
      try {
        const currentContent = await readFile(currentFile, 'utf-8');
        const currentData = JSON.parse(currentContent);
        result.current = {
          session_id: currentData.session_id,
          parent_session_id: currentData.parent_session_id,
          state: currentData.state,
          started_at: currentData.started_at,
          ended_at: currentData.ended_at,
          updated_at: currentData.updated_at,
          duration_minutes: currentData.duration_minutes,
          project_name: currentData.project_name,
          git_branch: currentData.git?.branch,
        };
      } catch {
        // Current session file doesn't exist
      }

      // Read archived sessions
      try {
        const files = await readdir(archiveDir);
        const jsonFiles = files.filter(f => f.endsWith('.json'));

        for (const file of jsonFiles) {
          try {
            const content = await readFile(join(archiveDir, file), 'utf-8');
            const data = JSON.parse(content);
            result.archives.push({
              session_id: data.session_id,
              parent_session_id: data.parent_session_id,
              state: data.state,
              started_at: data.started_at,
              ended_at: data.ended_at,
              updated_at: data.updated_at,
              duration_minutes: data.duration_minutes,
              project_name: data.project_name,
              git_branch: data.git?.branch,
            });
          } catch {
            // Skip invalid files
          }
        }

        // Sort by updated_at descending
        result.archives.sort((a, b) =>
          new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime()
        );
      } catch {
        // Archive directory doesn't exist
      }

      return Response.json(result);
    }

    if (url.pathname === '/api/settings') {
      if (req.method === 'GET') {
        const settings = ptyManager.getSettings();
        // Include current commands path
        settings.commands = {
          corePath: commandCatalog.getCommandsPath(),
        };
        return Response.json(settings);
      }
      if (req.method === 'POST') {
        const body = await req.json();
        ptyManager.setSettings(body);
        // Apply commands path if provided
        if (body.commands?.corePath) {
          commandCatalog.setCommandsPath(body.commands.corePath);
          await commandCatalog.reload();
        }
        return Response.json({ success: true });
      }
    }

    // Static files
    return serveStatic(url.pathname);
  },

  websocket: {
    open(ws) {
      clients.add(ws as unknown as WebSocket);

      // Send initial data
      const sessions = ptyManager.getAllSessions();
      ws.send(
        JSON.stringify({
          type: 'sessions_list',
          payload: { sessions },
        } as WSMessage<SessionsListPayload>)
      );
    },

    message(ws, message) {
      handleMessage(ws as unknown as WebSocket, message.toString());
    },

    close(ws) {
      clients.delete(ws as unknown as WebSocket);
    },
  },
});

// Start watching Plans.md for all projects
for (const [id, parser] of plansParsers) {
  parser.startWatching();
  console.log(`Watching Plans.md for project ${id}`);
}

console.log(`Harness UI Server running on http://localhost:${PORT}`);
console.log(`WebSocket available at ws://localhost:${PORT}/ws`);
console.log(`Watching Plans.md at: ${DEFAULT_PLANS_PATH}`);

// Cleanup on exit
process.on('SIGINT', () => {
  console.log('\nShutting down...');
  for (const [, parser] of plansParsers) {
    parser.stopWatching();
  }
  ptyManager.destroy();
  process.exit(0);
});
