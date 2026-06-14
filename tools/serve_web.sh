#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-58244}"
WEB_DIR="${WEB_DIR:-$ROOT/build/web}"

EXTRA_ARGS=()
if [[ -n "${TLS_CERT:-}" ]]; then
	EXTRA_ARGS+=(--cert "$TLS_CERT" --key "${TLS_KEY:-}")
fi
python3 "$ROOT/tools/serve_web.py" --dir "$WEB_DIR" --host "$HOST" --port "$PORT" "${EXTRA_ARGS[@]}"
