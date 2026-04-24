#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="${REPO_DIR}/dotfiles"
source "${REPO_DIR}/scripts/lib/dotfiles.sh"

usage() {
  cat <<'EOF'
Remove one or more files from dotfiles/ and stop managing them.

Usage:
  ./machete untrack PATH [PATH ...]

Examples:
  ./machete untrack .zshrc
  ./machete untrack .ssh/config
EOF
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 1
fi

for path in "$@"; do
  if ! relative_path="$(normalize_dotfile_path "${path}")"; then
    echo "Invalid dotfile path: ${path}" >&2
    exit 1
  fi

  source_path="$(dotfile_repo_path "${DOTFILES_DIR}" "${relative_path}")"
  destination_path="$(dotfile_home_path "${relative_path}")"

  if [[ ! -f "${source_path}" ]]; then
    echo "Cannot untrack ${relative_path}: not found in dotfiles/" >&2
    exit 1
  fi

  if [[ -L "${destination_path}" ]]; then
    target="$(readlink "${destination_path}")"
    if [[ "${target}" != /* ]]; then
      target="$(dirname "${destination_path}")/${target}"
    fi

    if [[ "$(dotfile_canonical_path "${target}")" == "$(dotfile_canonical_path "${source_path}")" ]]; then
      rm -f "${destination_path}"
      mkdir -p "$(dirname "${destination_path}")"
      cp "${source_path}" "${destination_path}"
    fi
  fi

  rm -f "${source_path}"
  remove_empty_parent_dirs "${DOTFILES_DIR}" "${source_path}"
  echo "Untracked ${relative_path}"
done
