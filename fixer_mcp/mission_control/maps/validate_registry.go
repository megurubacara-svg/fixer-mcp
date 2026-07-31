package main

import (
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"strings"

	"github.com/google/jsonschema-go/jsonschema"
)

type registryRefs struct {
	ArchitectGates []struct {
		ID string `json:"id"`
	} `json:"architect_gates"`
	Features []struct {
		ID               string   `json:"id"`
		Dependencies     []string `json:"dependencies"`
		ArchitectGateIDs []string `json:"architect_gate_ids"`
	} `json:"features"`
}

func mustRead(path string) []byte {
	data, err := os.ReadFile(path)
	if err != nil {
		panic(err)
	}
	return data
}

func main() {
	schemaData := mustRead("mission_control/feature_registry.schema.json")
	registryData := mustRead("mission_control/feature_registry.json")
	var schema jsonschema.Schema
	if err := json.Unmarshal(schemaData, &schema); err != nil {
		panic(err)
	}
	var registry any
	if err := json.Unmarshal(registryData, &registry); err != nil {
		panic(err)
	}
	resolved, err := schema.Resolve(nil)
	if err != nil {
		panic(err)
	}
	if err := resolved.Validate(registry); err != nil {
		panic(err)
	}

	var refs registryRefs
	if err := json.Unmarshal(registryData, &refs); err != nil {
		panic(err)
	}
	known := make(map[string]bool)
	for _, gate := range refs.ArchitectGates {
		if known[gate.ID] {
			panic("duplicate ID: " + gate.ID)
		}
		known[gate.ID] = true
	}
	for _, feature := range refs.Features {
		if known[feature.ID] {
			panic("duplicate ID: " + feature.ID)
		}
		known[feature.ID] = true
	}
	for _, feature := range refs.Features {
		for _, dependency := range feature.Dependencies {
			if !known[dependency] {
				panic(feature.ID + " has unknown dependency " + dependency)
			}
		}
		for _, gate := range feature.ArchitectGateIDs {
			if !known[gate] {
				panic(feature.ID + " has unknown Architect gate " + gate)
			}
		}
	}

	dependencyMap := string(mustRead("mission_control/maps/r1_dependency_graph.mmd"))
	criticalPath := string(mustRead("mission_control/maps/r1_release_critical_path.mmd"))
	for _, source := range []struct {
		name string
		body string
	}{{"dependency graph", dependencyMap}, {"critical path", criticalPath}} {
		if !strings.HasPrefix(source.body, "flowchart ") {
			panic(source.name + " does not start with a Mermaid flowchart declaration")
		}
	}
	for id := range known {
		if !strings.Contains(dependencyMap, id) {
			panic("dependency graph is missing registry ID " + id)
		}
	}
	for _, id := range regexp.MustCompile(`(?:R1|ARCH)-[A-Z0-9-]+-[0-9]{3}`).FindAllString(criticalPath, -1) {
		if !known[id] {
			panic("critical path contains unknown registry ID " + id)
		}
	}
	fmt.Printf("validated schema, %d features, references, and Mermaid ID coverage\n", len(refs.Features))
}
