package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func setupContextPackageTestDB(t *testing.T) *sql.DB {
	t.Helper()

	testDB, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open db: %v", err)
	}
	testDB.SetMaxOpenConns(1)
	testDB.SetMaxIdleConns(1)

	_, err = testDB.Exec(`
		CREATE TABLE project (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			name TEXT NOT NULL,
			cwd TEXT UNIQUE NOT NULL,
			active INTEGER NOT NULL DEFAULT 0
		);
		CREATE TABLE session (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			project_id INTEGER,
			task_description TEXT NOT NULL,
			status TEXT NOT NULL,
			report TEXT
		);
		CREATE TABLE project_doc (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			project_id INTEGER,
			title TEXT NOT NULL,
			content TEXT NOT NULL,
			doc_type TEXT DEFAULT 'documentation',
			parent_doc_id INTEGER,
			level INTEGER NOT NULL DEFAULT 0,
			slug TEXT NOT NULL DEFAULT '',
			path TEXT NOT NULL DEFAULT '',
			status TEXT NOT NULL DEFAULT 'current'
		);
		CREATE TABLE project_handoff (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			project_id INTEGER NOT NULL,
			content TEXT NOT NULL,
			updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
			UNIQUE(project_id)
		);
		CREATE TABLE project_overview (
			id INTEGER PRIMARY KEY AUTOINCREMENT,
			project_id INTEGER NOT NULL,
			content TEXT NOT NULL,
			updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
			UNIQUE(project_id)
		);
		CREATE TABLE backlog_item (
			id INTEGER PRIMARY KEY,
			project_id INTEGER,
			title TEXT,
			description TEXT,
			status TEXT DEFAULT 'open',
			priority TEXT,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP
		);
	`)
	if err != nil {
		t.Fatalf("create schema: %v", err)
	}

	sourceCWD := t.TempDir()
	targetCWD := t.TempDir()
	if _, err := testDB.Exec(
		"INSERT INTO project (id, name, cwd, active) VALUES (1, 'Source Project', ?, 1), (2, 'Target Project', ?, 0)",
		sourceCWD,
		targetCWD,
	); err != nil {
		t.Fatalf("seed projects: %v", err)
	}

	return testDB
}

// seedContextPackageSourceProject fills project 1 with an overview, a handoff,
// a small 0..2 doc tree, backlog items, and sessions.
func seedContextPackageSourceProject(t *testing.T, testDB *sql.DB) {
	t.Helper()

	if _, err := testDB.Exec("INSERT INTO project_overview (project_id, content) VALUES (1, 'Source overview content')"); err != nil {
		t.Fatalf("seed overview: %v", err)
	}
	if _, err := testDB.Exec("INSERT INTO project_handoff (project_id, content) VALUES (1, 'Source handoff content')"); err != nil {
		t.Fatalf("seed handoff: %v", err)
	}

	docs := []struct {
		id       int
		title    string
		content  string
		docType  string
		parentID any
		level    int
		slug     string
		path     string
		status   string
	}{
		{10, "Root Doc", "Root content", "architecture", nil, 0, "root-doc", "root-doc", "current"},
		{11, "Child Doc", "Child content", "contract", 10, 1, "child-doc", "root-doc/child-doc", "current"},
		{12, "Grandchild Doc", "Grandchild content", "documentation", 11, 2, "grandchild-doc", "root-doc/child-doc/grandchild-doc", "draft"},
	}
	for _, d := range docs {
		if _, err := testDB.Exec(
			"INSERT INTO project_doc (id, project_id, title, content, doc_type, parent_doc_id, level, slug, path, status) VALUES (?, 1, ?, ?, ?, ?, ?, ?, ?, ?)",
			d.id, d.title, d.content, d.docType, d.parentID, d.level, d.slug, d.path, d.status,
		); err != nil {
			t.Fatalf("seed doc %s: %v", d.slug, err)
		}
	}

	if _, err := testDB.Exec(
		"INSERT INTO backlog_item (project_id, title, description, status, priority) VALUES (1, 'Migrate context', 'Long description', 'open', 'high'), (1, 'Second idea', '', 'done', '')",
	); err != nil {
		t.Fatalf("seed backlog: %v", err)
	}

	longTask := strings.Repeat("x", contextPackageSessionExcerptLen+50)
	if _, err := testDB.Exec(
		"INSERT INTO session (project_id, task_description, status) VALUES (1, ?, 'completed'), (1, 'short task', 'pending')",
		longTask,
	); err != nil {
		t.Fatalf("seed sessions: %v", err)
	}
}

