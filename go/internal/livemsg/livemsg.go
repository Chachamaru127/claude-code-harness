// Package livemsg は CCH 自前の live-notice message store を提供する（Mode 2 用）。
//
// Inspired by the agmsg pattern (MIT license). agmsg は append-only event log と
// read-projection の組み合わせで durable な agent-to-agent messaging を実現する
// 軽量パターンであり、本パッケージはその「append-only events + projection」モデルを
// 参考に CCH 文脈へ翻案している。
//
// 設計境界:
//   - durable work-handoff = harness-mem signal（別系統、本パッケージは触らない）
//   - live notice messaging = 本パッケージ（mem 未導入でも動く）
package livemsg

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"sync/atomic"
	"time"

	_ "modernc.org/sqlite" // SQLite ドライバ登録（副作用のみ使用）
)

// Store は live-notice message の append-only event store。
type Store struct {
	db *sql.DB
}

// Message は projection された 1 件のメッセージ。
type Message struct {
	ID        string
	Team      string
	FromAgent string
	ToAgent   string
	Subject   string
	Body      string
	CreatedAt time.Time
}

// SentMessage は送信者視点の projection（既読状態付き）。
type SentMessage struct {
	Message
	Read   bool
	ReadAt time.Time
}

var idSeq atomic.Uint64

const schemaDDL = `
CREATE TABLE IF NOT EXISTS livemsg_events (
  event_id      TEXT PRIMARY KEY,
  event_type    TEXT NOT NULL CHECK(event_type IN ('message_sent','message_read')),
  team          TEXT NOT NULL,
  message_id    TEXT NOT NULL,
  from_agent    TEXT,
  to_agent      TEXT,
  subject       TEXT,
  body          TEXT,
  read_by_agent TEXT,
  created_at    INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS livemsg_events_team_to ON livemsg_events(team, to_agent, created_at);
CREATE INDEX IF NOT EXISTS livemsg_events_msg ON livemsg_events(message_id);
`

// Open は sqlite ファイル（WAL mode）を開き、未マイグレーションなら schema を作る。
// メモリ DB は ":memory:" を受け付ける（test 用）。
func Open(dbPath string) (*Store, error) {
	if dbPath != ":memory:" {
		dir := filepath.Dir(dbPath)
		if dir != "" && dir != "." {
			if err := os.MkdirAll(dir, 0o755); err != nil {
				return nil, fmt.Errorf("livemsg: mkdir %s: %w", dir, err)
			}
		}
	}

	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		return nil, fmt.Errorf("livemsg: open db %s: %w", dbPath, err)
	}

	db.SetMaxOpenConns(1)

	if _, err := db.Exec("PRAGMA journal_mode = WAL"); err != nil {
		db.Close()
		return nil, fmt.Errorf("livemsg: set WAL mode: %w", err)
	}
	if _, err := db.Exec("PRAGMA busy_timeout = 5000"); err != nil {
		db.Close()
		return nil, fmt.Errorf("livemsg: set busy_timeout: %w", err)
	}

	store := &Store{db: db}
	if err := store.initSchema(); err != nil {
		db.Close()
		return nil, err
	}

	return store, nil
}

func (s *Store) initSchema() error {
	if _, err := s.db.Exec(schemaDDL); err != nil {
		return fmt.Errorf("livemsg: init schema: %w", err)
	}
	return nil
}

// Close は DB 接続を閉じる。
func (s *Store) Close() error {
	return s.db.Close()
}

func newEventID() string {
	seq := idSeq.Add(1)
	return fmt.Sprintf("evt-%d-%06d", time.Now().UnixNano(), seq%1_000_000)
}

func newMessageID() string {
	seq := idSeq.Add(1)
	return fmt.Sprintf("%d-%06d", time.Now().UnixNano(), seq%1_000_000)
}

// Send は message_sent event を 1 行 append し、生成された Message ID を返す。
func (s *Store) Send(ctx context.Context, team, from, to, subject, body string) (string, error) {
	if err := ctx.Err(); err != nil {
		return "", err
	}

	messageID := newMessageID()
	now := time.Now().UnixNano()

	_, err := s.db.ExecContext(ctx,
		`INSERT INTO livemsg_events
		 (event_id, event_type, team, message_id, from_agent, to_agent, subject, body, read_by_agent, created_at)
		 VALUES (?, 'message_sent', ?, ?, ?, ?, ?, ?, NULL, ?)`,
		newEventID(), team, messageID, from, to, subject, body, now,
	)
	if err != nil {
		return "", fmt.Errorf("livemsg: send: %w", err)
	}

	return messageID, nil
}

// MarkRead は message_read event を 1 行 append する。
func (s *Store) MarkRead(ctx context.Context, team, messageID, byAgent string) error {
	if err := ctx.Err(); err != nil {
		return err
	}

	now := time.Now().UnixNano()
	_, err := s.db.ExecContext(ctx,
		`INSERT INTO livemsg_events
		 (event_id, event_type, team, message_id, from_agent, to_agent, subject, body, read_by_agent, created_at)
		 VALUES (?, 'message_read', ?, ?, NULL, NULL, NULL, NULL, ?, ?)`,
		newEventID(), team, messageID, byAgent, now,
	)
	if err != nil {
		return fmt.Errorf("livemsg: mark read: %w", err)
	}
	return nil
}

