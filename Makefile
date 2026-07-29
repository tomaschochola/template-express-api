# Makefile

SHELL := /usr/bin/env bash

GNUMAKEFLAGS ?=

MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

.SHELLFLAGS := -Eeuo pipefail -c

.DELETE_ON_ERROR:
.SUFFIXES:
.NOTPARALLEL:

DEVCONTAINER_PROJECT := template-express-api-devcontainer
DEVCONTAINER_FILTER := label=com.docker.compose.project=$(DEVCONTAINER_PROJECT)

# Default goal

.DEFAULT_GOAL := never

.PHONY: never
.SILENT: never
never:
	printf '%s\n' 'No default target. Run an explicit target' >&2
	exit 1

# Goals

.PHONY: all
all: build

.PHONY: fix
fix: eslint_fix prettier_fix

.PHONY: check
check: lint static audit

.PHONY: lint
lint: eslint_check prettier_check

.PHONY: static
static: typescript_check

.PHONY: audit
audit: npm_audit

.PHONY: deps_install
deps_install: npm_install

.PHONY: deps_update
deps_update: npm_update

.PHONY: clean
clean:
	rm -rf ./dist

.PHONY: deps_clean
deps_clean:
	rm -rf ./node_modules

.PHONY: distclean
distclean: clean deps_clean

.PHONY: nuke
nuke: distclean data_reset

.PHONY: eslint_fix
eslint_fix: ./node_modules ./package.json ./package-lock.json ./eslint.config.js
	npm exec --ignore-scripts -- eslint --concurrency=auto --fix .

.PHONY: prettier_fix
prettier_fix: ./node_modules ./package.json ./package-lock.json ./prettier.config.js
	npm exec --ignore-scripts -- prettier -w .

.PHONY: eslint_check
eslint_check: ./node_modules ./package.json ./package-lock.json ./eslint.config.js
	npm exec --ignore-scripts -- eslint --concurrency=auto .

.PHONY: prettier_check
prettier_check: ./node_modules ./package.json ./package-lock.json ./prettier.config.js
	npm exec --ignore-scripts -- prettier -c .

.PHONY: typescript_check
typescript_check: ./node_modules ./package.json ./package-lock.json ./tsconfig.json
	npm exec --ignore-scripts -- tsc --noEmit --project ./tsconfig.json

.PHONY: npm_audit
npm_audit: ./node_modules ./package.json ./package-lock.json
	npm audit --ignore-scripts --audit-level=critical --install-links --include=prod --include=dev --include=peer --include=optional

.PHONY: npm_install
npm_install: ./package.json ./package-lock.json
	npm ci --ignore-scripts --install-links --include=prod --include=dev --include=peer --include=optional

.PHONY: npm_update
npm_update: ./package.json
	rm -rf ./node_modules
	npm update --ignore-scripts --install-links --include=prod --include=dev --include=peer --include=optional

.PHONY: precreate
precreate:
	docker volume create tomaschochola-npm-cache

.PHONY: postcreate
postcreate: deps_install

.PHONY: build
build: ./node_modules ./package.json ./package-lock.json ./tsconfig.json
	npm exec --ignore-scripts -- tsc --project ./tsconfig.json

.PHONY: start serve server dev
start serve server dev: build
	node ./dist/index.js

.PHONY: compose_push
compose_push:
	docker compose -f ./docker-compose.yml -f ./docker-compose-swarm.yml build --pull --push

.PHONY: swarm_deploy
swarm_deploy:
	docker stack deploy -c ./docker-compose.yml -c ./docker-compose-swarm.yml --with-registry-auth --prune --detach=false --resolve-image=always $${CI_PROJECT_PATH_SLUG:-template-express-api}

.PHONY: compose_up
compose_up:
	docker compose -f ./docker-compose.yml -f ./docker-compose-swarm.yml up --build --remove-orphans --always-recreate-deps --force-recreate --pull=always --renew-anon-volumes

.PHONY: compose_stop
compose_stop:
	docker compose -f ./docker-compose.yml -f ./docker-compose-swarm.yml stop

.PHONY: devcontainer
devcontainer:
	devcontainer up --workspace-folder .
	devcontainer exec --workspace-folder . /bin/bash

.PHONY: status
status:
	docker container ls --all --filter "$(DEVCONTAINER_FILTER)"
	docker volume ls --filter "$(DEVCONTAINER_FILTER)"
	docker network ls --filter "$(DEVCONTAINER_FILTER)"

.PHONY: stop
stop:
	docker container ls --quiet --filter "$(DEVCONTAINER_FILTER)" | while IFS= read -r container; do docker container stop "$$container"; done

.PHONY: restart
restart:
	docker container ls --all --quiet --filter "$(DEVCONTAINER_FILTER)" | while IFS= read -r container; do docker container restart "$$container"; done

.PHONY: down
down: stop
	docker container ls --all --quiet --filter "$(DEVCONTAINER_FILTER)" | while IFS= read -r container; do docker container rm --force --volumes "$$container"; done
	docker network ls --quiet --filter "$(DEVCONTAINER_FILTER)" | while IFS= read -r network; do docker network rm "$$network"; done

.PHONY: rebuild
rebuild: down
	devcontainer up --workspace-folder .

.PHONY: rebuild_no_cache
rebuild_no_cache: down
	devcontainer up --workspace-folder . --build-no-cache

.PHONY: data_reset
data_reset: down
	docker volume ls --quiet --filter "$(DEVCONTAINER_FILTER)" | while IFS= read -r volume; do docker volume rm "$$volume"; done

# Dependencies

./node_modules: ./package.json ./package-lock.json
	${MAKE} npm_install
