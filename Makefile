SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

PYTHON ?= python3

.PHONY: install install-verify test-client-wires test-go smoke docker-smoke docker-bootstrap-e2e

install:
	bash scripts/install.sh

install-verify:
	bash scripts/install.sh --verify

test-client-wires:
	$(PYTHON) -m unittest discover -s client_wires/tests

test-go:
	cd fixer_mcp && go build ./... && env -u FIXER_MCP_LOCKED_ROLE go test ./...

smoke:
	bash scripts/verify-install.sh

docker-smoke:
	bash docker/fixer-smoke.sh

docker-bootstrap-e2e:
	bash docker/fixer-bootstrap-e2e.sh
