package deliveryidentity

import (
	"testing"
)

func TestResolve_ExplicitEnv(t *testing.T) {
	t.Setenv(EnvTeam, "team-x")
	t.Setenv(EnvAgent, "agent-y")
	team, agent, err := Resolve()
	if err != nil {
		t.Fatalf("Resolve: %v", err)
	}
	if team != "team-x" || agent != "agent-y" {
		t.Fatalf("got team=%q agent=%q", team, agent)
	}
}

func TestResolve_BreezingFallback(t *testing.T) {
	t.Setenv(EnvTeam, "")
	t.Setenv(EnvAgent, "")
	t.Setenv("BREEZING_SESSION_ID", "sess-abc")
	t.Setenv("BREEZING_ROLE", "implementer")
	team, agent, err := Resolve()
	if err != nil {
		t.Fatalf("Resolve: %v", err)
	}
	if team != "sess-abc" || agent != "implementer" {
		t.Fatalf("got team=%q agent=%q", team, agent)
	}
}

func TestResolve_MissingIdentity(t *testing.T) {
	t.Setenv(EnvTeam, "")
	t.Setenv(EnvAgent, "")
	t.Setenv("BREEZING_SESSION_ID", "")
	t.Setenv("BREEZING_ROLE", "")
	if _, _, err := Resolve(); err == nil {
		t.Fatal("expected error when no identity source is set")
	}
}
