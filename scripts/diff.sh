#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/profiles.sh"
MACHETE_PROFILE="${MACHETE_PROFILE:-$(resolve_profile "${REPO_DIR}")}"
source "${REPO_DIR}/scripts/lib/brewfile.sh"
source "${REPO_DIR}/scripts/lib/dotfiles.sh"

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
  local repo_file
  local home_file="${HOME}/${relative_path}"

  if ! repo_file="$(profile_dotfile_source_path "${REPO_DIR}" "${MACHETE_PROFILE}" "${relative_path}")"; then
    repo_file=""
  fi

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
  local tmp_dump
  local merged_brewfile
  tmp_dump="$(mktemp "${TMPDIR:-/tmp}/machete-brewfile.diff.XXXXXX")"
  merged_brewfile="$(mktemp "${TMPDIR:-/tmp}/machete-brewfile.repo.XXXXXX")"
  profile_write_merged_brewfile "${REPO_DIR}" "${MACHETE_PROFILE}" "${merged_brewfile}"

  if [[ ! -s "${merged_brewfile}" ]]; then
    echo "  [!] Brewfile not found for profile '${MACHETE_PROFILE}'"
    EXIT_CODE=1
    rm -f "${tmp_dump}"
    rm -f "${merged_brewfile}"
    return
  fi

  if ! command -v brew >/dev/null 2>&1; then
    echo "  [!] brew not found; cannot compare Brewfile"
    EXIT_CODE=1
    rm -f "${tmp_dump}"
    rm -f "${merged_brewfile}"
    return
  fi

  brewfile_dump_filtered "${tmp_dump}"

  if diff -u --label "repo/Brewfile" --label "current/brew bundle dump" "${merged_brewfile}" "${tmp_dump}"; then
    echo "  [ok] Brewfile: matches current brew bundle dump"
  else
    EXIT_CODE=1
  fi

  rm -f "${tmp_dump}"
  rm -f "${merged_brewfile}"
}

if [[ "${#PATHS[@]}" -eq 0 && "${DO_BREW}" -eq 0 ]]; then
  show_header "Dotfiles"
  while IFS=$'\t' read -r relative_path _; do
    diff_dotfile "${relative_path}"
  done < <(profile_collect_dotfiles "${REPO_DIR}" "${MACHETE_PROFILE}")

  show_header "Brewfile"
  diff_brewfile
else
  if [[ "${#PATHS[@]}" -gt 0 ]]; then
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
          if profile_dotfile_source_path "${REPO_DIR}" "${MACHETE_PROFILE}" "${path}" >/dev/null; then
            show_header "${path}"
            diff_dotfile "${path}"
          else
            echo "  [!] ${path}: not recognized as a tracked dotfile or Brewfile"
            EXIT_CODE=1
          fi
          ;;
      esac
    done
  fi

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
