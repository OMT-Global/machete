#!/usr/bin/env bash

MACHETE_DEFAULT_PROFILE="${MACHETE_DEFAULT_PROFILE:-default}"

active_profile_file() {
  local repo_dir="$1"
  printf '%s/.machete/active-profile\n' "${repo_dir}"
}

profile_validate_name() {
  local profile_name="$1"

  [[ "${profile_name}" =~ ^[A-Za-z0-9._-]+$ ]]
}

profile_require_valid_name() {
  local profile_name="$1"

  if ! profile_validate_name "${profile_name}"; then
    echo "Invalid profile name: ${profile_name}" >&2
    echo "Use only letters, numbers, dots, dashes, and underscores." >&2
    return 1
  fi
}

profiles_root_dir() {
  local repo_dir="$1"
  printf '%s/profiles\n' "${repo_dir}"
}

profile_root_dir() {
  local repo_dir="$1"
  local profile_name="$2"

  if [[ "${profile_name}" == "${MACHETE_DEFAULT_PROFILE}" ]]; then
    printf '%s\n' "${repo_dir}"
  else
    printf '%s/%s\n' "$(profiles_root_dir "${repo_dir}")" "${profile_name}"
  fi
}

profile_dotfiles_dir() {
  local repo_dir="$1"
  local profile_name="$2"
  printf '%s/dotfiles\n' "$(profile_root_dir "${repo_dir}" "${profile_name}")"
}

profile_packages_dir() {
  local repo_dir="$1"
  local profile_name="$2"
  printf '%s/packages\n' "$(profile_root_dir "${repo_dir}" "${profile_name}")"
}

profile_defaults_dir() {
  local repo_dir="$1"
  local profile_name="$2"
  printf '%s/defaults\n' "$(profile_root_dir "${repo_dir}" "${profile_name}")"
}

profile_brewfile_path() {
  local repo_dir="$1"
  local profile_name="$2"
  printf '%s/Brewfile\n' "$(profile_root_dir "${repo_dir}" "${profile_name}")"
}

profile_defaults_script_path() {
  local repo_dir="$1"
  local profile_name="$2"
  printf '%s/macos-defaults.sh\n' "$(profile_defaults_dir "${repo_dir}" "${profile_name}")"
}

profile_brew_services_file() {
  local repo_dir="$1"
  local profile_name="$2"
  printf '%s/brew-services.txt\n' "$(profile_defaults_dir "${repo_dir}" "${profile_name}")"
}

profile_editor_extensions_file() {
  local repo_dir="$1"
  local profile_name="$2"
  printf '%s/vscode-extensions.txt\n' "$(profile_packages_dir "${repo_dir}" "${profile_name}")"
}

read_active_profile() {
  local repo_dir="$1"
  local active_file

  active_file="$(active_profile_file "${repo_dir}")"
  if [[ -f "${active_file}" ]]; then
    head -n 1 "${active_file}"
  else
    printf '%s\n' "${MACHETE_DEFAULT_PROFILE}"
  fi
}

write_active_profile() {
  local repo_dir="$1"
  local profile_name="$2"
  local active_file

  active_file="$(active_profile_file "${repo_dir}")"
  mkdir -p "$(dirname "${active_file}")"
  printf '%s\n' "${profile_name}" > "${active_file}"
}

resolve_profile() {
  local repo_dir="$1"
  local explicit_profile="${2:-}"
  local profile_name

  if [[ -n "${explicit_profile}" ]]; then
    profile_name="${explicit_profile}"
  else
    profile_name="$(read_active_profile "${repo_dir}")"
  fi

  if [[ -z "${profile_name}" ]]; then
    profile_name="${MACHETE_DEFAULT_PROFILE}"
  fi

  profile_require_valid_name "${profile_name}" || return 1

  if [[ -n "${explicit_profile}" ]]; then
    write_active_profile "${repo_dir}" "${profile_name}"
  fi

  printf '%s\n' "${profile_name}"
}

list_profiles() {
  local repo_dir="$1"
  local active_profile
  local profiles=("${MACHETE_DEFAULT_PROFILE}")
  local profile_dir
  local profile_name

  active_profile="$(read_active_profile "${repo_dir}")"
  if [[ -n "${active_profile}" && "${active_profile}" != "${MACHETE_DEFAULT_PROFILE}" ]]; then
    profiles+=("${active_profile}")
  fi

  if [[ -d "$(profiles_root_dir "${repo_dir}")" ]]; then
    while IFS= read -r profile_dir; do
      profile_name="$(basename "${profile_dir}")"
      profiles+=("${profile_name}")
    done < <(find "$(profiles_root_dir "${repo_dir}")" -mindepth 1 -maxdepth 1 -type d | sort)
  fi

  printf '%s\n' "${profiles[@]}" | LC_ALL=C sort -u
}
