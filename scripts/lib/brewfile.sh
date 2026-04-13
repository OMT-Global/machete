#!/usr/bin/env bash

brewfile_dump_flags=(
  --describe
  --no-vscode
  --no-cargo
  --no-go
  --no-uv
  --no-flatpak
)

brewfile_filter() {
  local source_file="$1"
  local destination_file="$2"
  local filtered_file
  local referenced_taps_file
  filtered_file="$(mktemp "${TMPDIR:-/tmp}/machete-brewfile.filtered.XXXXXX")"
  referenced_taps_file="$(mktemp "${TMPDIR:-/tmp}/machete-brewfile.taps.XXXXXX")"
  local line package tap pending_buffer
  pending_buffer=""

  while IFS= read -r line; do
    if [[ "$line" =~ ^brew\ \"([^\"]+)\" ]]; then
      package="${BASH_REMATCH[1]}"
      if [[ "$package" == local/* ]]; then
        continue
      fi
      if [[ "$package" == */*/* ]]; then
        tap="${package%/*}"
        if ! grep -Fxq "$tap" "$referenced_taps_file"; then
          printf '%s\n' "$tap" >> "$referenced_taps_file"
        fi
      fi
    fi
  done < "$source_file"

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$line" || "$line" == \#* ]]; then
      pending_buffer+="${line}"$'\n'
      continue
    fi

    local keep_line=1

    if [[ "$line" =~ ^tap\ \"([^\"]+)\" ]]; then
      tap="${BASH_REMATCH[1]}"
      if ! grep -Fxq "$tap" "$referenced_taps_file"; then
        keep_line=0
      fi
    elif [[ "$line" =~ ^brew\ \"([^\"]+)\" ]]; then
      package="${BASH_REMATCH[1]}"
      if [[ "$package" == local/* ]]; then
        keep_line=0
      fi
    fi

    if (( keep_line )); then
      printf '%s' "$pending_buffer" >> "$filtered_file"
      printf '%s\n' "$line" >> "$filtered_file"
    fi

    pending_buffer=""
  done < "$source_file"

  rm -f "$referenced_taps_file"
  mv "$filtered_file" "$destination_file"
}

brewfile_dump_filtered() {
  local destination_file="$1"
  local raw_file
  raw_file="$(mktemp "${TMPDIR:-/tmp}/machete-brewfile.raw.XXXXXX")"

  HOMEBREW_NO_AUTO_UPDATE=1 brew bundle dump --file="$raw_file" --force "${brewfile_dump_flags[@]}"
  brewfile_filter "$raw_file" "$destination_file"
  rm -f "$raw_file"
}
