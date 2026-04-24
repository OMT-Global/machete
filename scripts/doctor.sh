#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/profiles.sh"
MACHETE_PROFILE="${MACHETE_PROFILE:-$(resolve_profile "${REPO_DIR}")}"
DOTFILES_DIR="$(profile_dotfiles_dir "${REPO_DIR}" "${MACHETE_PROFILE}")"
source "${REPO_DIR}/scripts/lib/brew-services.sh"
source "${REPO_DIR}/scripts/lib/dotfiles.sh"
source "${REPO_DIR}/scripts/lib/global-packages.sh"
source "${REPO_DIR}/scripts/lib/editor-extensions.sh"

EXIT_CODE=0
CHECKSUM_DB="${MACHETE_CHECKSUM_DB:-${HOME}/.machete/checksums.sqlite}"
CHECKSUM_SCOPE="profile:${MACHETE_PROFILE}:tracked"

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

python_bin() {
  if command -v python3 >/dev/null 2>&1; then
    command -v python3
  elif command -v python >/dev/null 2>&1; then
    command -v python
  else
    return 1
  fi
}

checksum_status() {
  local path="$1"
  local tmp_file
  local output
  local status
  local python

  if [[ ! -f "${CHECKSUM_DB}" ]]; then
    echo "NO_BASELINE"
    return 0
  fi

  if ! python="$(python_bin)"; then
    echo "NO_PYTHON"
    return 0
  fi

  tmp_file="$(mktemp "${TMPDIR:-/tmp}/machete-doctor-checksum.XXXXXX")"
  printf '%s\0' "$(dotfile_canonical_path "${path}")" > "${tmp_file}"
  output="$("${python}" "${REPO_DIR}/scripts/cksum.py" \
    --db "${CHECKSUM_DB}" \
    --scope "${CHECKSUM_SCOPE}" \
    --mode check \
    --paths-file "${tmp_file}" 2>/dev/null)" && status=0 || status=$?
  rm -f "${tmp_file}"

  if [[ "${status}" -eq 0 ]]; then
    echo "OK"
  elif [[ "${output}" == NEW* ]]; then
    echo "NO_BASELINE"
  elif [[ "${output}" == CHANGED* ]]; then
    echo "CHANGED"
  elif [[ "${output}" == MISSING* ]]; then
    echo "MISSING"
  else
    echo "UNKNOWN"
  fi
}

# --- Homebrew health ---
header "Homebrew"
BREWFILE_PATH="$(profile_brewfile_path "${REPO_DIR}" "${MACHETE_PROFILE}")"
if command -v brew >/dev/null 2>&1; then
  ok "brew found at $(command -v brew)"

  if [[ -f "${BREWFILE_PATH}" ]]; then
    if brew bundle check --file="${BREWFILE_PATH}" --no-upgrade >/dev/null 2>&1; then
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

# --- Global packages ---
header "Global packages"

NPM_FILE="$(npm_packages_file "${REPO_DIR}")"
if [[ -f "${NPM_FILE}" ]]; then
  if command -v npm >/dev/null 2>&1; then
    if check_saved_vs_current "${NPM_FILE}" bash -lc "npm ls -g --depth=0 --parseable=true 2>/dev/null | awk -F/ 'NR>1 {print \\$NF}' | grep -v '^npm$' | LC_ALL=C sort -u"; then
      ok "npm globals match snapshot"
    else
      warn "npm global package drift detected — run: ./machete snapshot or ./machete setup"
    fi
  else
    warn "npm snapshot exists but npm is not installed"
  fi
else
  info "No npm global snapshot yet — run: ./machete snapshot"
fi

PIP_FILE="$(pip_packages_file "${REPO_DIR}")"
if [[ -f "${PIP_FILE}" ]]; then
  if command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1 || command -v python3 >/dev/null 2>&1 || command -v python >/dev/null 2>&1; then
    if check_saved_vs_current "${PIP_FILE}" bash -lc '
      if command -v pip3 >/dev/null 2>&1; then
        pip3 list --user --format=freeze 2>/dev/null
      elif command -v pip >/dev/null 2>&1; then
        pip list --user --format=freeze 2>/dev/null
      elif command -v python3 >/dev/null 2>&1; then
        python3 -m pip list --user --format=freeze 2>/dev/null
      else
        python -m pip list --user --format=freeze 2>/dev/null
      fi | sed "/^$/d" | LC_ALL=C sort -u'; then
      ok "pip globals match snapshot"
    else
      warn "pip global package drift detected — run: ./machete snapshot or ./machete setup"
    fi
  else
    warn "pip snapshot exists but pip is not installed"
  fi
