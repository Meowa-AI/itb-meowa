#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-/home/pc/.local/bin/godot}"
PRESET="${PRESET:-Web}"
OUT_PATH="${OUT_PATH:-build/web/index.html}"
OUT_FILE="$ROOT/$OUT_PATH"
OUT_DIR="$(dirname "$OUT_FILE")"

mkdir -p "$OUT_DIR"

"$GODOT_BIN" --headless --path "$ROOT" --import
"$GODOT_BIN" --headless --path "$ROOT" --export-release "$PRESET" "$OUT_FILE"

printf 'Exported %s\n' "$OUT_FILE"
