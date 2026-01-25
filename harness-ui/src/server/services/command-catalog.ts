import { readdir, readFile } from 'fs/promises';
import { join, basename } from 'path';
import type { CoreCommand } from '@shared/types';

interface CommandCatalogConfig {
  commandsCorePath: string;
}

export class CommandCatalog {
  private commands: CoreCommand[] = [];
  private config: CommandCatalogConfig;
  private lastLoaded: number = 0;

  constructor(commandsCorePath: string) {
    this.config = { commandsCorePath };
  }

  setCommandsPath(path: string): void {
    this.config.commandsCorePath = path;
  }

  getCommandsPath(): string {
    return this.config.commandsCorePath;
  }

  async reload(): Promise<CoreCommand[]> {
    try {
      const files = await readdir(this.config.commandsCorePath);
      const mdFiles = files.filter(f => f.endsWith('.md') && f !== 'CLAUDE.md');

      const commands: CoreCommand[] = [];

      for (const file of mdFiles) {
        const filePath = join(this.config.commandsCorePath, file);
        const content = await readFile(filePath, 'utf-8');
        const command = this.parseCommand(file, content);
        if (command) {
          commands.push(command);
        }
      }

      // Sort by name
      commands.sort((a, b) => a.name.localeCompare(b.name));

      this.commands = commands;
      this.lastLoaded = Date.now();

      return commands;
    } catch (error) {
      console.error(`Failed to load commands from ${this.config.commandsCorePath}:`, error);
      return this.commands; // Return cached commands on error
    }
  }

  private parseCommand(filename: string, content: string): CoreCommand | null {
    // Extract command name from filename (e.g., "harness-init.md" -> "/init")
    const name = '/' + basename(filename, '.md');
    const id = basename(filename, '.md').replace(/-/g, '_');

    // Parse YAML frontmatter
    const frontmatterMatch = content.match(/^---\n([\s\S]*?)\n---/);
    let description = '';

    if (frontmatterMatch) {
      const frontmatter = frontmatterMatch[1];
      // Extract description field
      const descMatch = frontmatter.match(/^description:\s*(.+)$/m);
      if (descMatch) {
        description = descMatch[1].trim();
      }
    }

    // Fallback: try to extract from first heading or first paragraph
    if (!description) {
      const headingMatch = content.match(/^#\s+(.+?)(?:\s*-\s*(.+))?$/m);
      if (headingMatch && headingMatch[2]) {
        description = headingMatch[2].trim();
      } else {
        // Use first non-empty, non-heading line
        const lines = content.split('\n');
        for (const line of lines) {
          const trimmed = line.trim();
          if (trimmed && !trimmed.startsWith('#') && !trimmed.startsWith('---')) {
            description = trimmed.slice(0, 100);
            break;
          }
        }
      }
    }

    // Determine template based on command type
    const hasInput = this.commandRequiresInput(name);
    const template = hasInput ? `${name} {input}` : name;

    return {
      id,
      name,
      description: description || `${name} コマンド`,
      template,
    };
  }

  private commandRequiresInput(name: string): boolean {
    // Commands that typically require input
    const inputCommands = [
      '/plan',
      '/work',
      '/review',
    ];
    return inputCommands.some(cmd => name.includes(cmd.replace('/', '')));
  }

  getCommands(): CoreCommand[] {
    return this.commands;
  }

  getLastLoaded(): number {
    return this.lastLoaded;
  }
}

// Default instance
const defaultCommandsPath = join(process.cwd(), '..', 'commands', 'core');
export const commandCatalog = new CommandCatalog(defaultCommandsPath);
