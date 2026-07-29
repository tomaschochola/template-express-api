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

# Default goal

.DEFAULT_GOAL := help

# Goals

.PHONY: help
.SILENT: help
help:
	printf '\033[1m%s\033[0m\n' "$${PWD##*/} targets"
	printf '%s\n' '--------------------------------------------------------------------------------'
	printf '\033[1m%-16s\033[0m  %s\n' 'help' 'Show this help.'
	printf '\033[1m%-16s\033[0m  %s\n' 'all' 'Build final project artifacts for release.'
	printf '\033[1m%-16s\033[0m  %s\n' 'fix' 'Run all automatic fixers.'
	printf '\033[1m%-16s\033[0m  %s\n' 'check' 'Run lint, static analysis, tests, and audits.'
	printf '\033[1m%-16s\033[0m  %s\n' 'lint' 'Run code style checks.'
	printf '\033[1m%-16s\033[0m  %s\n' 'static' 'Run static analysis.'
	printf '\033[1m%-16s\033[0m  %s\n' 'audit' 'Run dependency/security audits.'
	printf '\033[1m%-16s\033[0m  %s\n' 'deps_install' 'Install dependencies from current lock files.'
	printf '\033[1m%-16s\033[0m  %s\n' 'deps_update' 'Refresh dependencies and generated lock files.'
	printf '\033[1m%-16s\033[0m  %s\n' 'clean' 'Remove generated build, dependency, and test artifacts.'
	printf '\033[1m%-16s\033[0m  %s\n' 'distclean' 'Run clean and remove generated lock files.'
	printf '\033[1m%-16s\033[0m  %s\n' 'eslint_fix' 'Fix JavaScript/TypeScript lint issues with ESLint.'
	printf '\033[1m%-16s\033[0m  %s\n' 'prettier_fix' 'Format files with Prettier.'
	printf '\033[1m%-16s\033[0m  %s\n' 'eslint_check' 'Check JavaScript/TypeScript with ESLint.'
	printf '\033[1m%-16s\033[0m  %s\n' 'prettier_check' 'Check formatting with Prettier.'
	printf '\033[1m%-16s\033[0m  %s\n' 'typescript_check' 'Run TypeScript type checking.'
	printf '\033[1m%-16s\033[0m  %s\n' 'npm_audit' 'Run npm audit at the configured severity level.'
	printf '\033[1m%-16s\033[0m  %s\n' 'npm_install' 'Install npm dependencies from package-lock.json.'
	printf '\033[1m%-16s\033[0m  %s\n' 'npm_update' 'Refresh npm dependencies and package-lock.json.'
	printf '\033[1m%-16s\033[0m  %s\n' 'precreate' 'Run pre-devcontainer setup hooks.'
	printf '\033[1m%-16s\033[0m  %s\n' 'postcreate' 'Run post-devcontainer setup hooks.'
	printf '\033[1m%-16s\033[0m  %s\n' 'build' 'Build project artifacts.'
	printf '\033[1m%-16s\033[0m  %s\n' 'start' 'Start the local development server.'
	printf '\033[1m%-16s\033[0m  %s\n' 'serve' 'Alias for start.'
	printf '\033[1m%-16s\033[0m  %s\n' 'server' 'Alias for start.'
	printf '\033[1m%-16s\033[0m  %s\n' 'dev' 'Alias for start.'
	printf '\033[1m%-16s\033[0m  %s\n' 'compose_push' 'Build and push Docker Compose images.'
	printf '\033[1m%-16s\033[0m  %s\n' 'swarm_deploy' 'Deploy the stack to Docker Swarm.'
	printf '\033[1m%-16s\033[0m  %s\n' 'compose_up' 'Start the Docker Compose environment.'
	printf '\033[1m%-16s\033[0m  %s\n' 'compose_stop' 'Stop the Docker Compose environment.'
	printf '\033[1m%-16s\033[0m  %s\n' 'port' 'Print local service ports.'
	printf '\033[1m%-16s\033[0m  %s\n' 'ports' 'Alias for port.'
	printf '\033[1m%-16s\033[0m  %s\n' 'devcontainer' 'Open a devcontainer shell, then stop the container.'
	printf '\033[1m%-16s\033[0m  %s\n' 'tsc' 'Compile/check TypeScript with tsc.'

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
	rm -rf ./node_modules
	rm -rf ./dist

.PHONY: distclean
distclean: clean
	rm -rf ./package-lock.json

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
	npm exec --ignore-scripts -- tsc --noEmit

.PHONY: npm_audit
npm_audit: ./node_modules ./package.json ./package-lock.json
	npm audit --ignore-scripts --audit-level=critical --install-links --include=prod --include=dev --include=peer --include=optional

.PHONY: npm_install
npm_install: ./package.json ./package-lock.json
	npm install --ignore-scripts --install-links --include=prod --include=dev --include=peer --include=optional

.PHONY: npm_update
npm_update: ./package.json
	rm -rf ./node_modules
	rm -rf ./package-lock.json
	npm update --ignore-scripts --install-links --include=prod --include=dev --include=peer --include=optional

.PHONY: precreate
precreate:
	docker volume create tomaschochola-npm-cache

.PHONY: postcreate
postcreate: deps_install

.PHONY: build
build: tsc

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

.PHONY: port ports
.SILENT: port ports
port ports:
	printf '\033[1m%-80s\033[0m\n' 'template-express-api ports'
	printf '%-80s\n' '--------------------------------------------------------------------------------'
	printf '\033[1m%-12s %-21s %-12s %-20s\033[0m\n' 'Kind' 'Host' 'Container' 'Service'
	printf '%-12s %-21s %-12s %-20s\n' 'express' '-' '61400' 'server'
	printf '%-12s %-21s %-12s %-20s\n' 'express' '127.0.0.1:61400' '61400' 'devcontainer'
	printf '%-80s\n' '--------------------------------------------------------------------------------'
	printf '\n\033[1mLinks\033[0m\n'
	printf '%s\n' 'Express server: http://127.0.0.1:61400/'
	printf '%s\n' 'Express health: http://127.0.0.1:61400/healthz/live'

.PHONY: devcontainer
devcontainer: precreate
	devcontainer up --workspace-folder .
	devcontainer exec --workspace-folder . /bin/bash || true
	docker ps -q --filter "label=devcontainer.local_folder=$${PWD}" | xargs -r docker stop

.PHONY: tsc
tsc: ./node_modules ./package.json ./package-lock.json ./tsconfig.json
	npm exec --ignore-scripts -- tsc

# Dependencies

./package-lock.json ./node_modules &: ./package.json
	${MAKE} npm_update