func withContextPackageTestAuth(t *testing.T, testDB *sql.DB, role string, projectID int) {
	t.Helper()
	originalDB := db
	originalRole := authorizedRole
	originalProjectID := authorizedProjectId
	t.Cleanup(func() {
		db = originalDB
		authorizedRole = originalRole
		authorizedProjectId = originalProjectID
	})
	db = testDB
	authorizedRole = role
	authorizedProjectId = projectID
}

func exportSourcePackage(t *testing.T, testDB *sql.DB) (string, ProjectContextPackage) {
	t.Helper()
	pkgPath := filepath.Join(t.TempDir(), "pkg.json")
	_, out, err := ExportProjectContextPackage(context.Background(), nil, ExportProjectContextPackageInput{Path: pkgPath})
	if err != nil {
		t.Fatalf("export_project_context_package failed: %v", err)
	}
	if out.Status != "success" {
		t.Fatalf("unexpected export status %q", out.Status)
	}
	data, err := os.ReadFile(pkgPath)
	if err != nil {
		t.Fatalf("read exported package: %v", err)
	}
	var pkg ProjectContextPackage
	if err := json.Unmarshal(data, &pkg); err != nil {
		t.Fatalf("parse exported package: %v", err)
	}
	return pkgPath, pkg
}

func TestExportProjectContextPackage(t *testing.T) {
	testDB := setupContextPackageTestDB(t)
	defer func() { _ = testDB.Close() }()
	seedContextPackageSourceProject(t, testDB)
	withContextPackageTestAuth(t, testDB, "fixer", 1)

	pkgPath, pkg := exportSourcePackage(t, testDB)

	if pkg.Manifest.SchemaVersion != contextPackageSchemaVersion {
		t.Fatalf("unexpected schema version %d", pkg.Manifest.SchemaVersion)
	}
	if pkg.Manifest.ProjectName != "Source Project" {
		t.Fatalf("unexpected project name %q", pkg.Manifest.ProjectName)
	}
	if pkg.Manifest.ProjectRoot == "" || pkg.Manifest.ExportedAt == "" {
		t.Fatalf("manifest missing root/exported_at: %+v", pkg.Manifest)
	}
	if pkg.Overview != "Source overview content" || pkg.Handoff != "Source handoff content" {
		t.Fatalf("overview/handoff not exported: %+v", pkg)
	}
	if len(pkg.Docs) != 3 {
		t.Fatalf("expected 3 docs, got %d", len(pkg.Docs))
	}

	bySlug := map[string]ContextPackageDoc{}
	for _, d := range pkg.Docs {
		bySlug[d.Slug] = d
	}
	child := bySlug["child-doc"]
	if child.ParentSlug != "root-doc" || child.ParentPath != "root-doc" {
		t.Fatalf("child parent linkage wrong: %+v", child)
	}
	grandchild := bySlug["grandchild-doc"]
	if grandchild.ParentSlug != "child-doc" || grandchild.ParentPath != "root-doc/child-doc" {
		t.Fatalf("grandchild parent linkage wrong: %+v", grandchild)
	}
	if grandchild.Level != 2 || grandchild.Status != "draft" || grandchild.DocType != "documentation" {
		t.Fatalf("grandchild metadata wrong: %+v", grandchild)
	}

	if len(pkg.Backlog) != 2 || pkg.Backlog[0].Title != "Migrate context" || pkg.Backlog[0].Priority != "high" {
		t.Fatalf("backlog export wrong: %+v", pkg.Backlog)
	}
	if len(pkg.Sessions) != 2 {
		t.Fatalf("expected 2 sessions, got %d", len(pkg.Sessions))
	}
	if pkg.Sessions[0].SessionId != 1 || pkg.Sessions[0].Status != "completed" {
		t.Fatalf("session index wrong: %+v", pkg.Sessions[0])
	}
	if len(pkg.Sessions[0].TaskExcerpt) != contextPackageSessionExcerptLen {
		t.Fatalf("task excerpt not truncated to %d: got %d", contextPackageSessionExcerptLen, len(pkg.Sessions[0].TaskExcerpt))
	}

	// Default path export lands under <project cwd>/artifacts/context_packages.
	_, defaultOut, err := ExportProjectContextPackage(context.Background(), nil, ExportProjectContextPackageInput{})
	if err != nil {
		t.Fatalf("default-path export failed: %v", err)
	}
	if !strings.Contains(defaultOut.Path, filepath.Join("artifacts", "context_packages")) || !strings.HasPrefix(defaultOut.Path, pkg.Manifest.ProjectRoot) {
		t.Fatalf("default export path %q not under project artifacts/context_packages", defaultOut.Path)
	}
	if !strings.HasPrefix(filepath.Base(defaultOut.Path), "source-project-") {
		t.Fatalf("default export filename %q lacks project slug", defaultOut.Path)
	}
	if _, err := os.Stat(defaultOut.Path); err != nil {
		t.Fatalf("default export file missing: %v", err)
	}
	_ = pkgPath
}

