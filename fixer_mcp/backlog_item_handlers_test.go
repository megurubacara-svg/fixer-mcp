package main

import (
	"context"
	"testing"
)

func createBacklogItemTestTable(t *testing.T) {
	t.Helper()
	_, err := db.Exec(`
		CREATE TABLE backlog_item (
			id INTEGER PRIMARY KEY,
			project_id INTEGER,
			title TEXT,
			description TEXT,
			status TEXT DEFAULT 'open',
			priority TEXT,
			created_at TEXT DEFAULT CURRENT_TIMESTAMP,
			updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
			FOREIGN KEY(project_id) REFERENCES project(id)
		)`)
	if err != nil {
		t.Fatalf("create backlog_item table: %v", err)
	}
}

func TestBacklogItemHandlersCRUDForFixer(t *testing.T) {
	originalDB := db
	originalRole := authorizedRole
	originalProjectID := authorizedProjectId
	defer func() {
		db = originalDB
		authorizedRole = originalRole
		authorizedProjectId = originalProjectID
	}()

	testDB := setupGetProjectsTestDB(t)
	defer testDB.Close()
	db = testDB
	createBacklogItemTestTable(t)
	authorizedRole = "fixer"
	authorizedProjectId = 1

	_, added, err := AddBacklogItem(context.Background(), nil, AddBacklogItemInput{
		Title:       "Split backlog from execution",
		Description: "Track ideas before creating a session.",
		Priority:    "high",
	})
	if err != nil {
		t.Fatalf("add_backlog_item failed: %v", err)
	}
	if added.Id <= 0 || added.Item.Id != added.Id {
		t.Fatalf("expected returned backlog item ID, got %+v", added)
	}
	if added.Item.ProjectId != 1 || added.Item.Status != "open" || added.Item.Priority != "high" {
		t.Fatalf("unexpected added backlog item: %+v", added.Item)
	}

	_, listed, err := GetBacklogItems(context.Background(), nil, GetBacklogItemsInput{})
	if err != nil {
		t.Fatalf("get_backlog_items failed: %v", err)
	}
	if len(listed.Items) != 1 || listed.Items[0].Id != added.Id {
		t.Fatalf("unexpected backlog list: %+v", listed)
	}

	_, updated, err := UpdateBacklogItem(context.Background(), nil, UpdateBacklogItemInput{
		ItemId: added.Id,
		Title:  "Split backlog and execution",
		Status: "in_progress",
	})
	if err != nil {
		t.Fatalf("update_backlog_item failed: %v", err)
	}
	if updated.Item.Title != "Split backlog and execution" || updated.Item.Status != "in_progress" || updated.Item.Description == "" {
		t.Fatalf("unexpected updated backlog item: %+v", updated.Item)
	}

	_, filtered, err := GetBacklogItems(context.Background(), nil, GetBacklogItemsInput{Status: "in_progress"})
	if err != nil {
		t.Fatalf("filtered get_backlog_items failed: %v", err)
	}
	if len(filtered.Items) != 1 || filtered.Items[0].Id != added.Id {
		t.Fatalf("unexpected filtered backlog list: %+v", filtered)
	}

	if _, _, err := UpdateBacklogItem(context.Background(), nil, UpdateBacklogItemInput{
		ProjectId: 2,
		ItemId:    added.Id,
		Status:    "closed",
	}); err == nil {
		t.Fatal("expected fixer cross-project update to be rejected")
	}
}

func TestBacklogItemHandlersUseExplicitProjectForOverseer(t *testing.T) {
	originalDB := db
	originalRole := authorizedRole
	originalProjectID := authorizedProjectId
	defer func() {
		db = originalDB
		authorizedRole = originalRole
		authorizedProjectId = originalProjectID
	}()

	testDB := setupGetProjectsTestDB(t)
	defer testDB.Close()
	db = testDB
	createBacklogItemTestTable(t)
	authorizedRole = "overseer"
	authorizedProjectId = 0

	_, added, err := AddBacklogItem(context.Background(), nil, AddBacklogItemInput{
		ProjectId: 2,
		Title:     "Project Beta item",
	})
	if err != nil {
		t.Fatalf("overseer add_backlog_item failed: %v", err)
	}

	_, listed, err := GetBacklogItems(context.Background(), nil, GetBacklogItemsInput{ProjectId: 2})
	if err != nil {
		t.Fatalf("overseer get_backlog_items failed: %v", err)
	}
	if listed.ProjectId != 2 || len(listed.Items) != 1 || listed.Items[0].ProjectId != 2 {
		t.Fatalf("unexpected overseer backlog list: %+v", listed)
	}

	if _, _, err := GetBacklogItems(context.Background(), nil, GetBacklogItemsInput{}); err == nil {
		t.Fatal("expected overseer get_backlog_items to require project_id")
	}

	_, updated, err := UpdateBacklogItem(context.Background(), nil, UpdateBacklogItemInput{
		ProjectId: 2,
		ItemId:    added.Id,
		Priority:  "low",
	})
	if err != nil {
		t.Fatalf("overseer update_backlog_item failed: %v", err)
	}
	if updated.Item.Priority != "low" {
		t.Fatalf("expected priority update, got %+v", updated.Item)
	}
}

func TestBacklogItemHandlersRejectUnauthorizedRolesAndInvalidInput(t *testing.T) {
	originalDB := db
	originalRole := authorizedRole
	originalProjectID := authorizedProjectId
	defer func() {
		db = originalDB
		authorizedRole = originalRole
		authorizedProjectId = originalProjectID
	}()

	testDB := setupGetProjectsTestDB(t)
	defer testDB.Close()
	db = testDB
	createBacklogItemTestTable(t)
	authorizedRole = "netrunner"
	authorizedProjectId = 1

	if _, _, err := AddBacklogItem(context.Background(), nil, AddBacklogItemInput{Title: "not allowed"}); err == nil {
		t.Fatal("expected netrunner add_backlog_item to be rejected")
	}

	authorizedRole = "fixer"
	if _, _, err := AddBacklogItem(context.Background(), nil, AddBacklogItemInput{}); err == nil {
		t.Fatal("expected empty title to be rejected")
	}
	if _, _, err := UpdateBacklogItem(context.Background(), nil, UpdateBacklogItemInput{ItemId: 1}); err == nil {
		t.Fatal("expected update with no fields to be rejected")
	}
}

func TestBacklogItemToolsAreRegisteredForFixerAndOverseer(t *testing.T) {
	for _, role := range []string{"fixer", "overseer"} {
		toolSet := make(map[string]struct{})
		for _, name := range registeredToolNamesForMode(role) {
			toolSet[name] = struct{}{}
		}
		for _, name := range []string{"add_backlog_item", "get_backlog_items", "update_backlog_item"} {
			if _, ok := toolSet[name]; !ok {
				t.Fatalf("expected %s in %s tool surface", name, role)
			}
		}
	}

	netrunnerTools := make(map[string]struct{})
	for _, name := range registeredToolNamesForMode("netrunner") {
		netrunnerTools[name] = struct{}{}
	}
	for _, name := range []string{"add_backlog_item", "get_backlog_items", "update_backlog_item"} {
		if _, ok := netrunnerTools[name]; ok {
			t.Fatalf("did not expect %s in netrunner tool surface", name)
		}
	}
}
