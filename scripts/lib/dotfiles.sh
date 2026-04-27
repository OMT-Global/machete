#!/usr/bin/env bash

DEFAULT_TRACKED_DOTFILES=(
  .zshrc
  .zprofile
  .gitconfig
  .gitignore_global
  .vimrc
)

dotfiles_default_paths() {
  printf '%s\n' "${DEFAULT_TRACKED_DOTFILES[@]}"
}

dotfiles_list() {
  local dotfiles_dir="$1"

  if [[ -d "${dotfiles_dir}" ]]; then
    find "${dotfiles_dir}" -type f ! -name '.gitkeep' | sort
  fi
}

dotfiles_has_tracked_files() {
  local dotfiles_dir="$1"
  local first_file

  first_file="$(dotfiles_list "${dotfiles_dir}" | head -n 1 || true)"
  [[ -n "${first_file}" ]]
}

normalize_dotfile_path() {
  local path="$1"

  case "${path}" in
    \~/*) path="${path#~/}" ;;
    "${HOME}/"*) path="${path#${HOME}/}" ;;
    dotfiles/*) path="${path#dotfiles/}" ;;
  esac

  while [[ "${path}" == ./* ]]; do
    path="${path#./}"
  done

  if [[ -z "${path}" || "${path}" == "." || "${path}" == ".." || "${path}" == /* ]]; then
    return 1
  fi

  if [[ "${path}" == ../* || "${path}" == */../* || "${path}" == */.. ]]; then
    return 1
  fi

  printf '%s\n' "${path}"
}

dotfile_repo_path() {
  local dotfiles_dir="$1"
  local relative_path="$2"

  printf '%s/%s\n' "${dotfiles_dir}" "${relative_path}"
}

dotfile_home_path() {
  local relative_path="$1"

  printf '%s/%s\n' "${HOME}" "${relative_path}"
}

dotfile_resolve_symlink_target() {
  local link_path="$1"
  local target

  target="$(readlink "${link_path}")"
  if [[ "${target}" != /* ]]; then
    target="$(dirname "${link_path}")/${target}"
  fi

  printf '%s\n' "${target}"
}

dotfile_canonical_path() {
  local path="$1"
  local dir
  local base

  dir="$(dirname "${path}")"
  base="$(basename "${path}")"

  if [[ -d "${dir}" ]]; then
    (cd "${dir}" && printf '%s/%s\n' "$(pwd -P)" "${base}")
  else
    printf '%s\n' "${path}"
  fi
}

dotfile_paths_match() {
  local left_path="$1"
  local right_path="$2"

  [[ "$(dotfile_canonical_path "${left_path}")" == "$(dotfile_canonical_path "${right_path}")" ]]
}

dotfile_symlink_points_to_path() {
  local link_path="$1"
  local expected_path="$2"
  local target_path

  [[ -L "${link_path}" ]] || return 1
  target_path="$(dotfile_resolve_symlink_target "${link_path}")"
  dotfile_paths_match "${target_path}" "${expected_path}"
}

copy_home_dotfile_to_repo() {
  local dotfiles_dir="$1"
  local relative_path="$2"
  local source_path
  local destination_path

  source_path="$(dotfile_home_path "${relative_path}")"
  destination_path="$(dotfile_repo_path "${dotfiles_dir}" "${relative_path}")"

  mkdir -p "$(dirname "${destination_path}")"
  cp "${source_path}" "${destination_path}"
}

symlink_repo_dotfile_to_home() {
  local dotfiles_dir="$1"
  local relative_path="$2"
  local source_path
  local destination_path

  source_path="$(dotfile_repo_path "${dotfiles_dir}" "${relative_path}")"
  destination_path="$(dotfile_home_path "${relative_path}")"

  mkdir -p "$(dirname "${destination_path}")"
  ln -sfn "${source_path}" "${destination_path}"
}

remove_empty_parent_dirs() {
  local root_dir="$1"
  local target_path="$2"
  local current_dir

  current_dir="$(dirname "${target_path}")"
  while [[ "${current_dir}" != "${root_dir}" && "${current_dir}" != "." ]]; do
    rmdir "${current_dir}" 2>/dev/null || break
    current_dir="$(dirname "${current_dir}")"
  done
}
