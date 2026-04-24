#!/usr/bin/env bash

if ! declare -F profile_brew_services_file >/dev/null 2>&1; then
  source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/profiles.sh"
fi

brew_services_state_file() {
  local profile_name="${MACHETE_PROFILE:-default}"
  echo "${MACHETE_BREW_SERVICES_FILE:-$(profile_brew_services_file "${REPO_DIR}" "${profile_name}")}"
}

brew_services_saved_names() {
  local services_file="$1"

  if [[ ! -f "${services_file}" ]]; then
    return 0
  fi

  sed -e 's/[[:space:]]*#.*$//' -e '/^[[:space:]]*$/d' "${services_file}"
}

brew_services_running_names() {
  brew services list 2>/dev/null | awk 'NR > 1 && $2 == "started" { print $1 }' | sort -u
}

brew_services_installed() {
  local service_name="$1"

  brew list --formula "${service_name}" >/dev/null 2>&1 ||
    brew list --cask "${service_name}" >/dev/null 2>&1
}

brew_services_snapshot() {
  local services_file="$1"
  local tmp_file

  mkdir -p "$(dirname "${services_file}")"
  tmp_file="$(mktemp "${TMPDIR:-/tmp}/machete-brew-services.XXXXXX")"

  if brew_services_running_names > "${tmp_file}"; then
    mv "${tmp_file}" "${services_file}"
    return 0
  fi

  rm -f "${tmp_file}"
  return 1
}

brew_services_restore() {
  local services_file="$1"
  local service_name
  local found=0

  if [[ ! -f "${services_file}" ]]; then
    echo "No defaults/brew-services.txt found; skipping Homebrew services."
    return 0
  fi

  while IFS= read -r service_name; do
    found=1

    if ! brew_services_installed "${service_name}"; then
      echo "  [!] ${service_name}: not installed; skipping."
      continue
    fi

    echo "  - Starting ${service_name}"
    if ! brew services start "${service_name}"; then
      echo "  [!] ${service_name}: failed to start; continuing."
    fi
  done < <(brew_services_saved_names "${services_file}")

  if [[ "${found}" -eq 0 ]]; then
    echo "No Homebrew services saved; nothing to start."
  fi
}

brew_services_saved_service_states() {
  local services_file="$1"
  local running_services
  local service_name

  running_services="$(brew_services_running_names || true)"

  while IFS= read -r service_name; do
    if ! brew_services_installed "${service_name}"; then
      printf 'missing\t%s\n' "${service_name}"
    elif grep -Fxq "${service_name}" <<<"${running_services}"; then
      printf 'running\t%s\n' "${service_name}"
    else
      printf 'stopped\t%s\n' "${service_name}"
    fi
  done < <(brew_services_saved_names "${services_file}")
}
