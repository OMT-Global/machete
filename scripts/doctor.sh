#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="${REPO_DIR}/dotfiles"

EXIT_CODE=0

header() { echo ""; echo "==> $*"; }
ok()     { echo "  [ok] $*"; }
warn()   { echo "  [!]  $*"; EXIT_CODE=1; }
info()   { echo "  [-]  $*"; }

# --- Homebrew health ---
header "Homebrew"
if command -v brew >/dev/null 2>&1; then
  ok "brew found at $(which brew)"

  if [[ -f "${REPO_DIR}/Brewfile" ]]; then
    MISSING=$(brew bundle check --file="${REPO_DIR}/Brewfile" 2>&1 | grep "^The following" -A 999 || true)
    if [[ -z "${MISSING}" ]]; then
      ok "All Brewfile entries installed"
    else
      warn "Some Brewfile entries not installed — run: ./machetesetup"
      echo "${MISSING}" | sed 's/^/      /'
    fi
  else
    warn "No Brewfile found"
  fi

  OUTDATED=$(brew outdated --quiet 2>/dev/null || true)
  if [[ -z "${OUTDATED}" ]]; then
    ok "All packages up to date"
  else
    COUNT=$(echo "${OUTDATED}" | wc -l | tr -d ' ')
    info "${COUNT} outdated package(s) — run: ./macheteupdate"
    echo "${OUTDATED}" | sed 's/^/      /'
  fi
else
  warn "Homebrew not found"
fi

# --- Dotfiles ---
header "Dotfiles"
if [[ -d "${DOTFILES_DIR}" ]]; then
  FOUND=0
  for src in "${DOTFILES_DIR}"/.*; do
    f="$(basename "${src}")"
    [[ "${f}" == "." || "${f}" == ".." || "${f}" == ".gitkeep" ]] && continue
    dst="${HOME}/${f}"
    FOUND=$((FOUND + 1))
    if [[ ! -e "${dst}" ]]; then
      warn "${f}: missing from home directory (not symlinked)"
    elif [[ -L "${dst}" ]]; then
      target="$(readlink "${dst}")"
      if [[ "${target}" == "${src}" ]]; then
        ok "${f}: symlinked correctly"
      else
        warn "${f}: symlink points elsewhere → ${target}"
      fi
    else
      # Real file exists — check if content matches
      if diff -q "${src}" "${dst}" >/dev/null 2>&1; then
        info "${f}: exists (not symlinked, but content matches)"
      else
        warn "${f}: exists as real file and differs from repo — run: ./machetesetup"
      fi
    fi
  done
  [[ "${FOUND}" -eq 0 ]] && info "No dotfiles committed yet — run: ./machetesnapshot"
else
  info "No dotfiles/ directory — run: ./machetesnapshot"
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
  info "No defaults/macos-defaults.sh — run: ./machetesnapshot to create template"
fi

# --- Git status ---
header "Repo sync"
cd "${REPO_DIR}"
if git remote get-url origin >/dev/null 2>&1; then
  git fetch --quiet 2>/dev/null || true
  BEHIND=$(git rev-list HEAD..origin/$(git branch --show-current) --count 2>/dev/null || echo "0")
  AHEAD=$(git rev-list origin/$(git branch --show-current)..HEAD --count 2>/dev/null || echo "0")
  DIRTY=$(git status --porcelain 2>/dev/null || true)

  if [[ -n "${DIRTY}" ]]; then
    warn "Uncommitted local changes — run: ./machetesnapshot then commit"
  else
    ok "Working tree clean"
  fi

  if [[ "${BEHIND}" -gt 0 ]]; then
    warn "${BEHIND} commit(s) behind remote — run: ./machetesync"
  elif [[ "${AHEAD}" -gt 0 ]]; then
    info "${AHEAD} commit(s) ahead of remote — push when ready"
  else
    ok "In sync with remote"
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
