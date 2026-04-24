#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/profiles.sh"

usage() {
  cat <<'EOF'
Manage machete profiles.

Usage:
  ./machete profile list
  ./machete profile create <name>
EOF
}

create_profile() {
  local profile_name="$1"
  local profile_root
  local defaults_script

  profile_require_valid_name "${profile_name}"

  if [[ "${profile_name}" == "${MACHETE_DEFAULT_PROFILE}" ]]; then
    echo "The default profile uses the repo root and does not need scaffolding." >&2
    return 1
  fi

  profile_root="$(profile_root_dir "${REPO_DIR}" "${profile_name}")"
  defaults_script="$(profile_defaults_script_path "${REPO_DIR}" "${profile_name}")"

  mkdir -p \
    "${profile_root}/dotfiles" \
    "${profile_root}/defaults" \
    "${profile_root}/packages"

  if [[ ! -f "$(profile_brewfile_path "${REPO_DIR}" "${profile_name}")" ]]; then
    : > "$(profile_brewfile_path "${REPO_DIR}" "${profile_name}")"
  fi

  if [[ ! -f "${defaults_script}" ]]; then
    cat > "${defaults_script}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Add profile-specific macOS defaults here.
EOF
    chmod +x "${defaults_script}"
  fi

  echo "Created profile scaffold at ${profile_root}"
}

SUBCOMMAND="${1:-list}"
if [[ $# -gt 0 ]]; then
  shift
fi

case "${SUBCOMMAND}" in
  list)
    ACTIVE_PROFILE="$(resolve_profile "${REPO_DIR}")"
    while IFS= read -r profile_name; do
      if [[ "${profile_name}" == "${ACTIVE_PROFILE}" ]]; then
        printf '* %s\n' "${profile_name}"
      else
        printf '  %s\n' "${profile_name}"
      fi
    done < <(list_profiles "${REPO_DIR}")
    ;;
  create)
    if [[ $# -ne 1 ]]; then
      usage >&2
      exit 1
    fi
    create_profile "$1"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    echo "Unknown profile command: ${SUBCOMMAND}" >&2
    echo "" >&2
    usage >&2
    exit 1
    ;;
esac
