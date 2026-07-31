package main

import (
	"database/sql"
	"fmt"
	"strings"
)

type parallelWaveScopeLease struct {
	WaveID    int
	ScopePath string
}

func activeParallelWaveScopeLeasesTx(tx *sql.Tx, projectID int) ([]parallelWaveScopeLease, error) {
	rows, err := tx.Query(
		`SELECT wave_id, scope_path
		 FROM parallel_wave_scope_lease
		 WHERE project_id = ? AND active = 1
		 ORDER BY wave_id, scope_path`,
		projectID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	leases := []parallelWaveScopeLease{}
	for rows.Next() {
		var lease parallelWaveScopeLease
		if err := rows.Scan(&lease.WaveID, &lease.ScopePath); err != nil {
			return nil, err
		}
		leases = append(leases, lease)
	}
	return leases, rows.Err()
}

func validateParallelWaveAdmissionLeasesTx(tx *sql.Tx, projectID int, candidates []parallelWaveSessionCandidate) error {
	for _, candidate := range candidates {
		var linkage string
		if err := tx.QueryRow(
			`SELECT COALESCE(parallel_wave_id, '')
			 FROM session
			 WHERE id = ? AND project_id = ?`,
			candidate.GlobalSessionID,
			projectID,
		).Scan(&linkage); err != nil {
			return err
		}
		if strings.TrimSpace(linkage) != "" {
			return fmt.Errorf("session %d is already linked to wave marker %q", candidate.LocalSessionID, linkage)
		}
	}

	leases, err := activeParallelWaveScopeLeasesTx(tx, projectID)
	if err != nil {
		return err
	}
	for _, candidate := range candidates {
		for _, requestedScope := range candidate.DeclaredWriteScope {
			for _, lease := range leases {
				if writeScopePathsOverlap(requestedScope, lease.ScopePath) {
					return fmt.Errorf(
						"session %d scope %q overlaps active wave %d scope lease %q",
						candidate.LocalSessionID,
						requestedScope,
						lease.WaveID,
						lease.ScopePath,
					)
				}
			}
		}
	}
	return nil
}

func insertParallelWaveScopeLeasesTx(tx *sql.Tx, projectID int, waveID int, candidates []parallelWaveSessionCandidate) error {
	seen := map[string]struct{}{}
	for _, candidate := range candidates {
		for _, scopePath := range candidate.DeclaredWriteScope {
			if _, exists := seen[scopePath]; exists {
				continue
			}
			seen[scopePath] = struct{}{}
			if _, err := tx.Exec(
				`INSERT INTO parallel_wave_scope_lease (project_id, wave_id, scope_path, active)
				 VALUES (?, ?, ?, 1)`,
				projectID,
				waveID,
				scopePath,
			); err != nil {
				return err
			}
		}
	}
	return nil
}

func releaseParallelWaveScopeLeases(waveID int, projectID int) error {
	_, err := db.Exec(
		`UPDATE parallel_wave_scope_lease
		 SET active = 0,
		     released_at = COALESCE(released_at, CURRENT_TIMESTAMP)
		 WHERE wave_id = ? AND project_id = ? AND active = 1`,
		waveID,
		projectID,
	)
	return err
}
