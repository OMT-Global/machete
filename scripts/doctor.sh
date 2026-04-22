#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="${REPO_DIR}/dotfiles"
source "${REPO_DIR}/scripts/lib/brew-services.sh"

EXIT_CODE=0

header() { echo ""; echo "==> $*"; }
ok()     { echo "  [ok] $*"; }
warn()   { echo "  [!]  $*"; EXIT_CODE=1; }
info()   { echo "  [-]  $*"; }

hash_file() {
  local path="$1"

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$path" | awk '{print $1}'
  else
    cksum "$path" | awk '{print $1}'
  fi
}

# --- Homebrew health ---
header "Homebrew"
if command -v brew >/dev/null 2>&1; then
  ok "brew found at $(command -v brew)"

  if [[ -f "${REPO_DIR}/Brewfile" ]]; then
    if brew bundle check --file="${REPO_DIR}/Brewfile" --no-upgrade >/dev/null 2>&1; then
      ok "All Brewfile entries installed"
    else
      warn "Brewfile drift detected — run: ./machete setup"
    fi
  else
    warn "No Brewfile found"
  fi

  OUTDATED="$(brew outdated --quiet 2>/dev/null || true)"
  if [[ -z "${OUTDATED}" ]]; then
    ok "All packages up to date"
  else
    COUNT="$(echo "${OUTDATED}" | wc -l | tr -d ' ')"
    info "${COUNT} outdated package(s) — run: ./machete update"
    echo "${OUTDATED}" | sed 's/^/      /'
  fi
else
  warn "Homebrew not found"
fi

# --- Homebrew services ---
header "Homebrew services"
BREW_SERVICES_FILE="$(brew_services_state_file)"
if [[ ! -f "${BREW_SERVICES_FILE}" ]]; then
  info "No defaults/brew-services.txt — run: ./machete snapshot"
elif ! command -v brew >/dev/null 2>&1; then
  warn "Homebrew not found; cannot check saved services"
else
  FOUND_SERVICE=0
  while IFS=$'\t' read -r service_state service_name; do
    FOUND_SERVICE=1
    case "${service_state}" in
      missing) warn "${service_name}: saved but not installed — run: ./machete setup" ;;
      running) ok "${service_name}: running" ;;
      stopped) warn "${service_name}: saved but not running — run: ./machete services" ;;
    esac
  done < <(brew_services_saved_service_states "${BREW_SERVICES_FILE}")

  if [[ "${FOUND_SERVICE}" -eq 0 ]]; then
    info "No saved Homebrew services"
  fi
fi

# --- Dotfiles ---
header "Dotfiles"
if [[ -d "${DOTFILES_DIR}" ]]; then
  FOUND=0
  while IFS= read -r src; do
    rel="${src#${DOTFILES_DIR}/}"
    dst="${HOME}/${rel}"
    FOUND=$((FOUND + 1))

    if [[ ! -e "${dst}" ]]; then
      warn "${rel}: missing from home directory (not symlinked)"
    elif [[ -L "${dst}" ]]; then
      target="$(readlink "${dst}")"
      if [[ "${target}" == "${src}" ]]; then
        ok "${rel}: symlinked correctly"
      else
        warn "${rel}: symlink points elsewhere -> ${target}"
      fi
    else
      src_hash="$(hash_file "${src}")"
      dst_hash="$(hash_file "${dst}")"
      if [[ "${src_hash}" == "${dst_hash}" ]]; then
        info "${rel}: content matches but file is not symlinked"
      else
        warn "${rel}: content differs from repo — run: ./machete diff ${rel}"
      fi
    fi
  done < <(find "${DOTFILES_DIR}" -type f ! -name '.gitkeep' | sort)

  if [[ "${FOUND}" -eq 0 ]]; then
    info "No dotfiles committed yet — run: ./machete snapshot"
  fi
else
  info "No dotfiles/ directory — run: ./machete snapshot"
fi

# --- macOS defaults ---
header "macOS defaults"
DEFAULTS_SCRIPT="${REPO_DIR}/defaults/macos-defaults.sh"
if [[ -f "${DEFAULTS_SCRIPT}" ]]; then
  ok "defaults/macos-defaults.sh exists"
  if [[ ! -x "${DEFAULTS_SCRIPT}" ]]; then
    warn "defaults/macos-defaults.sh is not executable — run: chmod +x ${DEFAULTS_SCRIPT}"
  fi
else
  info "No defaults/macos-defaults.sh — run: ./machete snapshot to create template"
fi

# --- Git status ---
header "Repo sync"
cd "${REPO_DIR}"
if git remote get-url origin >/dev/null 2>&1; then
  git fetch --quiet origin 2>/dev/null || true
  CURRENT_BRANCH="$(git branch --show-current)"
  REMOTE_BRANCH="origin/${CURRENT_BRANCH}"
  DIRTY="$(git status --porcelain 2>/dev/null || true)"

  if [[ -n "${DIRTY}" ]]; then
    warn "Uncommitted local changes — run: ./machete snapshot then commit"
  else
    ok "Working tree clean"
  fi

  if git rev-parse --verify --quiet "${REMOTE_BRANCH}" >/dev/null; then
    BEHIND="$(git rev-list --count "HEAD..${REMOTE_BRANCH}" 2>/dev/null || echo "0")"
    AHEAD="$(git rev-list --count "${REMOTE_BRANCH}..HEAD" 2>/dev/null || echo "0")"

    if [[ "${BEHIND}" -gt 0 ]]; then
      warn "${BEHIND} commit(s) behind remote — run: ./machete sync"
    elif [[ "${AHEAD}" -gt 0 ]]; then
      info "${AHEAD} commit(s) ahead of remote — push when ready"
    else
      ok "In sync with remote"
    fi
  else
    info "No tracking branch configured yet"
  fi
else
  info "No remote configured"
fi

# --- Summary ---
echo ""
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  echo "All checks passed."
else
  echo "Some checks need attention (see [!] above)."
fi

exit "${EXIT_CODE}"
