package dashboardapi

import (
	"context"
	"testing"
)

func TestProjectBacklogSeparatesStructuredItemsAndCanonicalDocuments(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()

	statements := []string{
		`CREATE TABLE backlog_item (
			id INTEGER PRIMARY KEY,
			project_id INTEGER,
			title TEXT,
			description TEXT,
			status TEXT DEFAULT 'open',
			priority TEXT,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP
		)`,
		`ALTER TABLE project_doc ADD COLUMN parent_doc_id INTEGER`,
		`ALTER TABLE project_doc ADD COLUMN level INTEGER NOT NULL DEFAULT 0`,
		`ALTER TABLE project_doc ADD COLUMN slug TEXT NOT NULL DEFAULT ''`,
		`ALTER TABLE project_doc ADD COLUMN path TEXT NOT NULL DEFAULT ''`,
		`ALTER TABLE project_doc ADD COLUMN status TEXT NOT NULL DEFAULT 'current'`,
		`INSERT INTO backlog_item (id, project_id, title, description, status, priority, created_at, updated_at)
		 VALUES (7, 1, 'Promote the backlog panel', 'Expose structured work in the dashboard.', 'open', 'high', '2026-07-01', '2026-07-02')`,
		`INSERT INTO backlog_item (id, project_id, title) VALUES (8, 2, 'Other project item')`,
		`INSERT INTO project_doc (id, project_id, title, content, doc_type, level, slug, path, status)
		 VALUES (3, 1, 'Backlog Canon', '# Current backlog\nCanonical notes.', 'backlog', 0, 'backlog', 'fixer-mcp/backlog', 'current')`,
		`INSERT INTO project_doc (id, project_id, title, content, doc_type, parent_doc_id, level, slug, path, status)
		 VALUES (4, 1, 'Backlog Detail', 'A detailed backlog section.', 'backlog', 3, 1, 'backlog-detail', 'fixer-mcp/backlog/detail', 'draft')`,
		`INSERT INTO project_doc (id, project_id, title, content, doc_type)
		 VALUES (5, 1, 'Architecture Notes', 'Not a backlog document.', 'architecture')`,
	}
	for _, statement := range statements {
		if _, err := repo.dbWrite.Exec(statement); err != nil {
			t.Fatalf("seed backlog fixture: %v\nstatement: %s", err, statement)
		}
	}

	backlog, err := repo.ProjectBacklog(context.Background(), 1)
	if err != nil {
		t.Fatalf("load project backlog: %v", err)
	}
	if backlog.Project.Name != "Fixer MCP" {
		t.Fatalf("unexpected project: %+v", backlog.Project)
	}
	if len(backlog.Items) != 1 || backlog.Items[0].ID != 7 {
		t.Fatalf("expected one project-scoped structured item, got %+v", backlog.Items)
	}
	if backlog.Items[0].Priority != "high" || backlog.Items[0].Description == "" {
		t.Fatalf("expected structured item fields, got %+v", backlog.Items[0])
	}
	if len(backlog.Documents) != 2 {
		t.Fatalf("expected two canonical backlog documents, got %+v", backlog.Documents)
	}
	if backlog.Documents[0].DocType != "backlog" || backlog.Documents[0].Level != 0 {
		t.Fatalf("unexpected root backlog document: %+v", backlog.Documents[0])
	}
	if backlog.Documents[1].ParentDocID != 3 || backlog.Documents[1].Level != 1 {
		t.Fatalf("expected project-scoped parent relationship, got %+v", backlog.Documents[1])
	}
	if backlog.Documents[1].ContentPreview == "" || backlog.Documents[1].Status != "draft" {
		t.Fatalf("expected document preview and status, got %+v", backlog.Documents[1])
	}
}

func TestProjectBacklogRequiresAnExistingProject(t *testing.T) {
	repo := openFixtureRepository(t)
	defer repo.Close()

	if _, err := repo.ProjectBacklog(context.Background(), 999); err == nil {
		t.Fatal("expected missing project to be rejected")
	}
}
