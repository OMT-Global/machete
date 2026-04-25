#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/profiles.sh"
MACHETE_PROFILE="${MACHETE_PROFILE:-$(resolve_profile "${REPO_DIR}")}"
DOTFILES_DIR="$(profile_dotfiles_dir "${REPO_DIR}" "${MACHETE_PROFILE}")"
source "${REPO_DIR}/scripts/lib/dotfiles.sh"

usage() {
  cat <<'EOF'
Reversibly tear down the machine-local parts of machete setup.

Usage:
  ./machete uninstall [--dotfiles] [--apply]
  ./machete uninstall --all [--apply]

Options:
  --dotfiles  Remove machete-managed home symlinks and restore the newest .bak backup when present
  --all       Alias for --dotfiles in Phase 1
  --apply     Perform the teardown; without this flag machete prints a dry-run plan

What this command does not do:
  - uninstall Homebrew packages or casks
  - remove caches, shell history, or other machine-local state
  - unwind scripts under scripts/claude/, scripts/claude-cloud/, or scripts/codex-cloud/
  - restore macOS defaults yet; use --dotfiles for the currently implemented Phase 1 path
EOF
}

ACTION_COUNT=0
APPLY=0
DO_DOTFILES=0
REQUESTED_DEFAULTS=0

latest_backup_for_path() {
  local destination_path="$1"
  local candidate
  local latest=""

  for candidate in "${destination_path}".bak.*; do
    [[ -e "${candidate}" ]] || continue
    if [[ -z "${latest}" || "${candidate}" > "${latest}" ]]; then
      latest="${candidate}"
    fi
  done

  [[ -n "${latest}" ]] || return 1
  printf '%s\n' "${latest}"
}

print_action() {
  local verb="$1"
  local detail="$2"

  ACTION_COUNT=$((ACTION_COUNT + 1))
  if [[ "${APPLY}" -eq 1 ]]; then
    printf '  - %s %s\n' "${verb}" "${detail}"
  else
    printf '  - Would %s %s\n' "${verb}" "${detail}"
  fi
}

apply_action() {
  local command="$1"

  if [[ "${APPLY}" -eq 1 ]]; then
    eval "${command}"
  fi
}

uninstall_dotfiles() {
  local found=0
  local src

  echo "==> Dotfiles"
  if [[ ! -d "${DOTFILES_DIR}" ]]; then
    echo "  - No dotfiles/ directory found for profile '${MACHETE_PROFILE}'."
    return 0
  fi

  while IFS= read -r src; do
    local rel
    local dst
    local backup

    found=1
    rel="${src#${DOTFILES_DIR}/}"
    dst="$(dotfile_home_path "${rel}")"

    if dotfile_symlink_points_to_path "${dst}" "${src}"; then
      print_action "remove" "managed symlink ${rel}"
      apply_action "rm -f \"${dst}\""

      if backup="$(latest_backup_for_path "${dst}")"; then
        print_action "restore" "backup ${rel} from ${backup}"
        apply_action "mv \"${backup}\" \"${dst}\""
      fi
      continue
    fi

    if [[ -L "${dst}" ]]; then
      print_action "skip" "${rel}: symlink points outside the repo"
      continue
    fi

    if [[ -e "${dst}" ]]; then
      print_action "skip" "${rel}: home file exists and is not a machete-managed symlink"
      continue
    fi

    if backup="$(latest_backup_for_path "${dst}")"; then
      print_action "restore" "backup ${rel} from ${backup}"
      apply_action "mkdir -p \"$(dirname "${dst}")\" && mv \"${backup}\" \"${dst}\""
    fi
  done < <(dotfiles_list "${DOTFILES_DIR}")

  if [[ "${found}" -eq 0 ]]; then
    echo "  - No tracked dotfiles found."
  elif [[ "${ACTION_COUNT}" -eq 0 ]]; then
    echo "  - Nothing to do."
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dotfiles)
      DO_DOTFILES=1
      shift
      ;;
    --defaults)
      REQUESTED_DEFAULTS=1
      shift
      ;;
    --all)
      DO_DOTFILES=1
      shift
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    help|--help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown uninstall option: $1" >&2
      echo >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ "${REQUESTED_DEFAULTS}" -eq 1 ]]; then
  echo "machete uninstall --defaults is not implemented yet. This change ships the Phase 1 dotfiles teardown only." >&2
  exit 1
fi

if [[ "${DO_DOTFILES}" -eq 0 ]]; then
  DO_DOTFILES=1
fi

if [[ "${APPLY}" -eq 0 ]]; then
  echo "Dry run only. Re-run with --apply to make changes."
fi

if [[ "${DO_DOTFILES}" -eq 1 ]]; then
  uninstall_dotfiles
fi

if [[ "${ACTION_COUNT}" -eq 0 ]]; then
  echo
  echo "No changes queued."
else
  echo
  if [[ "${APPLY}" -eq 1 ]]; then
    echo "Uninstall complete."
  else
    echo "Dry run complete."
  fi
fi
