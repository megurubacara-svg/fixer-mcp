package dashboardapi

import (
	"context"
	"testing"
)

func TestProjectNetrunnersGroupsWaveMembersAndLegacySessionsNewestFirst(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()
	seedNetrunnerWaveGroups(t, repo)

	response, err := repo.ProjectNetrunners(context.Background(), 1, nil)
	if err != nil {
		t.Fatalf("load grouped netrunners: %v", err)
	}
	if len(response.WaveGroups) != 2 {
		t.Fatalf("expected two wave groups, got %+v", response.WaveGroups)
	}
	if response.WaveGroups[0].WaveID != 8 || response.WaveGroups[1].WaveID != 7 {
		t.Fatalf("expected newest waves first, got %+v", response.WaveGroups)
	}
	if len(response.UngroupedSessions) != 1 || response.UngroupedSessions[0].ID != 12 {
		t.Fatalf("expected legacy session 12 to remain ungrouped, got %+v", response.UngroupedSessions)
	}

	pendingWorker := response.WaveGroups[0].Sessions[0]
	if pendingWorker.ID != 11 || pendingWorker.Kind != netrunnerKindWorker {
		t.Fatalf("unexpected pending wave worker: %+v", pendingWorker)
	}
	if pendingWorker.Backend != "" || pendingWorker.Model != "" || pendingWorker.Reasoning != "" {
		t.Fatalf("backend details must stay hidden before launch: %+v", pendingWorker)
	}

	waveSeven := response.WaveGroups[1]
	if waveSeven.WorkerCount != 1 || waveSeven.ReviewerCount != 1 || waveSeven.ManualCount != 1 {
		t.Fatalf("unexpected wave membership counts: %+v", waveSeven)
	}
	wantKinds := []string{netrunnerKindManual, netrunnerKindReviewer, netrunnerKindWorker}
	for index, wantKind := range wantKinds {
		if waveSeven.Sessions[index].Kind != wantKind {
			t.Fatalf("session %d kind = %q, want %q; sessions=%+v", index, waveSeven.Sessions[index].Kind, wantKind, waveSeven.Sessions)
		}
		if waveSeven.Sessions[index].Role != "netrunner" || waveSeven.Sessions[index].WaveID != 7 {
			t.Fatalf("missing role/wave identity on %+v", waveSeven.Sessions[index])
		}
	}
	launchedWorker := waveSeven.Sessions[2]
	if launchedWorker.Backend != "codex" || launchedWorker.Model != "gpt-5.4" || launchedWorker.LaunchedAt == "" {
		t.Fatalf("expected backend details after launch, got %+v", launchedWorker)
	}
	if len(response.Sessions) == 0 || response.Sessions[0].ID != 14 {
		t.Fatalf("legacy flat collection must also be newest-first, got %+v", response.Sessions)
	}
}

func TestProjectNetrunnersAppliesStatusFilterIndependentlyAcrossGroups(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()
	seedNetrunnerWaveGroups(t, repo)

	response, err := repo.ProjectNetrunners(context.Background(), 1, []string{"review"})
	if err != nil {
		t.Fatalf("load filtered grouped netrunners: %v", err)
	}
	if len(response.Statuses) != 1 || response.Statuses[0] != "review" {
		t.Fatalf("unexpected normalized filters: %+v", response.Statuses)
	}
	if len(response.WaveGroups) != 1 || response.WaveGroups[0].WaveID != 7 {
		t.Fatalf("expected only wave 7 after review filter, got %+v", response.WaveGroups)
	}
	if len(response.WaveGroups[0].Sessions) != 1 || response.WaveGroups[0].Sessions[0].Kind != netrunnerKindReviewer {
		t.Fatalf("expected only reviewer in grouped result, got %+v", response.WaveGroups[0].Sessions)
	}
	if len(response.UngroupedSessions) != 1 || response.UngroupedSessions[0].ID != 12 {
		t.Fatalf("expected independently filtered legacy review session, got %+v", response.UngroupedSessions)
	}
}

