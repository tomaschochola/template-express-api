# syntax=docker/dockerfile:1

FROM docker.io/library/node:24-trixie AS versionednode

FROM versionednode AS base
WORKDIR /workspace
ENV APP_ENV=production
ENV NODE_ENV=production
RUN <<EOF
  set -euo pipefail
  apt-get update -y
  apt-get upgrade -y --no-install-recommends
  apt-get autoremove -y
  apt-get autoclean -y
  apt-get clean -y
  rm -rf /var/lib/apt/lists/*
EOF
RUN chown node:node /workspace
RUN install -d -o node -g node /home/node/.npm
USER node

FROM base AS development_deps
COPY --chown=node:node ./package* ./
RUN npm install --ignore-scripts --install-links --include=prod --include=dev --include=peer --include=optional

FROM base AS production_deps
COPY --chown=node:node ./package* ./
RUN npm install --ignore-scripts --install-links --include=prod --omit=dev --include=peer --include=optional

FROM development_deps AS build
COPY --chown=node:node ./ ./
RUN npm exec --ignore-scripts -- tsc

FROM base AS server
COPY --chown=node:node --from=production_deps /workspace/package.json ./
COPY --chown=node:node --from=production_deps /workspace/package-lock.json ./
COPY --chown=node:node --from=production_deps /workspace/node_modules ./node_modules
COPY --chown=node:node --from=build /workspace/dist ./dist
COPY --chown=node:node --from=build /workspace/static ./static
COPY --chown=node:node --from=build /workspace/views ./views
CMD ["node", "./dist/index.js"]

FROM base AS devcontainer
USER root
ENV APP_ENV=local
ENV NODE_ENV=development
RUN <<EOF
  set -euo pipefail
  apt-get update -y
  apt-get upgrade -y --no-install-recommends
  apt-get install -y --no-install-recommends ca-certificates curl wget build-essential git zip unzip
  wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/local/bin/yq
  chmod +x /usr/local/bin/yq
  apt-get autoremove -y
  apt-get autoclean -y
  apt-get clean -y
  rm -rf /var/lib/apt/lists/*
EOF
USER node
