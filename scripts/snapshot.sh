#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="${REPO_DIR}/dotfiles"
source "${REPO_DIR}/scripts/lib/brewfile.sh"
source "${REPO_DIR}/scripts/lib/brew-services.sh"
source "${REPO_DIR}/scripts/lib/global-packages.sh"
source "${REPO_DIR}/scripts/lib/macos-defaults.sh"
source "${REPO_DIR}/scripts/lib/editor-extensions.sh"

WITH_EXTENSIONS=0

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

echo "==> Exporting Homebrew packages to Brewfile"
if command -v brew >/dev/null 2>&1; then
  brewfile_dump_filtered "${REPO_DIR}/Brewfile"
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
DOTFILES=(.zshrc .zprofile .gitconfig .gitignore_global .vimrc .ssh/config)
for f in "${DOTFILES[@]}"; do
  src="${HOME}/${f}"
  if [[ -f "${src}" ]]; then
    dst_dir="${DOTFILES_DIR}/$(dirname "${f}")"
    mkdir -p "${dst_dir}"
    cp "${src}" "${DOTFILES_DIR}/${f}"
    echo "  - ${f}"
  fi
done

echo "==> Ensuring defaults/macos-defaults.sh exists"
DEFAULTS_SCRIPT="${REPO_DIR}/defaults/macos-defaults.sh"
if [[ ! -f "${DEFAULTS_SCRIPT}" ]]; then
  echo "  - Creating defaults preset"
  macos_defaults_init "${DEFAULTS_SCRIPT}"
else
  echo "  - defaults/macos-defaults.sh already exists; not overwriting."
fi

echo ""
echo "==> Snapshot complete. Review changes and commit:"
echo "    cd ${REPO_DIR}"
echo "    git diff --stat"
echo "    git add ."
echo "    git commit -m 'snapshot: \$(date +%Y-%m-%d)' && git push"