func TestProjectNetrunnersWithoutWaveTablesReturnsLegacySessions(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()

	response, err := repo.ProjectNetrunners(context.Background(), 1, nil)
	if err != nil {
		t.Fatalf("load legacy netrunners: %v", err)
	}
	if len(response.WaveGroups) != 0 || len(response.UngroupedSessions) != 3 {
		t.Fatalf("expected a graceful legacy-only response, got %+v", response)
	}
	if response.UngroupedSessions[0].ID != 12 || response.UngroupedSessions[0].Kind != netrunnerKindLegacy {
		t.Fatalf("expected newest legacy session first, got %+v", response.UngroupedSessions)
	}
	if response.UngroupedSessions[1].Backend == "" {
		t.Fatalf("session 11 has launch evidence and should expose its backend: %+v", response.UngroupedSessions[1])
	}
}

func seedNetrunnerWaveGroups(t *testing.T, repo *Repository) {
	t.Helper()
	statements := []string{
		"ALTER TABLE session ADD COLUMN parallel_wave_id TEXT NOT NULL DEFAULT ''",
		"ALTER TABLE worker_process ADD COLUMN parallel_wave_id INTEGER",
		"ALTER TABLE worker_process ADD COLUMN parallel_wave_worker_id INTEGER",
		`CREATE TABLE parallel_wave (
			id INTEGER PRIMARY KEY,
			project_id INTEGER NOT NULL,
			status TEXT NOT NULL,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL,
			launched_at TEXT,
			completed_at TEXT
		)`,
		`CREATE TABLE parallel_wave_worker (
			id INTEGER PRIMARY KEY,
			wave_id INTEGER NOT NULL,
			project_id INTEGER NOT NULL,
			session_id INTEGER NOT NULL,
			status TEXT NOT NULL,
			created_at TEXT NOT NULL,
			updated_at TEXT NOT NULL,
			launched_at TEXT,
			terminal_at TEXT
		)`,
		"INSERT INTO parallel_wave VALUES (7, 1, 'completed', '2026-07-20T09:00:00Z', '2026-07-20T12:00:00Z', '2026-07-20T09:05:00Z', '2026-07-20T12:00:00Z')",
		"INSERT INTO parallel_wave VALUES (8, 1, 'created', '2026-07-21T09:00:00Z', '2026-07-21T09:00:00Z', NULL, NULL)",
		"UPDATE session SET parallel_wave_id = '7' WHERE id = 10",
		"UPDATE session SET parallel_wave_id = '8', status = 'pending' WHERE id = 11",
		"INSERT INTO session (id, project_id, task_description, status, cli_backend, cli_model, cli_reasoning, parallel_wave_id) VALUES (13, 1, 'Post-wave Reviewer for parallel wave 7', 'review', 'codex', 'gpt-5.6', 'high', 'parallel-wave-review:7')",
		"INSERT INTO session (id, project_id, task_description, status, cli_backend, cli_model, cli_reasoning, parallel_wave_id) VALUES (14, 1, 'Architect manual verification', 'in_progress', 'droid', 'sonnet', 'high', '7')",
		"INSERT INTO parallel_wave_worker VALUES (70, 7, 1, 10, 'review_ready', '2026-07-20T09:00:00Z', '2026-07-20T11:00:00Z', '2026-07-20T09:05:00Z', '2026-07-20T11:00:00Z')",
		"INSERT INTO parallel_wave_worker VALUES (80, 8, 1, 11, 'created', '2026-07-21T09:00:00Z', '2026-07-21T09:00:00Z', NULL, NULL)",
		"INSERT INTO worker_process (project_id, session_id, pid, launch_epoch, status, launch_origin, parallel_wave_id, started_at, updated_at, stopped_at) VALUES (1, 13, 0, 4, 'exited', 'parallel-wave-reviewer', 7, '2026-07-20T11:05:00Z', '2026-07-20T11:30:00Z', '2026-07-20T11:30:00Z')",
		"INSERT INTO worker_process (project_id, session_id, pid, launch_epoch, status, launch_origin, parallel_wave_id, started_at, updated_at) VALUES (1, 14, 0, 4, 'running', 'explicit-wait', 7, '2026-07-20T11:45:00Z', '2026-07-20T11:50:00Z')",
	}
	for _, statement := range statements {
		if _, err := repo.dbWrite.Exec(statement); err != nil {
			t.Fatalf("seed grouped netrunner fixture with %q: %v", statement, err)
		}
	}
}
