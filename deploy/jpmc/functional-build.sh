#!/usr/bin/env bash
# JPMC lightweight functional build: install, build @eventcatalog/core, build the default
# example catalog as a static site, and assert the output looks like a catalog.
# Same script runs on a laptop, on the Mac delegate (Delegate 3.x) and inside the image build.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
t0=$(date +%s)
corepack enable >/dev/null 2>&1 || true
pnpm install --frozen-lockfile --prefer-offline
pnpm turbo run build:bin --filter=@eventcatalog/core
t1=$(date +%s)

cd examples/default
mkdir -p node_modules/@eventcatalog
ln -sfn "$ROOT/packages/core" node_modules/@eventcatalog/core
# Stamp the build so a preview visibly shows which change it is serving
if [[ -n "${BUILD_LABEL:-}" ]]; then
  sed -i.bak "s|^  tagline: .*|  tagline: 'Build ${BUILD_LABEL}',|" eventcatalog.config.js && rm -f eventcatalog.config.js.bak
fi
NODE_OPTIONS=--max-old-space-size=4096 node "$ROOT/packages/core/bin/eventcatalog.js" build
t2=$(date +%s)

# Functional assertions: a static catalog with its key pages
test -f dist/index.html
pages=$(find dist -name '*.html' | wc -l | tr -d ' ')
test "$pages" -gt 50 || { echo "only $pages html pages built"; exit 1; }
for p in docs/domains docs/services docs/events; do
  ls dist/$p >/dev/null 2>&1 || { echo "missing $p in build output"; exit 1; }
done
echo "FUNCTIONAL_BUILD=PASS pages=$pages core_secs=$((t1-t0)) catalog_secs=$((t2-t1)) total_secs=$((t2-t0))"