else
  info "No pip global snapshot yet — run: ./machete snapshot"
fi

CARGO_FILE="$(cargo_packages_file "${REPO_DIR}")"
if [[ -f "${CARGO_FILE}" ]]; then
  if command -v cargo >/dev/null 2>&1; then
    if check_saved_vs_current "${CARGO_FILE}" bash -lc "cargo install --list 2>/dev/null | awk '/^[^ ]+ v[0-9]/ {version=substr(\\$2,2); sub(/:$/, \"\", version); print \\$1 \"@\" version}' | LC_ALL=C sort -u"; then
      ok "cargo globals match snapshot"
    else
      warn "cargo global package drift detected — run: ./machete snapshot or ./machete setup"
    fi
  else
    warn "cargo snapshot exists but cargo is not installed"
  fi
else
  info "No cargo global snapshot yet — run: ./machete snapshot"
fi

# --- Editor extensions ---
header "Editor extensions"
EDITOR_EXTENSIONS_FILE="$(editor_extensions_file)"
EDITOR_EXTENSIONS_STATE="$(editor_extensions_diff "${EDITOR_EXTENSIONS_FILE}")"
case "${EDITOR_EXTENSIONS_STATE}" in
  absent)
    info "No packages/vscode-extensions.txt — run: ./machete snapshot --with-extensions"
    ;;
  missing-editor)
    warn "packages/vscode-extensions.txt exists, but no VS Code-compatible editor CLI was found"
    ;;
  clean)
    ok "Editor extensions match packages/vscode-extensions.txt"
    ;;
  *)
    warn "Editor extension drift detected — run: ./machete setup or ./machete snapshot --with-extensions"
    while IFS=$'\t' read -r drift_type extension; do
      case "${drift_type}" in
        missing) echo "      missing: ${extension}" ;;
        extra) echo "      extra: ${extension}" ;;
      esac
    done <<< "${EDITOR_EXTENSIONS_STATE}"
    ;;
esac

# --- Dotfiles ---
header "Dotfiles"
if [[ -d "${DOTFILES_DIR}" ]]; then
  FOUND=0
  while IFS= read -r src; do
    rel="${src#${DOTFILES_DIR}/}"
    dst="$(dotfile_home_path "${rel}")"
    FOUND=$((FOUND + 1))

    if [[ ! -e "${dst}" ]]; then
      info "${rel}: absent from home directory"
    elif [[ -L "${dst}" ]]; then
      if dotfile_symlink_points_to_path "${dst}" "${src}"; then
        checksum_state="$(checksum_status "${dst}")"
        case "${checksum_state}" in
          OK) ok "${rel}: symlinked correctly (hash match)" ;;
          CHANGED) warn "${rel}: symlinked correctly (CONTENT DRIFT — run: ./machete diff ${rel})" ;;
          NO_BASELINE) info "${rel}: symlinked correctly (no checksum baseline — run: ./machete verify --init)" ;;
          NO_PYTHON) info "${rel}: symlinked correctly (checksum skipped; Python 3 not found)" ;;
          *) info "${rel}: symlinked correctly (checksum skipped)" ;;
        esac
      else
        target="$(dotfile_resolve_symlink_target "${dst}")"
        warn "${rel}: symlink points elsewhere -> ${target}"
      fi
    else
      info "${rel}: present as a regular file (not symlinked)"
    fi
  done < <(dotfiles_list "${DOTFILES_DIR}")

  if [[ "${FOUND}" -eq 0 ]]; then
    info "No dotfiles committed yet — run: ./machete snapshot"
  fi
else
  info "No dotfiles/ directory — run: ./machete snapshot"
fi

# --- macOS defaults ---
header "macOS defaults"
DEFAULTS_SCRIPT="$(profile_defaults_script_path "${REPO_DIR}" "${MACHETE_PROFILE}")"
if [[ -f "${DEFAULTS_SCRIPT}" ]]; then
  ok "defaults/macos-defaults.sh exists"
  if [[ ! -x "${DEFAULTS_SCRIPT}" ]]; then
    warn "defaults/macos-defaults.sh is not executable — run: chmod +x ${DEFAULTS_SCRIPT}"
  fi
else
  info "No macOS defaults template for profile '${MACHETE_PROFILE}' — run: ./machete snapshot to create one"
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