func TestImportProjectContextPackageIntoEmptyProject(t *testing.T) {
	testDB := setupContextPackageTestDB(t)
	defer func() { _ = testDB.Close() }()
	seedContextPackageSourceProject(t, testDB)
	withContextPackageTestAuth(t, testDB, "fixer", 1)

	pkgPath, _ := exportSourcePackage(t, testDB)

	authorizedProjectId = 2
	_, out, err := ImportProjectContextPackage(context.Background(), nil, ImportProjectContextPackageInput{Path: pkgPath})
	if err != nil {
		t.Fatalf("import_project_context_package failed: %v", err)
	}
	if out.DocsCreated != 3 || out.BacklogInserted != 2 || out.BacklogSkipped != 0 {
		t.Fatalf("unexpected import counts: %+v", out)
	}
	if !out.OverviewSet || !out.HandoffSet {
		t.Fatalf("overview/handoff not set: %+v", out)
	}
	if out.SessionsInPackage != 2 {
		t.Fatalf("sessions_in_package wrong: %+v", out)
	}

	var overview, handoff string
	if err := testDB.QueryRow("SELECT content FROM project_overview WHERE project_id = 2").Scan(&overview); err != nil {
		t.Fatalf("read imported overview: %v", err)
	}
	if err := testDB.QueryRow("SELECT content FROM project_handoff WHERE project_id = 2").Scan(&handoff); err != nil {
		t.Fatalf("read imported handoff: %v", err)
	}
	if overview != "Source overview content" || handoff != "Source handoff content" {
		t.Fatalf("imported overview/handoff wrong: %q / %q", overview, handoff)
	}

	// Verify the recreated doc tree preserves levels and parent linkage via
	// the new machine-local global ids.
	type docRow struct {
		id       int
		parentID sql.NullInt64
		level    int
		slug     string
		path     string
		status   string
		docType  string
	}
	rows, err := testDB.Query("SELECT id, parent_doc_id, level, slug, path, status, doc_type FROM project_doc WHERE project_id = 2 ORDER BY id")
	if err != nil {
		t.Fatalf("query imported docs: %v", err)
	}
	defer rows.Close()
	imported := map[string]docRow{}
	for rows.Next() {
		var r docRow
		if err := rows.Scan(&r.id, &r.parentID, &r.level, &r.slug, &r.path, &r.status, &r.docType); err != nil {
			t.Fatalf("scan imported doc: %v", err)
		}
		imported[r.slug] = r
	}
	if len(imported) != 3 {
		t.Fatalf("expected 3 imported docs, got %d", len(imported))
	}
	root := imported["root-doc"]
	child := imported["child-doc"]
	grandchild := imported["grandchild-doc"]
	if root.parentID.Valid {
		t.Fatalf("root doc must have no parent: %+v", root)
	}
	if !child.parentID.Valid || int(child.parentID.Int64) != root.id || child.level != 1 {
		t.Fatalf("child linkage wrong: %+v (root id %d)", child, root.id)
	}
	if !grandchild.parentID.Valid || int(grandchild.parentID.Int64) != child.id || grandchild.level != 2 {
		t.Fatalf("grandchild linkage wrong: %+v (child id %d)", grandchild, child.id)
	}
	if grandchild.status != "draft" || grandchild.docType != "documentation" || grandchild.path != "root-doc/child-doc/grandchild-doc" {
		t.Fatalf("grandchild metadata wrong: %+v", grandchild)
	}

	var backlogCount int
	if err := testDB.QueryRow("SELECT COUNT(*) FROM backlog_item WHERE project_id = 2").Scan(&backlogCount); err != nil {
		t.Fatalf("count imported backlog: %v", err)
	}
	if backlogCount != 2 {
		t.Fatalf("expected 2 backlog items, got %d", backlogCount)
	}
}

