package dashboardapi

import (
	"context"
	"sort"
)

type projectRecord struct {
	ID   int
	Name string
	CWD  string
}

func (r *Repository) loadProjects(ctx context.Context) (map[int]projectRecord, []int, error) {
	rows, err := r.db.QueryContext(ctx, `SELECT id, name, cwd FROM project`)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	projectMap := map[int]projectRecord{}
	order := []int{}
	for rows.Next() {
		var project projectRecord
		if err := rows.Scan(&project.ID, &project.Name, &project.CWD); err != nil {
			return nil, nil, err
		}
		projectMap[project.ID] = project
		order = append(order, project.ID)
	}
	if err := rows.Err(); err != nil {
		return nil, nil, err
	}

	activity, err := r.loadProjectActivity(ctx)
	if err != nil {
		return nil, nil, err
	}
	sort.SliceStable(order, func(i, j int) bool {
		left := activity[order[i]].LastActivityAt
		right := activity[order[j]].LastActivityAt
		if left != right {
			// Empty timestamps sort after real activity. SQLite's timestamp
			// defaults are ISO-like, so lexical ordering is deterministic.
			if !hasProjectActivity(left) {
				return false
			}
			if !hasProjectActivity(right) {
				return true
			}
			return left > right
		}
		return order[i] < order[j]
	})
	return projectMap, order, nil
}

func (r *Repository) requireProject(ctx context.Context, projectID int) (projectRecord, error) {
	var project projectRecord
	err := r.db.QueryRowContext(ctx, `SELECT id, name, cwd FROM project WHERE id = ?`, projectID).Scan(&project.ID, &project.Name, &project.CWD)
	if err != nil {
		return projectRecord{}, err
	}
	return project, nil
}

func (r *Repository) currentProjectBinding(projects map[int]projectRecord) *ProjectBinding {
	for _, project := range projects {
		if project.CWD == r.currentProjectCWD && project.CWD != "" {
			return &ProjectBinding{ID: project.ID, Name: project.Name, CWD: project.CWD}
		}
	}
	return nil
}
