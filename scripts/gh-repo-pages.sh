#!/usr/bin/env bash
# Copyright (c) 2026 NOAMi (https://noami.us)
set -euo pipefail

info() { printf "\n%s\n" "$*" >&2; }
warn() { printf "WARN: %s\n" "$*" >&2; }
fail() { printf "ERROR: %s\n" "$*" >&2; exit 1; }

prompt() {
  local label="$1"
  local default="${2-}"
  local value=""
  if [ -n "$default" ]; then
    read -r -p "$label [$default]: " value
    if [ -z "$value" ]; then
      value="$default"
    fi
  else
    read -r -p "$label: " value
  fi
  printf "%s" "$value"
}

token_file="${HOME}/.scadpipeline"
repo_file="/workspace/.scadpipeline_repo"

get_config() {
  local key="$1"
  if [ -f "$token_file" ]; then
    value="$(grep -E "^${key}=" "$token_file" | head -n1 | sed -E "s/^${key}=//")"
    if [ -n "$value" ]; then
      printf "%s" "$value"
      return 0
    fi
  fi
  return 1
}

set_config() {
  local key="$1"
  local value="$2"
  umask 077
  tmp="$(mktemp "$token_file.XXXXXX")"
  if [ -f "$token_file" ]; then
    grep -v -E "^${key}=" "$token_file" > "$tmp" || true
  fi
  printf "%s=%s\n" "$key" "$value" >> "$tmp"
  cat "$tmp" > "$token_file"
  rm -f "$tmp"
}

load_token() {
  if token="$(get_config token)"; then
    printf "%s" "$token"
    return 0
  fi
  if [ -f "$token_file" ]; then
    token="$(head -n1 "$token_file" | tr -d '\r')"
    if [ -n "$token" ] && ! printf "%s" "$token" | grep -q '='; then
      printf "%s" "$token"
      return 0
    fi
  fi
  return 1
}

save_token() {
  local token="$1"
  set_config token "$token"
}

install_gh_user() {
  local arch url version tmpdir target
  if ! command -v curl >/dev/null 2>&1; then
    fail "curl is required to install gh without root. Re-run as root or preinstall gh."
  fi
  case "$(uname -m)" in
    x86_64|amd64) arch="linux_amd64" ;;
    aarch64|arm64) arch="linux_arm64" ;;
    *) fail "Unsupported architecture: $(uname -m). Install gh manually." ;;
  esac
  version="$(
    curl -fsSL https://api.github.com/repos/cli/cli/releases/latest \
      | sed -n 's/.*"tag_name":[[:space:]]*"v\{0,1\}\([^"]*\)".*/\1/p' \
      | head -n1
  )"
  if [ -z "$version" ]; then
    fail "Unable to detect gh version from GitHub. Install gh manually."
  fi
  url="https://github.com/cli/cli/releases/latest/download/gh_${version}_${arch}.tar.gz"
  tmpdir="$(mktemp -d)"
  curl -fsSL "$url" -o "$tmpdir/gh.tgz"
  tar -xzf "$tmpdir/gh.tgz" -C "$tmpdir"
  target="${HOME}/.local/bin"
  mkdir -p "$target"
  cp "$tmpdir"/gh_"${version}"_"${arch}"/bin/gh "$target/gh"
  chmod +x "$target/gh"
  rm -rf "$tmpdir"
  export PATH="$target:$PATH"
}

install_gh_root() {
  # Prefer the official release tarball so we get device auth support.
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y
    apt-get install -y ca-certificates curl
  fi
  install_gh_user
}

ensure_gh() {
  if command -v gh >/dev/null 2>&1; then
    info "GitHub CLI found: $(gh --version | head -n1)"
    return 0
  fi
  info "GitHub CLI (gh) not found. Installing..."
  if [ "$(id -u)" -eq 0 ]; then
    install_gh_root
  else
    if ! command -v curl >/dev/null 2>&1; then
      fail "curl is required for user-space gh install. Run from pipeline create-github (root in container) or preinstall gh."
    fi
    install_gh_user
  fi
  if ! command -v gh >/dev/null 2>&1; then
    fail "gh installation failed."
  fi
  info "GitHub CLI installed: $(gh --version | head -n1)"
}

