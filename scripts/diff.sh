#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/brewfile.sh"

usage() {
  cat <<'EOF'
Compare tracked state against what is on disk.

Usage:
  ./machete diff [PATH ...]
  ./machete diff --brew

Examples:
  ./machete diff .zshrc
  ./machete diff .ssh/config
  ./machete diff --brew
EOF
}

EXIT_CODE=0
DO_BREW=0
PATHS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --brew)
      DO_BREW=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      PATHS+=("$@")
      break
      ;;
    *)
      PATHS+=("$1")
      shift
      ;;
  esac
done

show_header() {
  echo ""
  echo "==> $*"
}

diff_dotfile() {
  local relative_path="$1"
  local repo_file="${REPO_DIR}/dotfiles/${relative_path}"
  local home_file="${HOME}/${relative_path}"

  if [[ ! -f "${repo_file}" ]]; then
    echo "  [!] ${relative_path}: not tracked in dotfiles/"
    EXIT_CODE=1
    return
  fi

  if [[ ! -e "${home_file}" ]]; then
    echo "  [!] ${relative_path}: missing from ${home_file}"
    diff -u --label "repo/dotfiles/${relative_path}" --label "home/${relative_path}" "${repo_file}" /dev/null || true
    EXIT_CODE=1
    return
  fi

  if diff -u --label "repo/dotfiles/${relative_path}" --label "home/${relative_path}" "${repo_file}" "${home_file}"; then
    echo "  [ok] ${relative_path}: matches"
  else
    EXIT_CODE=1
  fi
}

diff_brewfile() {
  local brewfile_path="${REPO_DIR}/Brewfile"
  local tmp_dump
  tmp_dump="$(mktemp "${TMPDIR:-/tmp}/machete-brewfile.diff.XXXXXX")"

  if ! command -v brew >/dev/null 2>&1; then
    echo "  [!] brew not found; cannot compare Brewfile"
    EXIT_CODE=1
    rm -f "${tmp_dump}"
    return
  fi

  brewfile_dump_filtered "${tmp_dump}"

  if diff -u --label "repo/Brewfile" --label "current/brew bundle dump" "${brewfile_path}" "${tmp_dump}"; then
    echo "  [ok] Brewfile: matches current brew bundle dump"
  else
    EXIT_CODE=1
  fi

  rm -f "${tmp_dump}"
}

if [[ "${#PATHS[@]}" -eq 0 && "${DO_BREW}" -eq 0 ]]; then
  show_header "Dotfiles"
  while IFS= read -r tracked_file; do
    relative_path="${tracked_file#${REPO_DIR}/dotfiles/}"
    diff_dotfile "${relative_path}"
  done < <(find "${REPO_DIR}/dotfiles" -type f ! -name '.gitkeep' | sort)

  show_header "Brewfile"
  diff_brewfile
else
  for path in "${PATHS[@]}"; do
    case "${path}" in
      Brewfile)
        show_header "Brewfile"
        diff_brewfile
        ;;
      dotfiles/*)
        relative_path="${path#dotfiles/}"
        show_header "${relative_path}"
        diff_dotfile "${relative_path}"
        ;;
      .*)
        show_header "${path}"
        diff_dotfile "${path}"
        ;;
      *)
        if [[ -f "${REPO_DIR}/dotfiles/${path}" ]]; then
          show_header "${path}"
          diff_dotfile "${path}"
        else
          echo "  [!] ${path}: not recognized as a tracked dotfile or Brewfile"
          EXIT_CODE=1
        fi
        ;;
    esac
  done

  if [[ "${DO_BREW}" -eq 1 ]]; then
    show_header "Brewfile"
    diff_brewfile
  fi
fi

echo ""
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  echo "No differences found."
else
  echo "Differences found."
fi

exit "${EXIT_CODE}"
