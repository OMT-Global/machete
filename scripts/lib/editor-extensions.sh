#!/usr/bin/env bash

editor_extensions_file() {
  echo "${REPO_DIR}/packages/vscode-extensions.txt"
}

editor_extensions_find_bin() {
  local candidate

  for candidate in code cursor codium; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      command -v "${candidate}"
      return 0
    fi
  done

  return 1
}

editor_extensions_snapshot() {
  local destination_file="$1"
  local editor_bin

  if ! editor_bin="$(editor_extensions_find_bin)"; then
    echo "  - No VS Code-compatible editor CLI found; skipping extensions export."
    return 0
  fi

  mkdir -p "$(dirname "${destination_file}")"
  "${editor_bin}" --list-extensions | sort -u > "${destination_file}"
  echo "  - Editor extensions written to ${destination_file}"
}

editor_extensions_restore() {
  local source_file="$1"
  local editor_bin extension

  if [[ ! -f "${source_file}" ]]; then
    return 0
  fi

  if ! editor_bin="$(editor_extensions_find_bin)"; then
    echo "  - No VS Code-compatible editor CLI found; skipping extension install."
    return 0
  fi

  echo "==> Installing editor extensions from ${source_file}"
  while IFS= read -r extension || [[ -n "${extension}" ]]; do
    if [[ -z "${extension}" || "${extension}" == \#* ]]; then
      continue
    fi

    echo "  - ${extension}"
    "${editor_bin}" --install-extension "${extension}"
  done < "${source_file}"
}

editor_extensions_diff() {
  local source_file="$1"
  local editor_bin current_file expected_file missing_file extra_file

  if [[ ! -f "${source_file}" ]]; then
    echo "absent"
    return 0
  fi

  if ! editor_bin="$(editor_extensions_find_bin)"; then
    echo "missing-editor"
    return 0
  fi

  current_file="$(mktemp "${TMPDIR:-/tmp}/machete-editor-extensions.current.XXXXXX")"
  expected_file="$(mktemp "${TMPDIR:-/tmp}/machete-editor-extensions.expected.XXXXXX")"
  missing_file="$(mktemp "${TMPDIR:-/tmp}/machete-editor-extensions.missing.XXXXXX")"
  extra_file="$(mktemp "${TMPDIR:-/tmp}/machete-editor-extensions.extra.XXXXXX")"

  { grep -Ev '^[[:space:]]*(#|$)' "${source_file}" || true; } | sort -u > "${expected_file}"
  "${editor_bin}" --list-extensions | sort -u > "${current_file}"
  comm -23 "${expected_file}" "${current_file}" > "${missing_file}"
  comm -13 "${expected_file}" "${current_file}" > "${extra_file}"

  if [[ ! -s "${missing_file}" && ! -s "${extra_file}" ]]; then
    echo "clean"
  else
    if [[ -s "${missing_file}" ]]; then
      sed 's/^/missing\t/' "${missing_file}"
    fi
    if [[ -s "${extra_file}" ]]; then
      sed 's/^/extra\t/' "${extra_file}"
    fi
  fi

  rm -f "${current_file}" "${expected_file}" "${missing_file}" "${extra_file}"
}