func TestImportProjectContextPackageRefusedWithoutForce(t *testing.T) {
	testDB := setupContextPackageTestDB(t)
	defer func() { _ = testDB.Close() }()
	seedContextPackageSourceProject(t, testDB)
	withContextPackageTestAuth(t, testDB, "fixer", 1)

	pkgPath, _ := exportSourcePackage(t, testDB)

	// Importing back into the non-empty source project must be refused.
	callResult, _, err := ImportProjectContextPackage(context.Background(), nil, ImportProjectContextPackageInput{Path: pkgPath})
	if err == nil {
		t.Fatalf("expected refusal for non-empty project without force")
	}
	if callResult == nil || !callResult.IsError {
		t.Fatalf("expected IsError call result")
	}
	if !strings.Contains(err.Error(), "force") {
		t.Fatalf("refusal error must mention force: %v", err)
	}
}

func TestImportProjectContextPackageForceDedupesBacklog(t *testing.T) {
	testDB := setupContextPackageTestDB(t)
	defer func() { _ = testDB.Close() }()
	seedContextPackageSourceProject(t, testDB)
	withContextPackageTestAuth(t, testDB, "fixer", 1)

	pkgPath, _ := exportSourcePackage(t, testDB)

	// Target project already has a handoff and one backlog item with the same title.
	if _, err := testDB.Exec("INSERT INTO project_handoff (project_id, content) VALUES (2, 'Existing handoff')"); err != nil {
		t.Fatalf("seed target handoff: %v", err)
	}
	if _, err := testDB.Exec("INSERT INTO backlog_item (project_id, title, description, status, priority) VALUES (2, 'Migrate context', 'old', 'open', 'low')"); err != nil {
		t.Fatalf("seed target backlog: %v", err)
	}

	authorizedProjectId = 2
	callResult, _, err := ImportProjectContextPackage(context.Background(), nil, ImportProjectContextPackageInput{Path: pkgPath})
	if err == nil || callResult == nil || !callResult.IsError {
		t.Fatalf("expected refusal without force, got err=%v", err)
	}

	_, out, err := ImportProjectContextPackage(context.Background(), nil, ImportProjectContextPackageInput{Path: pkgPath, Force: true})
	if err != nil {
		t.Fatalf("forced import failed: %v", err)
	}
	if out.BacklogInserted != 1 || out.BacklogSkipped != 1 {
		t.Fatalf("backlog dedupe wrong: %+v", out)
	}

	var handoff string
	if err := testDB.QueryRow("SELECT content FROM project_handoff WHERE project_id = 2").Scan(&handoff); err != nil {
		t.Fatalf("read handoff: %v", err)
	}
	if handoff != "Source handoff content" {
		t.Fatalf("forced import must replace handoff, got %q", handoff)
	}

	var dupes int
	if err := testDB.QueryRow("SELECT COUNT(*) FROM backlog_item WHERE project_id = 2 AND title = 'Migrate context'").Scan(&dupes); err != nil {
		t.Fatalf("count backlog dupes: %v", err)
	}
	if dupes != 1 {
		t.Fatalf("expected deduped backlog title, got %d rows", dupes)
	}

	// Re-import stays idempotent for backlog.
	_, out2, err := ImportProjectContextPackage(context.Background(), nil, ImportProjectContextPackageInput{Path: pkgPath, Force: true})
	if err != nil {
		t.Fatalf("re-import failed: %v", err)
	}
	if out2.BacklogInserted != 0 || out2.BacklogSkipped != 2 {
		t.Fatalf("re-import dedupe wrong: %+v", out2)
	}
}

