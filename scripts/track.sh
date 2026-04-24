#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="${REPO_DIR}/dotfiles"
source "${REPO_DIR}/scripts/lib/dotfiles.sh"

usage() {
  cat <<'EOF'
Add one or more home-directory files to dotfiles/ and start managing them.

Usage:
  ./machete track PATH [PATH ...]

Examples:
  ./machete track .zshrc
  ./machete track .ssh/config
  ./machete track ~/.config/ghostty/config
EOF
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 1
fi

mkdir -p "${DOTFILES_DIR}"

for path in "$@"; do
  if ! relative_path="$(normalize_dotfile_path "${path}")"; then
    echo "Invalid dotfile path: ${path}" >&2
    exit 1
  fi

  source_path="$(dotfile_home_path "${relative_path}")"

  if [[ ! -e "${source_path}" ]]; then
    echo "Cannot track ${relative_path}: ${source_path} does not exist" >&2
    exit 1
  fi

  if [[ ! -f "${source_path}" ]]; then
    echo "Cannot track ${relative_path}: only files are supported" >&2
    exit 1
  fi

  copy_home_dotfile_to_repo "${DOTFILES_DIR}" "${relative_path}"
  symlink_repo_dotfile_to_home "${DOTFILES_DIR}" "${relative_path}"
  echo "Tracked ${relative_path}"
done