ensure_login() {
  if gh auth status -h github.com >/dev/null 2>&1; then
    info "GitHub CLI is already authenticated."
    return 0
  fi
  info "Let's sign in to GitHub."
  auth_mode="${GH_AUTH_MODE:-device}"

  auth_with_token() {
    info "Token auth selected (console-only)."
    if token="$(load_token)"; then
      use_existing="$(prompt "Use saved token from $token_file? (y/n)" "y")"
      if [ "$use_existing" = "y" ] || [ "$use_existing" = "Y" ]; then
        printf "%s" "$token" | gh auth login --hostname github.com --with-token
        return 0
      fi
    fi
    info "Create a classic PAT. Minimum scopes:"
    info "- public repos only: public_repo"
    info "- private repos: repo"
    info "- admin:org"
    info "Do NOT select delete_repo or project unless you specifically need them."
    printf "GitHub token: "
    stty -echo
    read -r token
    stty echo
    printf "\n"
    save_token "$token"
    printf "%s" "$token" | gh auth login --hostname github.com --with-token
  }

  if [ "$auth_mode" = "token" ]; then
    auth_with_token
    return 0
  fi

  if gh auth login --help 2>/dev/null | grep -q -- "--device"; then
    info "A one-time code will be shown. Open the URL on any device and paste the code."
    gh auth login --hostname github.com --device
    return 0
  fi

  info "This gh build doesn't support --device."
  auth_with_token
}

pick_visibility() {
  local choice
  while true; do
    choice="$(prompt "Visibility (public/private)" "public")"
    case "$choice" in
      public|private) printf "%s" "$choice"; return 0 ;;
      *) warn "Please type 'public' or 'private'." ;;
    esac
  done
}

create_repo() {
  local owner repo visibility desc full
  owner="$(get_config owner || true)"
  if [ -n "$owner" ]; then
    info "Default owner from $token_file: $owner"
  fi
  while true; do
    if [ -n "$owner" ]; then
      owner="$(prompt "GitHub owner (user or org)" "$owner")"
    else
      owner="$(prompt "GitHub owner (user or org)")"
    fi
    if [ -n "$owner" ]; then
      break
    fi
    warn "Owner is required."
  done
  default_repo="$(basename "$(pwd)")"
  while true; do
    repo="$(prompt "Repository name (no spaces)" "$default_repo")"
    if [ -n "$repo" ]; then
      break
    fi
    warn "Repository name is required."
  done
  visibility="$(pick_visibility)"
  desc="$(prompt "Description (optional)" "")"
  full="${owner}/${repo}"

  info "Creating repo: ${full} (${visibility})"
  if gh repo view "$full" >/dev/null 2>&1; then
    use_existing="$(prompt "Repo already exists. Use it? (y/n)" "y")"
    if [ "$use_existing" != "y" ] && [ "$use_existing" != "Y" ]; then
      fail "Choose a different repository name and try again."
    fi
  else
    if [ -n "$desc" ]; then
      gh repo create "$full" --"$visibility" --description "$desc" --confirm >/dev/null
    else
      gh repo create "$full" --"$visibility" --confirm >/dev/null
    fi
  fi

  set_config owner "$owner"
  set_config last_repo "$full"
  printf "%s\n" "$full" > "$repo_file"
  printf "%s" "$full"
}

main() {
  cmd="${1:-create}"
  case "$cmd" in
    create)
      info "SCADPipeline GitHub setup"
      info "This wizard will install gh (if needed), sign you in, and create a repo."
      ensure_gh
      ensure_login
      full_repo="$(create_repo)"
      info "GitHub Actions may be disabled by default on new repos."
      info "Enable it here: https://github.com/${full_repo}/settings/actions"
      info "After GitHub Actions publishes the gh-pages branch, enable Pages here:"
      info "https://github.com/${full_repo}/settings/pages"
      owner="$(printf "%s" "$full_repo" | awk -F/ '{print $1}')"
      repo="$(printf "%s" "$full_repo" | awk -F/ '{print $2}')"
      pages_url="https://${owner}.github.io/${repo}/"
      info "Interactive viewer: ${pages_url}"
      ;;
    enable-pages)
      ensure_gh
      ensure_login
      repo="${2:-}"
      if [ -z "$repo" ]; then
        repo="$(get_config last_repo || true)"
      fi
      if [ -z "$repo" ]; then
        repo="$(prompt "Repository (owner/name)")"
      fi
      warn "Pages enablement is manual. Open:"
      info "https://github.com/${repo}/settings/pages"
      ;;
    *)
      fail "Unknown command: $cmd"
      ;;
  esac
}

main "$@"
