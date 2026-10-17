#!/usr/bin/env bash
# Session-start setup for Claude Code on the web: build the gobofx CLI in
# release mode so `tools/verify-all.sh` is ready, and install the site deps.
# Locally, contributors build on demand — this bails outside a remote container.
set -euo pipefail
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi
cd "$CLAUDE_PROJECT_DIR"
if command -v cargo >/dev/null 2>&1; then
  echo "session-start: building gobofx CLI (release)"
  cargo build -p gobofx --release --quiet || echo "session-start: cargo build failed (continuing)" >&2
fi
if command -v pnpm >/dev/null 2>&1; then
  pnpm install --frozen-lockfile --silent 2>/dev/null || true
fi
