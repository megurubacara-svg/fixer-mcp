SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
PYTHON ?= python3
DOCKER_IMAGE ?= fixer-mcp-smoke:local
DOCKER_CONTAINER_PREFIX ?= fixer-mcp-smoke

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
	docker build -f "$(ROOT_DIR)/docker/fixer-smoke.Dockerfile" -t "$(DOCKER_IMAGE)" "$(ROOT_DIR)"
	docker run --rm --name "$(DOCKER_CONTAINER_PREFIX)-$$(date +%s)" "$(DOCKER_IMAGE)"

docker-bootstrap-e2e:
	bash docker/fixer-bootstrap-e2e.sh
