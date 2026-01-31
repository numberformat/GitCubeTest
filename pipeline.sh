#!/usr/bin/env bash
# Copyright (c) 2026 NOAMi (https://noami.us)
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"

usage() {
  cat <<'EOF'
Usage: ./pipeline.sh <command>

Commands:
  build          Build models and site (Dockerized OpenSCAD)
  clean          Remove the generated ./site directory
  run            Serve the site locally via nginx
  create-github  Create a GitHub repo (runs in container)
  help           Show this help
EOF
}

prompt() {
  local label="$1"
  local value=""
  read -r -p "$label: " value
  printf "%s" "$value"
}

ensure_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker not found. Install Docker Desktop and try again." >&2
    exit 1
  fi
}

ensure_git_ready() {
  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git not found. Install git to initialize the repo." >&2
    exit 1
  fi
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if ! git config --get user.name >/dev/null; then
      name="$(prompt "Git user.name")"
      git config user.name "$name"
    fi
    if ! git config --get user.email >/dev/null; then
      email="$(prompt "Git user.email")"
      git config user.email "$email"
    fi
    git init -b main
  fi
  if ! git rev-parse --verify HEAD >/dev/null 2>&1; then
    git add .
    git commit -m "Initial commit"
  elif [ -n "$(git status --porcelain)" ]; then
    git add .
    git commit -m "Prepare for GitHub"
  fi
}

configure_remote() {
  local full="$1"
  local url="https://github.com/${full}.git"
  local remote="origin"
  if git remote get-url origin >/dev/null 2>&1; then
    echo "Existing git remote 'origin' detected."
    echo "Choose an option:"
    echo "1) Add new remote (keep existing origin)"
    echo "2) Replace origin with the new GitHub repo"
    echo "3) Skip remote setup"
    choice="$(prompt "Select 1/2/3")"
    case "$choice" in
      1)
        remote="$(prompt "New remote name" "github")"
        git remote add "$remote" "$url"
        ;;
      2)
        git remote remove origin
        git remote add origin "$url"
        remote="origin"
        ;;
      3)
        return 0
        ;;
      *)
        echo "Invalid choice. Skipping remote setup."
        return 0
        ;;
    esac
  else
    git remote add origin "$url"
    remote="origin"
  fi

  push_all="$(prompt "Push all local branches to ${remote}? (y/n)" "y")"
  if [ "$push_all" = "y" ] || [ "$push_all" = "Y" ]; then
    git push --all "$remote"
    return 0
  fi
  push_choice="$(prompt "Push current branch to ${remote}? (y/n)" "y")"
  if [ "$push_choice" = "y" ] || [ "$push_choice" = "Y" ]; then
    git push -u "$remote" "$(git rev-parse --abbrev-ref HEAD)"
  fi
}

docker_image() {
  if [ -n "${OPENSCAD_DOCKER_IMAGE:-}" ]; then
    printf "%s" "$OPENSCAD_DOCKER_IMAGE"
  else
    printf "%s" "scadpipeline:latest"
  fi
}

ensure_docker_image() {
  local image platform
  image="$(docker_image)"
  if [ "$image" = "scadpipeline:latest" ]; then
    if ! docker image inspect "$image" >/dev/null 2>&1; then
      if [ ! -f "$root_dir/Dockerfile" ]; then
        echo "ERROR: Dockerfile not found; cannot build $image." >&2
        exit 1
      fi
      echo "Building Docker image $image..."
      platform="${OPENSCAD_DOCKER_PLATFORM:-}"
      if [ -z "$platform" ]; then
        platform="$(docker_platform_args || true)"
      fi
      if [ -n "$platform" ]; then
        docker build --platform "$platform" -t "$image" "$root_dir"
      else
        docker build -t "$image" "$root_dir"
      fi
    fi
  fi
}

docker_platform_args() {
  local platform="${OPENSCAD_DOCKER_PLATFORM:-}"
  if [ -z "$platform" ]; then
    local arch
    arch="$(uname -m)"
    if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then
      platform="linux/amd64"
    fi
  fi
  if [ -n "$platform" ]; then
    printf "%s" "$platform"
  fi
}

cmd_build() {
  ensure_docker
  ensure_docker_image
  local image platform_args
  image="$(docker_image)"
  platform_args=()
  if platform="$(docker_platform_args)"; then
    if [ -n "$platform" ]; then
      platform_args=(--platform "$platform")
    fi
  fi
  docker run --rm \
    --user "$(id -u):$(id -g)" \
    "${platform_args[@]}" \
    -v "$root_dir:/workspace" \
    -w /workspace \
    "$image" \
    bash /workspace/scripts/docker-build.sh
}

cmd_clean() {
  if [ -d "site" ]; then
    rm -rf site
    echo "Removed ./site"
  else
    echo "No ./site directory to remove"
  fi
}

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

cmd_run() {
  ensure_docker
  if [ ! -f "site/index.html" ]; then
    echo "ERROR: site/index.html not found. Run ./pipeline.sh build first." >&2
    exit 1
  fi

  local port start_port url log_file
  port="${SITE_PORT:-8080}"

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

  ( docker run --rm \
    -p "$port:80" \
    -v "$root_dir/site:/usr/share/nginx/html:ro" \
    nginx:alpine ) >"$log_file" 2>&1 &
  container_pid=$!

  sleep 1

  echo "Serving site at $url"
  echo "Press Ctrl+C to stop."
  echo "(nginx logs in $log_file)"

  wait "$container_pid"
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  build)
    cmd_build "$@"
    ;;
  clean)
    cmd_clean "$@"
    ;;
  run)
    cmd_run "$@"
    ;;
  create-github)
    ensure_git_ready
    ensure_docker
    ensure_docker_image
    touch "${HOME}/.scadpipeline"
    chmod 600 "${HOME}/.scadpipeline" || true
    image="$(docker_image)"
    platform_args=()
    platform="$(docker_platform_args)"
    if [ -n "$platform" ]; then
      platform_args=(--platform "$platform")
    fi
    tty_args=()
    if [ -t 0 ] && [ -t 1 ]; then
      tty_args=(-it)
    fi
    docker run --rm "${tty_args[@]}" \
      --user 0:0 \
      "${platform_args[@]}" \
      -v "${HOME}/.scadpipeline:/root/.scadpipeline" \
      -v "$root_dir:/workspace" \
      -w /workspace \
      "$image" \
      bash /workspace/scripts/gh-repo-pages.sh create
    if [ -f "$root_dir/.scadpipeline_repo" ]; then
      repo="$(cat "$root_dir/.scadpipeline_repo" | tr -d '\r\n')"
      if [ -n "$repo" ]; then
        configure_remote "$repo"
      else
        echo "WARN: No repo name returned from GitHub setup."
      fi
      rm -f "$root_dir/.scadpipeline_repo"
    else
      echo "WARN: Repo info file not found. Skipping remote setup."
    fi
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $cmd" >&2
    usage
    exit 1
    ;;
esac
