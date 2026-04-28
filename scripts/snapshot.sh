#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/profiles.sh"
MACHETE_PROFILE="${MACHETE_PROFILE:-$(resolve_profile "${REPO_DIR}")}"
DOTFILES_DIR="$(profile_dotfiles_dir "${REPO_DIR}" "${MACHETE_PROFILE}")"
source "${REPO_DIR}/scripts/lib/brewfile.sh"
source "${REPO_DIR}/scripts/lib/brew-services.sh"
source "${REPO_DIR}/scripts/lib/dotfiles.sh"
source "${REPO_DIR}/scripts/lib/global-packages.sh"
source "${REPO_DIR}/scripts/lib/macos-defaults.sh"
source "${REPO_DIR}/scripts/lib/editor-extensions.sh"
source "${REPO_DIR}/scripts/lib/snapshot-tags.sh"

WITH_EXTENSIONS=0
AUDIT_BASELINE_MODE="${MACHETE_AUDIT_BASELINE_MODE:-background}"

usage() {
  cat <<'EOF'
Export current machine state to the repo.

Usage:
  ./machete snapshot [--with-extensions]

Options:
  --with-extensions  Also save VS Code-compatible editor extensions to packages/vscode-extensions.txt
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-extensions)
      WITH_EXTENSIONS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown snapshot option: $1" >&2
      echo "" >&2
      usage >&2
      exit 1
      ;;
  esac
done

echo "==> Creating rollback snapshot"
if SNAPSHOT_TAG="$(create_snapshot_tag "${REPO_DIR}" "snapshot")"; then
  echo "  - ${SNAPSHOT_TAG}"
else
  echo "  - Not in a git worktree; skipping rollback snapshot."
fi

echo "==> Exporting Homebrew packages to Brewfile"
if command -v brew >/dev/null 2>&1; then
  brewfile_dump_filtered "$(profile_brewfile_path "${REPO_DIR}" "${MACHETE_PROFILE}")"
  echo "  - Brewfile updated with portable filters"

  echo "==> Exporting Homebrew services to defaults/brew-services.txt"
  if brew_services_snapshot "$(brew_services_state_file)"; then
    echo "  - Homebrew services updated"
  else
    echo "  - brew services list failed; skipping services export."
  fi
else
  echo "  - Homebrew not found; skipping Brewfile export."
fi

echo "==> Exporting global packages"
snapshot_npm_globals "${REPO_DIR}"
snapshot_pip_globals "${REPO_DIR}"
snapshot_cargo_globals "${REPO_DIR}"

if [[ "${WITH_EXTENSIONS}" -eq 1 ]]; then
  echo "==> Exporting editor extensions"
  editor_extensions_snapshot "$(editor_extensions_file)"
fi

echo "==> Copying dotfiles to ${DOTFILES_DIR}"
mkdir -p "${DOTFILES_DIR}"
if dotfiles_has_tracked_files "${DOTFILES_DIR}"; then
  while IFS= read -r tracked_file; do
    relative_path="${tracked_file#${DOTFILES_DIR}/}"
    if ! dotfile_is_portable_path "${relative_path}"; then
      reason="$(dotfile_non_portable_reason "${relative_path}")"
      echo "  - ${relative_path} (skipped: ${reason})"
      continue
    fi

    source_path="$(dotfile_home_path "${relative_path}")"
    if [[ -f "${source_path}" ]]; then
      copy_home_dotfile_to_repo "${DOTFILES_DIR}" "${relative_path}"
      echo "  - ${relative_path}"
    else
      echo "  - ${relative_path} (missing from home; kept repo copy)"
    fi
  done < <(dotfiles_list "${DOTFILES_DIR}")
else
  while IFS= read -r default_path; do
    if ! dotfile_is_portable_path "${default_path}"; then
      reason="$(dotfile_non_portable_reason "${default_path}")"
      echo "  - ${default_path} (skipped: ${reason})"
      continue
    fi

    source_path="$(dotfile_home_path "${default_path}")"
    if [[ -f "${source_path}" ]]; then
      copy_home_dotfile_to_repo "${DOTFILES_DIR}" "${default_path}"
      echo "  - ${default_path}"
    fi
  done < <(dotfiles_default_paths)
fi

echo "==> Ensuring defaults/macos-defaults.sh exists"
DEFAULTS_SCRIPT="$(profile_defaults_script_path "${REPO_DIR}" "${MACHETE_PROFILE}")"
if [[ ! -f "${DEFAULTS_SCRIPT}" ]]; then
  echo "  - Creating defaults preset"
  macos_defaults_init "${DEFAULTS_SCRIPT}"
else
  echo "  - macOS defaults already exist for profile '${MACHETE_PROFILE}'; not overwriting."
fi

echo ""
echo "==> Snapshot complete. Review changes and commit:"
echo "    cd ${REPO_DIR}"
echo "    git diff --stat"
echo "    git add ."
echo "    git commit -m 'snapshot: \$(date +%Y-%m-%d)' && git push"

python_bin=""
if command -v python3 >/dev/null 2>&1; then
  python_bin="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
  python_bin="$(command -v python)"
fi

if [[ -n "${python_bin}" ]]; then
  checksum_db="${MACHETE_CHECKSUM_DB:-${HOME}/.machete/checksums.sqlite}"
  baseline_cmd=(
    "${python_bin}"
    "${REPO_DIR}/scripts/cksum.py"
    --db "${checksum_db}"
    --scope "home:${HOME}"
    --mode init
    --home "${HOME}"
  )

  case "${AUDIT_BASELINE_MODE}" in
    background)
      echo "==> Starting full-home audit baseline refresh in background"
      log_file="${HOME}/.machete/audit-baseline.log"
      mkdir -p "$(dirname "${log_file}")"
      (
        "${baseline_cmd[@]}" >"${log_file}" 2>&1
      ) &
      ;;
    foreground)
      echo "==> Refreshing full-home audit baseline"
      "${baseline_cmd[@]}"
      ;;
    skip)
      echo "==> Skipping full-home audit baseline refresh"
      ;;
    *)
      echo "Unknown MACHETE_AUDIT_BASELINE_MODE: ${AUDIT_BASELINE_MODE}" >&2
      exit 1
      ;;
  esac
else
  echo "==> Python not found; skipping full-home audit baseline refresh."
fi
