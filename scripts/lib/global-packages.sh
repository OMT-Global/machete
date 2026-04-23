#!/usr/bin/env bash
set -euo pipefail

PACKAGES_DIR_DEFAULT_REL="packages"

packages_dir() {
  local repo_dir="$1"
  printf '%s/%s\n' "${repo_dir}" "${PACKAGES_DIR_DEFAULT_REL}"
}

npm_packages_file() {
  local repo_dir="$1"
  printf '%s/npm-global.txt\n' "$(packages_dir "${repo_dir}")"
}

pip_packages_file() {
  local repo_dir="$1"
  printf '%s/pip-global.txt\n' "$(packages_dir "${repo_dir}")"
}

cargo_packages_file() {
  local repo_dir="$1"
  printf '%s/cargo-global.txt\n' "$(packages_dir "${repo_dir}")"
}

write_list_file() {
  local target="$1"
  shift
  mkdir -p "$(dirname "${target}")"
  {
    for entry in "$@"; do
      if [[ -n "${entry}" ]]; then
        printf '%s\n' "${entry}"
      fi
    done
  } | LC_ALL=C sort -u > "${target}"
}

snapshot_npm_globals() {
  local repo_dir="$1"
  local target
  target="$(npm_packages_file "${repo_dir}")"

  if ! command -v npm >/dev/null 2>&1; then
    echo "  - npm not found; skipping npm global package snapshot."
    return 0
  fi

  local packages=()
  local package
  while IFS= read -r package; do
    [[ -n "${package}" ]] && packages+=("${package}")
  done < <(
    npm ls -g --depth=0 --parseable=true 2>/dev/null \
      | awk -F/ 'NR>1 {print $NF}' \
      | grep -v '^npm$' || true
  )
  write_list_file "${target}" "${packages[@]:-}"
  echo "  - npm globals -> ${target}"
}

snapshot_pip_globals() {
  local repo_dir="$1"
  local target
  target="$(pip_packages_file "${repo_dir}")"

  local pip_cmd=()
  if command -v pip3 >/dev/null 2>&1; then
    pip_cmd=(pip3)
  elif command -v pip >/dev/null 2>&1; then
    pip_cmd=(pip)
  elif command -v python3 >/dev/null 2>&1; then
    pip_cmd=(python3 -m pip)
  elif command -v python >/dev/null 2>&1; then
    pip_cmd=(python -m pip)
  else
    echo "  - pip not found; skipping pip global package snapshot."
    return 0
  fi

  local packages=()
  local package
  while IFS= read -r package; do
    [[ -n "${package}" ]] && packages+=("${package}")
  done < <(
    "${pip_cmd[@]}" list --user --format=freeze 2>/dev/null \
      | sed '/^$/d' || true
  )
  write_list_file "${target}" "${packages[@]:-}"
  echo "  - pip globals -> ${target}"
}

snapshot_cargo_globals() {
  local repo_dir="$1"
  local target
  target="$(cargo_packages_file "${repo_dir}")"

  if ! command -v cargo >/dev/null 2>&1; then
    echo "  - cargo not found; skipping cargo global package snapshot."
    return 0
  fi

  local packages=()
  local package
  while IFS= read -r package; do
    [[ -n "${package}" ]] && packages+=("${package}")
  done < <(
    cargo install --list 2>/dev/null \
      | awk '/^[^ ]+ v[0-9]/ {version=substr($2,2); sub(/:$/, "", version); print $1 "@" version}' || true
  )
  write_list_file "${target}" "${packages[@]:-}"
  echo "  - cargo globals -> ${target}"
}

restore_npm_globals() {
  local repo_dir="$1"
  local target
  target="$(npm_packages_file "${repo_dir}")"

  if [[ ! -f "${target}" ]]; then
    echo "  - No npm global snapshot found; skipping."
    return 0
  fi

  if ! command -v npm >/dev/null 2>&1; then
    echo "  - Warning: npm not found; skipping npm global restore."
    return 0
  fi

  local packages=()
  local package
  while IFS= read -r package; do
    [[ -n "${package}" ]] && packages+=("${package}")
  done < <(sed '/^$/d' "${target}")
  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "  - No npm globals recorded."
    return 0
  fi

  echo "  - Installing npm globals from ${target}"
  npm install -g "${packages[@]}"
}

restore_pip_globals() {
  local repo_dir="$1"
  local target
  target="$(pip_packages_file "${repo_dir}")"

  if [[ ! -f "${target}" ]]; then
    echo "  - No pip global snapshot found; skipping."
    return 0
  fi

  local pip_cmd=()
  if command -v pip3 >/dev/null 2>&1; then
    pip_cmd=(pip3)
  elif command -v pip >/dev/null 2>&1; then
    pip_cmd=(pip)
  elif command -v python3 >/dev/null 2>&1; then
    pip_cmd=(python3 -m pip)
  elif command -v python >/dev/null 2>&1; then
    pip_cmd=(python -m pip)
  else
    echo "  - Warning: pip not found; skipping pip global restore."
    return 0
  fi

  local packages=()
  local package
  while IFS= read -r package; do
    [[ -n "${package}" ]] && packages+=("${package}")
  done < <(sed '/^$/d' "${target}")
  if [[ ${#packages[@]} -eq 0 ]]; then
    echo "  - No pip globals recorded."
    return 0
  fi

  echo "  - Installing pip globals from ${target}"
  "${pip_cmd[@]}" install --user "${packages[@]}"
}

restore_cargo_globals() {
  local repo_dir="$1"
  local target
  target="$(cargo_packages_file "${repo_dir}")"

  if [[ ! -f "${target}" ]]; then
    echo "  - No cargo global snapshot found; skipping."
    return 0
  fi

  if ! command -v cargo >/dev/null 2>&1; then
    echo "  - Warning: cargo not found; skipping cargo global restore."
    return 0
  fi

  local line crate version
  local found=0
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    found=1
    crate="${line%@*}"
    version="${line##*@}"
    cargo install "${crate}" --version "${version}"
  done < "${target}"

  if [[ "${found}" -eq 0 ]]; then
    echo "  - No cargo globals recorded."
  else
    echo "  - Installed cargo globals from ${target}"
  fi
}

check_saved_vs_current() {
  local saved_file="$1"
  shift
  local current_cmd=("$@")
  local tmp
  tmp="$(mktemp)"
  if ! "${current_cmd[@]}" > "${tmp}" 2>/dev/null; then
    rm -f "${tmp}"
    return 2
  fi
  if diff -u "${saved_file}" "${tmp}" >/dev/null 2>&1; then
    rm -f "${tmp}"
    return 0
  fi
  rm -f "${tmp}"
  return 1
}
