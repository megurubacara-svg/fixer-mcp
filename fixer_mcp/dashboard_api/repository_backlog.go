package dashboardapi

import "context"

// BacklogItemRecord is a structured backlog item. Unlike a project document,
// it represents work that can be promoted into an executable session.
type BacklogItemRecord struct {
	ID          int    `json:"id"`
	ProjectID   int    `json:"project_id"`
	Title       string `json:"title"`
	Description string `json:"description"`
	Status      string `json:"status"`
	Priority    string `json:"priority"`
	CreatedAt   string `json:"created_at"`
	UpdatedAt   string `json:"updated_at"`
}

// BacklogDocumentRecord is a canonical project document whose type is
// "backlog". It is intentionally separate from BacklogItemRecord: documents
// are durable project context, not executable backlog items.
type BacklogDocumentRecord struct {
	ID             int    `json:"id"`
	Title          string `json:"title"`
	DocType        string `json:"doc_type"`
	ContentPreview string `json:"content_preview"`
	ParentDocID    int    `json:"parent_doc_id,omitempty"`
	Level          int    `json:"level"`
	Slug           string `json:"slug"`
	Path           string `json:"path"`
	Status         string `json:"status"`
}

// ProjectBacklogResponse contains both sources shown by the project backlog
// panel. Keeping them in separate fields prevents a canonical backlog document
// from being mistaken for a structured item.
type ProjectBacklogResponse struct {
	Project   ProjectHeader           `json:"project"`
	Items     []BacklogItemRecord     `json:"items"`
	Documents []BacklogDocumentRecord `json:"documents"`
}

// ProjectBacklog loads the current project's structured backlog items and
// canonical backlog documents. Document IDs are project-scoped, matching the
// other dashboard document APIs.
func (r *Repository) ProjectBacklog(ctx context.Context, projectID int) (ProjectBacklogResponse, error) {
	project, err := r.requireProject(ctx, projectID)
	if err != nil {
		return ProjectBacklogResponse{}, err
	}

	items, err := r.loadBacklogItems(ctx, projectID)
	if err != nil {
		return ProjectBacklogResponse{}, err
	}
	documents, err := r.loadBacklogDocuments(ctx, projectID)
	if err != nil {
		return ProjectBacklogResponse{}, err
	}

	return ProjectBacklogResponse{
		Project:   ProjectHeader{ID: project.ID, Name: project.Name, CWD: project.CWD},
		Items:     items,
		Documents: documents,
	}, nil
}

func (r *Repository) loadBacklogItems(ctx context.Context, projectID int) ([]BacklogItemRecord, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT id,
		       project_id,
		       COALESCE(title, ''),
		       COALESCE(description, ''),
		       COALESCE(status, 'open'),
		       COALESCE(priority, ''),
		       COALESCE(created_at, ''),
		       COALESCE(updated_at, '')
		FROM backlog_item
		WHERE project_id = ?
		ORDER BY id`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	items := make([]BacklogItemRecord, 0)
	for rows.Next() {
		var item BacklogItemRecord
		if err := rows.Scan(
			&item.ID,
			&item.ProjectID,
			&item.Title,
			&item.Description,
			&item.Status,
			&item.Priority,
			&item.CreatedAt,
			&item.UpdatedAt,
		); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *Repository) loadBacklogDocuments(ctx context.Context, projectID int) ([]BacklogDocumentRecord, error) {
	rows, err := r.db.QueryContext(ctx, `
		SELECT
			(
				SELECT COUNT(*)
				FROM project_doc d2
				WHERE d2.project_id = d.project_id AND d2.id <= d.id
			) AS local_doc_id,
			COALESCE(d.title, ''),
			COALESCE(d.doc_type, 'documentation'),
			COALESCE(d.content, ''),
			COALESCE((
				SELECT COUNT(*)
				FROM project_doc parent_ranked
				WHERE parent_ranked.project_id = d.project_id AND parent_ranked.id <= d.parent_doc_id
			), 0),
			COALESCE(d.level, 0),
			COALESCE(d.slug, ''),
			COALESCE(d.path, ''),
			COALESCE(d.status, 'current')
		FROM project_doc d
		WHERE d.project_id = ? AND LOWER(COALESCE(d.doc_type, '')) = 'backlog'
		ORDER BY COALESCE(d.level, 0), COALESCE(d.path, ''), d.id`, projectID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	documents := make([]BacklogDocumentRecord, 0)
	for rows.Next() {
		var document BacklogDocumentRecord
		var content string
		if err := rows.Scan(
			&document.ID,
			&document.Title,
			&document.DocType,
			&content,
			&document.ParentDocID,
			&document.Level,
			&document.Slug,
			&document.Path,
			&document.Status,
		); err != nil {
			return nil, err
		}
		document.ContentPreview = summarizeContent(content)
		documents = append(documents, document)
	}
	return documents, rows.Err()
}
