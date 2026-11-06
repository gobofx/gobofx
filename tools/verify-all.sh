#!/usr/bin/env bash
# Build the CLI and verify every library plugin (plugins/org.gobofx.*), or the
# folders given as arguments. Writes <plugin>/dist/verify/{report.json,sheet.png,*.png}
# per plugin and dist/verify/{index.json,all.png} for the batch.
#
#   tools/verify-all.sh                 # whole library
#   tools/verify-all.sh plugins/org.gobofx.wipe plugins/org.gobofx.solid
#   ASSETS=1 tools/verify-all.sh        # also (re)write preview.png + icon.png
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
# shellcheck source=tools/gpu-env.sh
source tools/gpu-env.sh
cargo build -p gobofx --release --quiet
if [ "$#" -gt 0 ]; then
  dirs=("$@")
else
  dirs=()
  for d in plugins/org.gobofx.*/; do dirs+=("${d%/}"); done
fi
extra=()
[ -n "${ASSETS:-}" ] && extra+=(--assets)
[ -n "${NO_PERF:-}" ] && extra+=(--no-perf)
exec target/release/gobofx verify "${dirs[@]}" "${extra[@]}"
