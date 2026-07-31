package dashboardapi

import (
	"context"
	"database/sql"
	"testing"

	_ "github.com/glebarez/go-sqlite"
)

func TestProjectDocsTreeReturnsNestedCanonicalDocuments(t *testing.T) {
	db, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	defer db.Close()
	db.SetMaxOpenConns(1)

	_, err = db.Exec(`
		CREATE TABLE project (
			id INTEGER PRIMARY KEY,
			name TEXT NOT NULL,
			cwd TEXT NOT NULL
		);
		CREATE TABLE project_doc (
			id INTEGER PRIMARY KEY,
			project_id INTEGER NOT NULL,
			title TEXT NOT NULL,
			content TEXT NOT NULL,
			doc_type TEXT DEFAULT 'documentation',
			parent_doc_id INTEGER,
			level INTEGER NOT NULL DEFAULT 0,
			slug TEXT NOT NULL DEFAULT '',
			path TEXT NOT NULL DEFAULT '',
			status TEXT NOT NULL DEFAULT 'current'
		);
		INSERT INTO project (id, name, cwd) VALUES (1, 'Fixer MCP', '/workspace/fixer');
		INSERT INTO project_doc
			(id, project_id, title, content, doc_type, level, slug, path, status)
			VALUES (10, 1, 'Runtime', '# Runtime', 'architecture', 0, 'runtime', 'runtime', 'current');
		INSERT INTO project_doc
			(id, project_id, title, content, doc_type, parent_doc_id, level, slug, path, status)
			VALUES (20, 1, 'Launch', '# Launch

Details', 'contract', 10, 1, 'launch', 'runtime/launch', 'draft');
		INSERT INTO project_doc
			(id, project_id, title, content, doc_type, parent_doc_id, level, slug, path, status)
			VALUES (30, 1, 'Manual', 'Manual notes', 'documentation', 20, 2, 'manual', 'runtime/launch/manual', 'current');
	`)
	if err != nil {
		t.Fatalf("seed schema and docs: %v", err)
	}

	repo := &Repository{db: db, dbWrite: db}
	tree, err := repo.ProjectDocsTree(context.Background(), 1)
	if err != nil {
		t.Fatalf("ProjectDocsTree: %v", err)
	}
	if tree.TotalDocs != 3 || len(tree.Roots) != 1 {
		t.Fatalf("unexpected tree shape: %+v", tree)
	}
	root := tree.Roots[0]
	if root.ID != 1 || root.Title != "Runtime" || root.Level != 0 {
		t.Fatalf("unexpected root: %+v", root)
	}
	if len(root.Children) != 1 || root.Children[0].ParentDocID != root.ID {
		t.Fatalf("expected nested child relationship: %+v", root.Children)
	}
	if len(root.Children[0].Children) != 1 || root.Children[0].Children[0].Level != 2 {
		t.Fatalf("expected level-two grandchild: %+v", root.Children[0].Children)
	}
	if root.Children[0].ContentPreview != "# Launch Details" {
		t.Fatalf("unexpected content preview: %q", root.Children[0].ContentPreview)
	}

	detail, err := repo.ProjectDoc(context.Background(), 1, 2)
	if err != nil {
		t.Fatalf("ProjectDoc: %v", err)
	}
	if detail.Document.ID != 2 || detail.Document.Content != "# Launch\n\nDetails" {
		t.Fatalf("expected full selected document content, got %+v", detail.Document)
	}
}

func TestProjectDocRejectsInvalidProjectScopedID(t *testing.T) {
	db, err := sql.Open("sqlite", ":memory:")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	defer db.Close()
	db.SetMaxOpenConns(1)
	if _, err := db.Exec(`
		CREATE TABLE project (id INTEGER PRIMARY KEY, name TEXT NOT NULL, cwd TEXT NOT NULL);
		INSERT INTO project (id, name, cwd) VALUES (1, 'Fixer MCP', '/workspace/fixer');
	`); err != nil {
		t.Fatalf("seed project: %v", err)
	}

	repo := &Repository{db: db, dbWrite: db}
	if _, err := repo.ProjectDoc(context.Background(), 1, 0); err == nil {
		t.Fatal("expected invalid project document id error")
	}
}