const inboxQuery = `
SELECT message_id, team, from_agent, to_agent, subject, body, created_at
FROM livemsg_events s
WHERE s.event_type = 'message_sent'
  AND s.team = ?
  AND s.to_agent = ?
  AND NOT EXISTS (
    SELECT 1 FROM livemsg_events r
    WHERE r.event_type = 'message_read'
      AND r.team = s.team
      AND r.message_id = s.message_id
  )
ORDER BY s.created_at ASC`

const historyQuery = `
SELECT message_id, team, from_agent, to_agent, subject, body, created_at
FROM livemsg_events s
WHERE s.event_type = 'message_sent'
  AND s.team = ?
  AND s.to_agent = ?
ORDER BY s.created_at ASC`

const sentQuery = `
SELECT s.message_id, s.team, s.from_agent, s.to_agent, s.subject, s.body, s.created_at,
       EXISTS (
         SELECT 1 FROM livemsg_events r
         WHERE r.event_type = 'message_read'
           AND r.team = s.team
           AND r.message_id = s.message_id
       ) AS is_read,
       (
         SELECT MAX(r.created_at) FROM livemsg_events r
         WHERE r.event_type = 'message_read'
           AND r.team = s.team
           AND r.message_id = s.message_id
       ) AS read_at
FROM livemsg_events s
WHERE s.event_type = 'message_sent'
  AND s.team = ?
  AND s.from_agent = ?
ORDER BY s.created_at ASC`

// Inbox は (team, agent) 宛 unread message を CreatedAt 昇順で返す。
func (s *Store) Inbox(ctx context.Context, team, agent string) ([]Message, error) {
	return s.queryMessages(ctx, inboxQuery, team, agent)
}

// History は (team, agent) が受信した全 message（read 含む）を CreatedAt 昇順で返す。
func (s *Store) History(ctx context.Context, team, agent string) ([]Message, error) {
	return s.queryMessages(ctx, historyQuery, team, agent)
}

// Sent は (team, from) が送信した message と既読状態を CreatedAt 昇順で返す。
func (s *Store) Sent(ctx context.Context, team, from string) ([]SentMessage, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(ctx, sentQuery, team, from)
	if err != nil {
		return nil, fmt.Errorf("livemsg: query sent: %w", err)
	}
	defer rows.Close()

	var messages []SentMessage
	for rows.Next() {
		var (
			messageID string
			teamOut   string
			fromAgent sql.NullString
			toAgent   sql.NullString
			subject   sql.NullString
			body      sql.NullString
			createdAt int64
			isRead    bool
			readAt    sql.NullInt64
		)
		if err := rows.Scan(&messageID, &teamOut, &fromAgent, &toAgent, &subject, &body, &createdAt, &isRead, &readAt); err != nil {
			return nil, fmt.Errorf("livemsg: scan sent: %w", err)
		}
		sm := SentMessage{
			Message: Message{
				ID:        messageID,
				Team:      teamOut,
				FromAgent: fromAgent.String,
				ToAgent:   toAgent.String,
				Subject:   subject.String,
				Body:      body.String,
				CreatedAt: time.Unix(0, createdAt),
			},
			Read: isRead,
		}
		if readAt.Valid {
			sm.ReadAt = time.Unix(0, readAt.Int64)
		}
		messages = append(messages, sm)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("livemsg: iterate sent: %w", err)
	}
	if messages == nil {
		return []SentMessage{}, nil
	}
	return messages, nil
}

func (s *Store) queryMessages(ctx context.Context, query, team, agent string) ([]Message, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}

	rows, err := s.db.QueryContext(ctx, query, team, agent)
	if err != nil {
		return nil, fmt.Errorf("livemsg: query messages: %w", err)
	}
	defer rows.Close()

	var messages []Message
	for rows.Next() {
		var (
			messageID string
			teamOut   string
			fromAgent sql.NullString
			toAgent   sql.NullString
			subject   sql.NullString
			body      sql.NullString
			createdAt int64
		)
		if err := rows.Scan(&messageID, &teamOut, &fromAgent, &toAgent, &subject, &body, &createdAt); err != nil {
			return nil, fmt.Errorf("livemsg: scan message: %w", err)
		}
		messages = append(messages, Message{
			ID:        messageID,
			Team:      teamOut,
			FromAgent: fromAgent.String,
			ToAgent:   toAgent.String,
			Subject:   subject.String,
			Body:      body.String,
			CreatedAt: time.Unix(0, createdAt),
		})
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("livemsg: iterate messages: %w", err)
	}
	if messages == nil {
		return []Message{}, nil
	}
	return messages, nil
}