func TestImportProjectContextPackageRejectsBadPackage(t *testing.T) {
	testDB := setupContextPackageTestDB(t)
	defer func() { _ = testDB.Close() }()
	withContextPackageTestAuth(t, testDB, "fixer", 2)

	badVersion := filepath.Join(t.TempDir(), "bad.json")
	if err := os.WriteFile(badVersion, []byte(`{"manifest":{"schema_version":99,"exported_at":"x","project_name":"x","project_root":"x"},"docs":[]}`), 0o644); err != nil {
		t.Fatalf("write bad package: %v", err)
	}
	if _, _, err := ImportProjectContextPackage(context.Background(), nil, ImportProjectContextPackageInput{Path: badVersion}); err == nil || !strings.Contains(err.Error(), "schema_version") {
		t.Fatalf("expected schema_version refusal, got %v", err)
	}

	badParent := filepath.Join(t.TempDir(), "badparent.json")
	content := fmt.Sprintf(`{"manifest":{"schema_version":%d,"exported_at":"x","project_name":"x","project_root":"x"},"docs":[{"title":"orphan","content":"c","doc_type":"documentation","level":1,"slug":"orphan","path":"root/orphan","status":"current","parent_slug":"missing"}]}`, contextPackageSchemaVersion)
	if err := os.WriteFile(badParent, []byte(content), 0o644); err != nil {
		t.Fatalf("write bad parent package: %v", err)
	}
	if _, _, err := ImportProjectContextPackage(context.Background(), nil, ImportProjectContextPackageInput{Path: badParent}); err == nil || !strings.Contains(err.Error(), "unknown parent") {
		t.Fatalf("expected unknown parent refusal, got %v", err)
	}
}

func TestContextPackageToolsRequireFixerOrOverseer(t *testing.T) {
	testDB := setupContextPackageTestDB(t)
	defer func() { _ = testDB.Close() }()
	seedContextPackageSourceProject(t, testDB)
	withContextPackageTestAuth(t, testDB, "netrunner", 1)

	callResult, _, err := ExportProjectContextPackage(context.Background(), nil, ExportProjectContextPackageInput{})
	if err == nil || callResult == nil || !callResult.IsError {
		t.Fatalf("expected netrunner export denial")
	}
	if !strings.Contains(err.Error(), "requires fixer or overseer role") {
		t.Fatalf("unexpected denial error: %v", err)
	}

	callResult, _, err = ImportProjectContextPackage(context.Background(), nil, ImportProjectContextPackageInput{Path: "whatever.json"})
	if err == nil || callResult == nil || !callResult.IsError {
		t.Fatalf("expected netrunner import denial")
	}
	if !strings.Contains(err.Error(), "requires fixer or overseer role") {
		t.Fatalf("unexpected denial error: %v", err)
	}
}
