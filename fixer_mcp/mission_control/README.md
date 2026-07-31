# Fixer R1 Mission Control registry

This directory is the static product contract for Mission Control. It gives each
R1 feature a stable ID and records product decisions, evidence, acceptance,
dependencies, durable runtime references, and Architect gates.

It is deliberately **not** a runtime-status database. `feature_registry.json`
contains evidence-backed portfolio states such as `planned`, `active`, or
`verified`, but it never stores a completion percentage or copies live worker
state. Mission Control must join each `feature.id` to Fixer MCP runtime entities
and derive current tasks, waves, workers, screenshots, acceptance, deployments,
and open gates at read time.

## Files

- `feature_registry.json`: reviewed R1 static metadata and durable references.
- `feature_registry.schema.json`: JSON Schema Draft 2020-12 contract.
- `maps/r1_dependency_graph.mmd`: complete feature dependency graph.
- `maps/r1_release_critical_path.mmd`: release-critical path and explicit
  Architect stops.

The registry's `status` is a coarse evidence classification, not an execution
status. `maturity` describes release honesty independently: every surface must
remain labelled `stable`, `alpha`, or `experimental` even when its delivery
status changes.

## Validation

Parse the files, resolve and validate the Draft 2020-12 schema, check dependency
and Architect-gate references, and verify Mermaid ID coverage with the existing
Go module dependency:

```sh
cd fixer_mcp
go run ./mission_control/maps/validate_registry.go
```

Check cross-references and the invariant that no runtime percentage is stored:

```sh
jq -e '
  ([.features[].id] | length == (unique | length)) and
  ([.architect_gates[].id] | length == (unique | length)) and
  ([.features[].dependencies[]] - [.features[].id] | length == 0) and
  ([.features[].architect_gate_ids[]] - [.architect_gates[].id] | length == 0) and
  ([paths | last | tostring | select(test("(^|_)(completion_)?percent(age)?$"; "i"))] | length == 0)
' fixer_mcp/mission_control/feature_registry.json
```

## Mermaid review artifacts

No repository-pinned or installed Mermaid renderer was present when the registry
was created, so generated SVG/PNG files are intentionally not committed. The
sources use Mermaid `flowchart` syntax and keep the exact registry feature IDs in
every visible node label.

Render deterministically with the pinned CLI version from the repository root:

```sh
npx -y @mermaid-js/mermaid-cli@11.9.0 -i fixer_mcp/mission_control/maps/r1_dependency_graph.mmd -o fixer_mcp/mission_control/maps/r1_dependency_graph.svg
npx -y @mermaid-js/mermaid-cli@11.9.0 -i fixer_mcp/mission_control/maps/r1_release_critical_path.mmd -o fixer_mcp/mission_control/maps/r1_release_critical_path.svg
```

For PNG review output, repeat either command with an `.png` output path.
