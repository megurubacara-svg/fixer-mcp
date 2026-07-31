package dashboardapi

import (
	"net/http/httptest"
	"testing"
)

func TestProjectWaveReviewsRouteExposesReviewerSessionReport(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()

	if _, err := repo.dbWrite.Exec("ALTER TABLE session ADD COLUMN parallel_wave_id TEXT NOT NULL DEFAULT ''"); err != nil {
		t.Fatalf("add parallel wave marker column: %v", err)
	}
	report := `{"files_changed":[],"commands_run":["go test ./..."],"checks_run":["all checks passed"],"blockers":[]}`
	if _, err := repo.dbWrite.Exec(
		"INSERT INTO session (project_id, task_description, status, report, parallel_wave_id) VALUES (1, ?, 'review', ?, ?)",
		"Post-wave Reviewer for parallel wave 7",
		report,
		"parallel-wave-review:7",
	); err != nil {
		t.Fatalf("seed reviewer session: %v", err)
	}

	server := httptest.NewServer(NewServer(repo))
	defer server.Close()
	var response ProjectWaveReviewsResponse
	readJSON(t, server.URL+"/api/projects/1/wave-reviews", &response)
	if len(response.Reviews) != 1 {
		t.Fatalf("expected one wave review, got %+v", response.Reviews)
	}
	review := response.Reviews[0]
	if review.WaveID != 7 || review.Status != "review" || review.StructuredFinalReport == nil {
		t.Fatalf("unexpected wave review payload: %+v", review)
	}
}
