#!/usr/bin/env bash
# update-wasm-demo.sh
# Rebuilds the rs-grid WASM demo and copies it into the site.
#
# Usage (from repo root or scripts/):
#   bash scripts/update-wasm-demo.sh [path/to/rs-grid]
#
# Requires: trunk, cargo (Rust toolchain with wasm32-unknown-unknown target)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RS_GRID="${1:-../../rs-grid}"          # default: sibling repo
EXAMPLE="$RS_GRID/examples/basic-leptos"
OUT_DIR="$SITE_ROOT/docs/public/wasm"

echo "▶ Building WASM demo from $EXAMPLE …"
(cd "$EXAMPLE" && trunk build --release)

JS_SRC=$(ls "$EXAMPLE/dist"/basic-leptos-*.js 2>/dev/null | grep -v snippets | head -1)
WASM_SRC=$(ls "$EXAMPLE/dist"/basic-leptos-*_bg.wasm 2>/dev/null | head -1)

if [[ -z "$JS_SRC" || -z "$WASM_SRC" ]]; then
  echo "✗ Build artefacts not found in $EXAMPLE/dist" >&2
  exit 1
fi

echo "▶ Copying artefacts to $OUT_DIR …"
cp "$JS_SRC"   "$OUT_DIR/basic_js.js"
cp "$WASM_SRC" "$OUT_DIR/basic_js_bg.wasm"

echo "✔ Done — $(du -sh "$OUT_DIR/basic_js_bg.wasm" | cut -f1) WASM, $(du -sh "$OUT_DIR/basic_js.js" | cut -f1) JS"
echo ""
echo "Next: git add docs/public/wasm && git commit -m 'chore: update WASM demo'"
