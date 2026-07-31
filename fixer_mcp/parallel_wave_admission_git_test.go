package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestNormalizeParallelWaveAdmissionWorkersAllowsOnlySequentialOverlap(t *testing.T) {
	workers := []parallelWaveAdmissionWorker{
		{SessionID: 1, DeclaredWriteScope: []string{"docs"}},
		{SessionID: 2, DeclaredWriteScope: []string{"docs/generated"}},
	}

	if _, err := normalizeParallelWaveAdmissionWorkersWithDependencies(workers, nil); err == nil || !strings.Contains(err.Error(), "overlapping declared write scopes") {
		t.Fatalf("expected unrelated overlapping scopes to be rejected, got %v", err)
	}

	dependencies := []WaveDependency{{Child: 2, Parents: []int64{1}}}
	normalized, err := normalizeParallelWaveAdmissionWorkersWithDependencies(workers, dependencies)
	if err != nil {
		t.Fatalf("expected parent-child overlap to be allowed: %v", err)
	}
	if len(normalized) != len(workers) || normalized[0].DeclaredWriteScope[0] != "docs" || normalized[1].DeclaredWriteScope[0] != "docs/generated" {
		t.Fatalf("unexpected normalized workers: %+v", normalized)
	}

	transitiveWorkers := []parallelWaveAdmissionWorker{
		{SessionID: 1, DeclaredWriteScope: []string{"docs"}},
		{SessionID: 3, DeclaredWriteScope: []string{"docs/generated"}},
	}
	transitiveDependencies := []WaveDependency{
		{Child: 2, Parents: []int64{1}},
		{Child: 3, Parents: []int64{2}},
	}
	if _, err := normalizeParallelWaveAdmissionWorkersWithDependencies(transitiveWorkers, transitiveDependencies); err != nil {
		t.Fatalf("expected transitive parent-child overlap to be allowed: %v", err)
	}
}

func TestGitMergeBranchCommand(t *testing.T) {
	spec, err := gitMergeBranchCommand("/tmp/child-worktree", "fixer/wave-54/session-1")
	if err != nil {
		t.Fatalf("gitMergeBranchCommand failed: %v", err)
	}
	if spec.Name != "git" || strings.Join(spec.Args, " ") != "-C /tmp/child-worktree merge --no-edit fixer/wave-54/session-1" {
		t.Fatalf("unexpected merge command: %+v", spec)
	}

	if _, err := gitMergeBranchCommand("/tmp/child-worktree", "main"); err == nil {
		t.Fatal("expected invalid parent branch name to be rejected")
	}
}

func TestVerifyParallelWaveGitBaseAllowsNestedGitRoot(t *testing.T) {
	projectCWD := t.TempDir()
	repoDir := filepath.Join(projectCWD, "rita_repo")
	setupCleanGitRepoAt(t, repoDir)

	expectedBaseSHA := runGitTestCommand(t, repoDir, "rev-parse", "--verify", "HEAD^{commit}")
	baseSHA, _, err := verifyParallelWaveGitBase(projectCWD, "HEAD")
	if err != nil {
		t.Fatalf("expected project cwd containing nested Git root to be accepted: %v", err)
	}
	if baseSHA != expectedBaseSHA {
		t.Fatalf("expected base SHA %q, got %q", expectedBaseSHA, baseSHA)
	}

	if _, err := os.Stat(filepath.Join(repoDir, ".git")); err != nil {
		t.Fatalf("expected nested Git repository to remain available: %v", err)
	}
}
