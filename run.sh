#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found. Install Docker Desktop and try again." >&2
  exit 1
fi

if [ ! -f "site/index.html" ]; then
  echo "ERROR: site/index.html not found. Run ./build.sh first." >&2
  exit 1
fi

port="${SITE_PORT:-8080}"

port_available() {
  local p="$1"
  if command -v lsof >/dev/null 2>&1; then
    lsof -iTCP:"$p" -sTCP:LISTEN >/dev/null 2>&1 && return 1 || return 0
  fi
  if command -v nc >/dev/null 2>&1; then
    nc -z 127.0.0.1 "$p" >/dev/null 2>&1 && return 1 || return 0
  fi
  return 0
}

if ! port_available "$port"; then
  start_port="$port"
  for _ in $(seq 1 20); do
    port=$((port + 1))
    if port_available "$port"; then
      break
    fi
  done
  if [ "$port" = "$start_port" ]; then
    echo "ERROR: Port $start_port is in use and no free port found nearby." >&2
    exit 1
  fi
fi

url="http://localhost:$port"
log_file="${TMPDIR:-/tmp}/scadpipeline-site.log"

( docker run --rm   -p "$port:80"   -v "$root_dir/site:/usr/share/nginx/html:ro"   nginx:alpine ) >"$log_file" 2>&1 &
container_pid=$!

sleep 1

echo "Serving site at $url"
echo "Press Ctrl+C to stop."

echo "(nginx logs in $log_file)"

wait "$container_pid"
