# syntax=docker/dockerfile:1
#
# Pretty MD (loader distribution) — container image.
# Node 20 is pinned on purpose: better-sqlite3 11.10.0 is validated on it.
# Do not bump the major without retesting the native build.
#
# NOTE: this image ships only the LOADER. At startup it downloads the real
# bot source (REPO_URL, overridable via env) into node_modules/xsqlite3/
# and runs it from there; the bot's require() calls resolve against this
# image's node_modules.

FROM node:20-bookworm-slim

# Compiler toolchain as a fallback for better-sqlite3 when its prebuilt
# binary cannot be downloaded. ffmpeg itself comes from ffmpeg-static (npm).
RUN apt-get update \
 && apt-get install -y --no-install-recommends python3 make g++ ca-certificates \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Dependencies in their own layer so source edits don't reinstall everything.
# No lockfile by design (this distribution resolves at build time).
COPY package.json ./
RUN npm install --omit=dev --no-audit --no-fund

# Loader source (see .dockerignore for what is excluded).
COPY . .

# The loader writes to /app at runtime (.env, .update-backup) and creates
# node_modules/xsqlite3/core0..core4/lib_signals/ for the downloaded bot,
# so the entire workdir — node_modules included — must be owned by the
# runtime user. Never run as root.
RUN chown -R node:node /app
USER node

# The loader itself binds nothing; the downloaded bot starts a keep-alive
# status server on $PORT (fallbacks 5000/3000/8000/4000). EXPOSE documents
# the default for platforms that auto-detect.
EXPOSE 5000

CMD ["node", "index.js"]
