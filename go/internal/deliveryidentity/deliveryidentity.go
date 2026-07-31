// Package deliveryidentity resolves livemsg team/agent for Mode-2 delivery hooks.
// Generated hook commands use `inbox check --from-env` so identity is read at
// execution time (one hooks.json per checkout; team/agent vary per session).
package deliveryidentity

import (
	"errors"
	"os"
	"strings"
)

const (
	// EnvTeam is the primary team id for directed livemsg delivery.
	EnvTeam = "HARNESS_LIVEMSG_TEAM"
	// EnvAgent is the receiving agent name within the team.
	EnvAgent = "HARNESS_LIVEMSG_AGENT"
)

// ErrMissingIdentity is returned when neither explicit env nor breezing fallbacks
// yield a team id (agent may default to "solo" when team is known).
var ErrMissingIdentity = errors.New("delivery identity: team could not be resolved from environment")

// Resolve returns team and agent for livemsg inbox routing.
//
// Precedence:
//  1. HARNESS_LIVEMSG_TEAM and HARNESS_LIVEMSG_AGENT when both non-empty
//  2. Otherwise team from BREEZING_SESSION_ID; agent from BREEZING_ROLE or "solo"
//
// Values are used as argv (never shell-interpolated) so arbitrary safe strings
// are acceptable; callers must not embed them in shell scripts unquoted.
func Resolve() (team, agent string, err error) {
	team = strings.TrimSpace(os.Getenv(EnvTeam))
	agent = strings.TrimSpace(os.Getenv(EnvAgent))
	if team != "" && agent != "" {
		return team, agent, nil
	}
	if team == "" {
		team = strings.TrimSpace(os.Getenv("BREEZING_SESSION_ID"))
	}
	if agent == "" {
		agent = strings.TrimSpace(os.Getenv("BREEZING_ROLE"))
		if agent == "" {
			agent = "solo"
		}
	}
	if team == "" {
		return "", "", ErrMissingIdentity
	}
	return team, agent, nil
}
