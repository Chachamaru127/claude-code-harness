package hookhandler

import (
	"encoding/json"
	"fmt"
	"io"
	"os/exec"
)

// agentBrowserContext is the additionalContext injected when agent-browser is installed.
const agentBrowserContext = `💡 **Consider trying agent-browser first**

agent-browser is a browser automation tool optimised for AI agents.

` + "```bash" + `
# Basic usage
agent-browser open <url>
agent-browser snapshot -i -c  # AI-friendly snapshot
agent-browser click @e1        # Click by element reference
` + "```" + `

The current MCP tools are still available, but agent-browser is simpler and faster.

Details: ` + "`docs/OPTIONAL_PLUGINS.md`"

// agentBrowserLookupFn is the function used to check if agent-browser is
// installed. It is a package-level variable to allow injection in tests.
var agentBrowserLookupFn = agentBrowserInstalled

// HandleBrowserGuide ports pretooluse-browser-guide.sh.
//
// When agent-browser is installed, outputs an additionalContext recommendation.
// The hook matcher (hooks.json) already filters to MCP browser tool names, so
// no additional tool-name check is needed here.
func HandleBrowserGuide(in io.Reader, out io.Writer) error {
	// Read stdin — if empty, nothing to do (matches bash `[ -z "$INPUT" ] && exit 0`).
	data, err := io.ReadAll(in)
	if err != nil {
		return nil //nolint:nilerr // fail-open
	}
	if len(data) == 0 {
		return nil
	}

	// Only recommend when agent-browser is installed.
	if !agentBrowserLookupFn() {
		return nil
	}

	output := preToolAllowOutput{}
	output.HookSpecificOutput.HookEventName = "PreToolUse"
	output.HookSpecificOutput.AdditionalContext = agentBrowserContext

	out_data, err := json.Marshal(output)
	if err != nil {
		return fmt.Errorf("marshaling output: %w", err)
	}
	_, err = fmt.Fprintf(out, "%s\n", out_data)
	return err
}

// agentBrowserInstalled checks if the agent-browser binary is on PATH.
func agentBrowserInstalled() bool {
	_, err := exec.LookPath("agent-browser")
	return err == nil
}
