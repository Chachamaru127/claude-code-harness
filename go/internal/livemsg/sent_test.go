package livemsg_test

import (
	"context"
	"testing"
)

func TestStore_Sent_ReportsReadState(t *testing.T) {
	store, _ := openTestStore(t)
	defer store.Close()

	ctx := context.Background()
	team := "team-a"
	from := "agent-1"
	to := "agent-2"

	msgID, err := store.Send(ctx, team, from, to, "subj", "body")
	if err != nil {
		t.Fatalf("Send: %v", err)
	}

	sent, err := store.Sent(ctx, team, from)
	if err != nil {
		t.Fatalf("Sent: %v", err)
	}
	if len(sent) != 1 {
		t.Fatalf("Sent len = %d, want 1", len(sent))
	}
	if sent[0].ID != msgID || sent[0].Read {
		t.Fatalf("unexpected sent projection: %+v", sent[0])
	}

	if err := store.MarkRead(ctx, team, msgID, to); err != nil {
		t.Fatalf("MarkRead: %v", err)
	}

	sent, err = store.Sent(ctx, team, from)
	if err != nil {
		t.Fatalf("Sent after read: %v", err)
	}
	if len(sent) != 1 || !sent[0].Read {
		t.Fatalf("expected Read=true, got %+v", sent[0])
	}
	if sent[0].ReadAt.IsZero() {
		t.Fatal("ReadAt should be set")
	}
}
