package dashboardapi

import (
	"context"
	"database/sql"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"

	_ "github.com/glebarez/go-sqlite"
)

func TestNetrunnerThreadLoadsLinkedCodexTranscript(t *testing.T) {
	repo := openNetrunnerThreadFixture(t)
	defer repo.Close()

	transcriptRoot := t.TempDir()
	t.Setenv("FIXER_CODEX_SESSION_ROOT", transcriptRoot)
	transcriptPath := filepath.Join(transcriptRoot, "2026", "07", "23", "rollout-codex-thread-11.jsonl")
	if err := os.MkdirAll(filepath.Dir(transcriptPath), 0o755); err != nil {
		t.Fatalf("mkdir transcript: %v", err)
	}
	transcript := strings.Join([]string{
		`{"timestamp":"2026-07-23T10:00:00Z","type":"event_msg","payload":{"type":"user_message","message":"Inspect this failure"}}`,
		`{"timestamp":"2026-07-23T10:00:01Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"I found the cause."}]}}`,
		`{"type":"tool_call","payload":{"type":"tool_call","name":"exec"}}`,
	}, "\n") + "\n"
	if err := os.WriteFile(transcriptPath, []byte(transcript), 0o644); err != nil {
		t.Fatalf("write transcript: %v", err)
	}

	thread, err := repo.NetrunnerThread(context.Background(), 11)
	if err != nil {
		t.Fatalf("load thread: %v", err)
	}
	if thread.Backend != "codex" || thread.ExternalSessionID != "codex-thread-11" || thread.LaunchState != "linked" {
		t.Fatalf("unexpected linkage: %+v", thread)
	}
	if thread.TranscriptAvailability != "available" || thread.TranscriptPath != transcriptPath {
		t.Fatalf("unexpected transcript metadata: %+v", thread)
	}
	if len(thread.Messages) != 2 || thread.Messages[0].Role != "user" || thread.Messages[1].Text != "I found the cause." {
		t.Fatalf("unexpected normalized messages: %+v", thread.Messages)
	}
	if !thread.Continuation.Supported || thread.Continuation.Mode != "headless_resume" {
		t.Fatalf("expected Codex continuation support, got %+v", thread.Continuation)
	}
}

func TestNetrunnerThreadLeavesPendingManualSessionUnlaunched(t *testing.T) {
	repo := openNetrunnerThreadFixture(t)
	defer repo.Close()

	thread, err := repo.NetrunnerThread(context.Background(), 12)
	if err != nil {
		t.Fatalf("load pending manual thread: %v", err)
	}
	if thread.Backend != "" || thread.LaunchState != "awaiting_backend" {
		t.Fatalf("pending manual task must not default to Codex: %+v", thread)
	}
	if thread.Continuation.Supported || !strings.Contains(thread.Continuation.Reason, "Choose and launch") {
		t.Fatalf("unexpected pending capability: %+v", thread.Continuation)
	}
}

func TestNetrunnerThreadReportsUnsupportedProviderWithoutDiscardingLink(t *testing.T) {
	repo := openNetrunnerThreadFixture(t)
	defer repo.Close()

	thread, err := repo.NetrunnerThread(context.Background(), 13)
	if err != nil {
		t.Fatalf("load Kimi thread: %v", err)
	}
	if thread.Backend != "kimi-code" || thread.ExternalSessionID != "kimi-thread-13" {
		t.Fatalf("expected preserved Kimi linkage, got %+v", thread)
	}
	if thread.TranscriptAvailability != "metadata_only" || thread.Continuation.Supported {
		t.Fatalf("expected truthful metadata-only Kimi capability, got %+v", thread)
	}
	if !strings.Contains(thread.Continuation.Reason, "MCP config") {
		t.Fatalf("expected actionable unsupported reason, got %q", thread.Continuation.Reason)
	}
}

func TestContinueNetrunnerThreadUsesProviderResumeCommand(t *testing.T) {
	repo := openNetrunnerThreadFixture(t)
	defer repo.Close()

	originalStarter := startNetrunnerContinuation
	t.Cleanup(func() { startNetrunnerContinuation = originalStarter })
	var gotCWD string
	var gotCommand []string
	startNetrunnerContinuation = func(_ context.Context, cwd string, command []string) (int, error) {
		gotCWD = cwd
		gotCommand = append([]string(nil), command...)
		return 4242, nil
	}

	result, err := repo.ContinueNetrunnerThread(context.Background(), 11, ContinueNetrunnerThreadInput{Message: "Run the focused test again."})
	if err != nil {
		t.Fatalf("continue thread: %v", err)
	}
	wantCommand := []string{"codex", "exec", "resume", "codex-thread-11", "Run the focused test again."}
	if gotCWD != "/workspace/project" || !reflect.DeepEqual(gotCommand, wantCommand) {
		t.Fatalf("unexpected continuation start cwd=%q command=%v", gotCWD, gotCommand)
	}
	if result.Status != "started" || result.ProcessID != 4242 {
		t.Fatalf("unexpected continuation response: %+v", result)
	}
}

func openNetrunnerThreadFixture(t *testing.T) *Repository {
	t.Helper()
	dbPath := filepath.Join(t.TempDir(), "fixer.db")
	db, err := sql.Open("sqlite", dbPath)
	if err != nil {
		t.Fatalf("open fixture db: %v", err)
	}
	statements := []string{
		`CREATE TABLE project (id INTEGER PRIMARY KEY, name TEXT NOT NULL, cwd TEXT NOT NULL)`,
		`CREATE TABLE session (
			id INTEGER PRIMARY KEY,
			project_id INTEGER NOT NULL,
			task_description TEXT NOT NULL DEFAULT '',
			status TEXT NOT NULL,
			cli_backend TEXT,
			cli_model TEXT,
			cli_reasoning TEXT
		)`,
		`CREATE TABLE session_external_link (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			session_id INTEGER NOT NULL,
			backend TEXT NOT NULL,
			external_session_id TEXT NOT NULL,
			updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
		)`,
		`INSERT INTO project (id, name, cwd) VALUES (1, 'Project', '/workspace/project')`,
		`INSERT INTO session (id, project_id, status, cli_backend, cli_model, cli_reasoning) VALUES
			(11, 1, 'in_progress', 'codex', 'gpt-5.6-sol', 'high'),
			(12, 1, 'pending', '', '', ''),
			(13, 1, 'in_progress', 'kimi-code', 'kimi-k2.5', 'default')`,
		`INSERT INTO session_external_link (session_id, backend, external_session_id) VALUES
			(11, 'codex', 'codex-thread-11'),
			(13, 'kimi-code', 'kimi-thread-13')`,
	}
	for _, statement := range statements {
		if _, err := db.Exec(statement); err != nil {
			_ = db.Close()
			t.Fatalf("seed fixture with %q: %v", statement, err)
		}
	}
	if err := db.Close(); err != nil {
		t.Fatalf("close fixture db: %v", err)
	}
	repo, err := OpenRepository(dbPath, "/workspace/project")
	if err != nil {
		t.Fatalf("open repository: %v", err)
	}
	return repo
}
