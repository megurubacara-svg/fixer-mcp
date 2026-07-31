package main

import (
	"context"
	"os"
	"os/exec"
	"testing"
)

func TestLaunchParallelWaveReviewerUsesRuntimeSafePythonEnvironment(t *testing.T) {
	originalDB, originalRole, originalProjectID, originalExecCommand := db, authorizedRole, authorizedProjectId, execCommand
	defer func() {
		db, authorizedRole, authorizedProjectId, execCommand = originalDB, originalRole, originalProjectID, originalExecCommand
	}()

	repoDir := setupCleanGitRepo(t)
	testDB := setupParallelWaveTestDB(t, repoDir)
	defer testDB.Close()
	db, authorizedRole, authorizedProjectId = testDB, "fixer", 1
	t.Setenv(pythonNoBytecodeEnv, "0")

	var captured *exec.Cmd
	execCommand = func(name string, args ...string) *exec.Cmd {
		if name != "python3" {
			t.Fatalf("unexpected reviewer command %q", name)
		}
		captured = exec.Command(os.Args[0], "-test.run=^$")
		return captured
	}

	if err := launchParallelWaveReviewer(context.Background(), NetrunnerWaveSnapshot{Id: 42}, parallelWaveReviewSession{LocalSessionID: 2}); err != nil {
		t.Fatalf("launch reviewer: %v", err)
	}
	if captured == nil {
		t.Fatal("reviewer command was not captured")
	}
	env := envSliceToMap(captured.Env)
	if env[pythonNoBytecodeEnv] != "1" {
		t.Fatalf("reviewer bytecode guard = %q, want 1", env[pythonNoBytecodeEnv])
	}
	if env["FIXER_REVIEW_WAVE_ID"] != "42" {
		t.Fatalf("review wave ID = %q, want 42", env["FIXER_REVIEW_WAVE_ID"])
	}
}
