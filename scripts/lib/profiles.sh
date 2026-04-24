#!/usr/bin/env bash

MACHETE_DEFAULT_PROFILE="${MACHETE_DEFAULT_PROFILE:-default}"
MACHETE_BASE_PROFILE="${MACHETE_BASE_PROFILE:-base}"

global_active_profile_file() {
  printf '%s/.machete/profile\n' "${HOME}"
}

legacy_active_profile_file() {
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

base_profile_root_dir() {
  local repo_dir="$1"
  printf '%s/%s\n' "$(profiles_root_dir "${repo_dir}")" "${MACHETE_BASE_PROFILE}"
}

profile_exists() {
  local repo_dir="$1"
  local profile_name="$2"

  case "${profile_name}" in
    "${MACHETE_DEFAULT_PROFILE}")
      return 0
      ;;
    "${MACHETE_BASE_PROFILE}")
      [[ -d "$(base_profile_root_dir "${repo_dir}")" ]]
      ;;
    *)
      [[ -d "$(profiles_root_dir "${repo_dir}")/${profile_name}" ]]
      ;;
  esac
}

profile_require_existing() {
  local repo_dir="$1"
  local profile_name="$2"

  if profile_exists "${repo_dir}" "${profile_name}"; then
    return 0
  fi

  echo "Unknown profile: ${profile_name}" >&2
  echo "Create it with ./machete profile create ${profile_name} or select an existing profile." >&2
  return 1
}

profile_root_dir() {
  local repo_dir="$1"
  local profile_name="$2"

  case "${profile_name}" in
    "${MACHETE_DEFAULT_PROFILE}")
      printf '%s\n' "${repo_dir}"
      ;;
    "${MACHETE_BASE_PROFILE}")
      printf '%s\n' "$(base_profile_root_dir "${repo_dir}")"
      ;;
    *)
      printf '%s/%s\n' "$(profiles_root_dir "${repo_dir}")" "${profile_name}"
      ;;
  esac
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

profile_layer_roots() {
  local repo_dir="$1"
  local profile_name="$2"

  case "${profile_name}" in
    "${MACHETE_DEFAULT_PROFILE}")
      printf '%s\n' "${repo_dir}"
      ;;
    "${MACHETE_BASE_PROFILE}")
      if [[ -d "$(base_profile_root_dir "${repo_dir}")" ]]; then
        printf '%s\n' "$(base_profile_root_dir "${repo_dir}")"
      else
        printf '%s\n' "${repo_dir}"
      fi
      ;;
    *)
      if [[ -d "$(base_profile_root_dir "${repo_dir}")" ]]; then
        printf '%s\n' "$(base_profile_root_dir "${repo_dir}")"
      else
        printf '%s\n' "${repo_dir}"
      fi
      printf '%s\n' "$(profile_root_dir "${repo_dir}" "${profile_name}")"
      ;;
  esac
}

profile_layer_dotfiles_dirs() {
  local repo_dir="$1"
  local profile_name="$2"
  local layer_root

  while IFS= read -r layer_root; do
    printf '%s/dotfiles\n' "${layer_root}"
  done < <(profile_layer_roots "${repo_dir}" "${profile_name}")
}

profile_layer_brewfiles() {
  local repo_dir="$1"
  local profile_name="$2"
  local layer_root

  while IFS= read -r layer_root; do
    printf '%s/Brewfile\n' "${layer_root}"
  done < <(profile_layer_roots "${repo_dir}" "${profile_name}")
}

profile_collect_dotfiles() {
  local repo_dir="$1"
  local profile_name="$2"
  local dotfiles_dir
  local tracked_file
  local relative_path

  while IFS= read -r dotfiles_dir; do
    if [[ ! -d "${dotfiles_dir}" ]]; then
      continue
    fi

    while IFS= read -r tracked_file; do
      relative_path="${tracked_file#${dotfiles_dir}/}"
      printf '%s\t%s\n' "${relative_path}" "${tracked_file}"
    done < <(find "${dotfiles_dir}" -type f ! -name '.gitkeep' | sort)
  done < <(profile_layer_dotfiles_dirs "${repo_dir}" "${profile_name}") | \
    awk -F '\t' '{ paths[$1]=$2 } END { for (path in paths) printf "%s\t%s\n", path, paths[path] }' | sort
}

profile_dotfile_source_path() {
  local repo_dir="$1"
  local profile_name="$2"
  local relative_path="$3"
  local dotfiles_dir
  local candidate
  local source_path=""

  while IFS= read -r dotfiles_dir; do
    candidate="${dotfiles_dir}/${relative_path}"
    if [[ -f "${candidate}" ]]; then
      source_path="${candidate}"
    fi
  done < <(profile_layer_dotfiles_dirs "${repo_dir}" "${profile_name}")

  if [[ -n "${source_path}" ]]; then
    printf '%s\n' "${source_path}"
    return 0
  fi

  return 1
}

profile_write_merged_brewfile() {
  local repo_dir="$1"
  local profile_name="$2"
  local destination_file="$3"
  local brewfile_path

  mkdir -p "$(dirname "${destination_file}")"

  while IFS= read -r brewfile_path; do
    [[ -f "${brewfile_path}" ]] || continue
    cat "${brewfile_path}"
    printf '\n'
  done < <(profile_layer_brewfiles "${repo_dir}" "${profile_name}") | \
    awk '
      /^[[:space:]]*$/ {
        pending_blank=1
        next
      }
      {
        if (!seen[$0]++) {
          if (printed && pending_blank) {
            print ""
          }
          print
          printed=1
        }
        pending_blank=0
      }
    ' > "${destination_file}"
}

read_active_profile() {
  local repo_dir="$1"
  local active_file

  active_file="$(global_active_profile_file)"
  if [[ -f "${active_file}" ]]; then
    head -n 1 "${active_file}"
  elif [[ -f "$(legacy_active_profile_file "${repo_dir}")" ]]; then
    head -n 1 "$(legacy_active_profile_file "${repo_dir}")"
  else
    printf '%s\n' "${MACHETE_DEFAULT_PROFILE}"
  fi
}

write_active_profile() {
  local repo_dir="$1"
  local profile_name="$2"
  local active_file

  active_file="$(global_active_profile_file)"
  mkdir -p "$(dirname "${active_file}")"
  printf '%s\n' "${profile_name}" > "${active_file}"
  mkdir -p "$(dirname "$(legacy_active_profile_file "${repo_dir}")")"
  printf '%s\n' "${profile_name}" > "$(legacy_active_profile_file "${repo_dir}")"
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

  if ! profile_require_existing "${repo_dir}" "${profile_name}"; then
    if [[ -z "${explicit_profile}" ]]; then
      profile_name="${MACHETE_DEFAULT_PROFILE}"
    else
      return 1
    fi
  fi

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

  if [[ -d "$(base_profile_root_dir "${repo_dir}")" ]]; then
    profiles+=("${MACHETE_BASE_PROFILE}")
  fi

  if [[ -d "$(profiles_root_dir "${repo_dir}")" ]]; then
    while IFS= read -r profile_dir; do
      profile_name="$(basename "${profile_dir}")"
      [[ "${profile_name}" == "${MACHETE_BASE_PROFILE}" ]] && continue
      profiles+=("${profile_name}")
    done < <(find "$(profiles_root_dir "${repo_dir}")" -mindepth 1 -maxdepth 1 -type d | sort)
  fi

  printf '%s\n' "${profiles[@]}" | LC_ALL=C sort -u
}
