# Default shell
SHELL := /bin/bash

# Default goal
.DEFAULT_GOAL := never

# Options
export DEBIAN_FRONTEND := noninteractive
# Goals
.PHONY: commit
commit: distclean update fix check

.PHONY: fix
fix: eslint_fix prettier_fix yq_fix

.PHONY: check
check: lint stan test audit

.PHONY: lint
lint: eslint_check prettier_check

.PHONY: stan
stan: typescript_check

.PHONY: test
test:

.PHONY: audit
audit: npm_audit

.PHONY: install
install: npm_install

.PHONY: update
update: npm_update

.PHONY: clean
clean:
	rm -rf ./node_modules

.PHONY: distclean
distclean: clean
	git clean -Xfd

.PHONY: eslint_fix
eslint_fix: ./node_modules ./eslint.config.js
	npm exec --ignore-scripts -- eslint --concurrency=auto --fix .

.PHONY: prettier_fix
prettier_fix: ./node_modules ./prettier.config.js
	npm exec --ignore-scripts -- prettier -w .

.PHONY: yq_fix
yq_fix:
	find . -type f -name "*.yml" -exec yq -i 'sort_keys(..)' {} \;

.PHONY: eslint_check
eslint_check: ./node_modules ./eslint.config.js
	npm exec --ignore-scripts -- eslint --concurrency=auto .

.PHONY: prettier_check
prettier_check: ./node_modules ./prettier.config.js
	npm exec --ignore-scripts -- prettier -c .

.PHONY: typescript_check
typescript_check: ./node_modules ./tsconfig.json
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
	docker volume create tomaschochola-npm-cache >/dev/null

.PHONY: postcreate
postcreate: install

.PHONY: start serve server dev
start serve server dev: ./node_modules ./dist/index.js ./package.json ./package-lock.json tsc
	node ./dist/index.js

.PHONY: image
image:
	docker compose -f ./docker-compose.yml -f ./docker-compose-swarm.yml build --pull --push

.PHONY: trivy
trivy:
	docker compose -f ./docker-compose.yml -f ./docker-compose-swarm.yml build --pull
	@set -eo pipefail; \
		docker compose -f ./docker-compose.yml -f ./docker-compose-swarm.yml config --images | sort -u | \
		xargs -r -n 1 docker run --rm --pull missing \
			--mount type=bind,source=/var/run/docker.sock,target=/var/run/docker.sock \
			--mount type=volume,source=trivy-cache,target=/root/.cache \
			docker.io/aquasec/trivy:latest image \
			--exit-code 1 \
			--severity HIGH,CRITICAL

.PHONY: deploy
deploy:
	docker stack deploy -c ./docker-compose.yml -c ./docker-compose-swarm.yml --with-registry-auth --prune --detach=false --resolve-image=always $${CI_PROJECT_PATH_SLUG:-template-express-api}

.PHONY: up
up:
	docker compose -f ./docker-compose.yml -f ./docker-compose-swarm.yml up --build --remove-orphans --always-recreate-deps --force-recreate --pull=always --renew-anon-volumes

.PHONY: stop
stop:
	docker compose -f ./docker-compose.yml -f ./docker-compose-swarm.yml stop

.PHONY: port ports
port ports:
	@printf '\033[1m%-80s\033[0m\n' 'template-express-api ports'
	@printf '%-80s\n' '--------------------------------------------------------------------------------'
	@printf '\033[1m%-12s %-21s %-12s %-20s\033[0m\n' 'Kind' 'Host' 'Container' 'Service'
	@printf '%-12s %-21s %-12s %-20s\n' 'express' '-' '61400' 'server'
	@printf '%-12s %-21s %-12s %-20s\n' 'express' '127.0.0.1:61400' '61400' 'devcontainer'
	@printf '%-80s\n' '--------------------------------------------------------------------------------'
	@printf '\n\033[1mLinks\033[0m\n'
	@printf '%s\n' 'Express server: http://127.0.0.1:61400/'
	@printf '%s\n' 'Express health: http://127.0.0.1:61400/healthz/live'

.PHONY: devcontainer
devcontainer: precreate
	devcontainer up
	devcontainer exec /bin/bash || true
	docker ps -q --filter "label=devcontainer.local_folder=$${PWD}" | xargs -r docker stop

.PHONY: tsc
tsc: ./node_modules ./tsconfig.json
	npm exec --ignore-scripts -- tsc

# Dependencies
./package-lock.json ./node_modules: ./package.json
	${MAKE} npm_update
