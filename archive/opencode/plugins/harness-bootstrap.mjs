import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const skillsDir = path.resolve(__dirname, "../skills");
const bootstrapSkillPath = path.join(skillsDir, "harness-plan", "SKILL.md");
const marker = "HARNESS_BOOTSTRAP";

let bootstrapCache;
let bootstrapReadCount = 0;

function stripFrontmatter(content) {
  return content.replace(/^---\n[\s\S]*?\n---\n?/, "").trim();
}

function getBootstrapContent() {
  if (bootstrapCache !== undefined) {
    return bootstrapCache;
  }

  if (!fs.existsSync(bootstrapSkillPath)) {
    bootstrapCache = null;
    return bootstrapCache;
  }

  bootstrapReadCount += 1;
  const body = stripFrontmatter(fs.readFileSync(bootstrapSkillPath, "utf8"));
  bootstrapCache = `<${marker}>
Claude Code Harness workflows are available through OpenCode skills.

Use OpenCode's native skill tool to load the right Harness workflow:
- harness-plan for evidence-backed planning
- harness-work for Plans.md execution
- harness-review for independent review
- harness-release for release and handoff checks
- harness-setup for setup checks
- breezing for team execution mode

Tool mapping:
- Claude Skill tool -> OpenCode native skill tool
- Claude Task/subagent routing -> OpenCode subagent facilities when available
- Claude hook parity is not claimed for OpenCode

Boundary: not_observed != absent. Runtime smoke absence keeps OpenCode at
internal-compatible; it is not public supported parity.

Reference content:
${body}
</${marker}>`;
  return bootstrapCache;
}

function firstUserMessage(output) {
  if (!output || !Array.isArray(output.messages)) {
    return null;
  }
  return output.messages.find((message) => message.info && message.info.role === "user") || null;
}

function hasBootstrap(message) {
  return Boolean(
    message &&
      Array.isArray(message.parts) &&
      message.parts.some((part) => part && part.type === "text" && String(part.text || "").includes(marker))
  );
}

export const HarnessBootstrapPlugin = async () => ({
  config: async (config) => {
    config.skills = config.skills || {};
    config.skills.paths = config.skills.paths || [];
    if (!config.skills.paths.includes(skillsDir)) {
      config.skills.paths.push(skillsDir);
    }
  },

  "experimental.chat.messages.transform": async (_input, output) => {
    const bootstrap = getBootstrapContent();
    if (!bootstrap) {
      return;
    }

    const message = firstUserMessage(output);
    if (!message || !Array.isArray(message.parts) || message.parts.length === 0 || hasBootstrap(message)) {
      return;
    }

    const ref = message.parts[0];
    message.parts.unshift({ ...ref, type: "text", text: bootstrap });
  }
});

export function __resetHarnessBootstrapCacheForTest() {
  bootstrapCache = undefined;
  bootstrapReadCount = 0;
}

export function __getHarnessBootstrapReadCountForTest() {
  return bootstrapReadCount;
}

export function __getHarnessBootstrapContentForTest() {
  return getBootstrapContent();
}
