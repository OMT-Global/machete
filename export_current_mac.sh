#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BREWFILE_PATH="${REPO_DIR}/Brewfile"
BREW_DUMP_FLAGS=(
  --describe
  --no-vscode
  --no-cargo
  --no-go
  --no-uv
  --no-flatpak
)

filter_brewfile() {
  local source_file="$1"
  local destination_file="$2"
  local filtered_file
  local referenced_taps_file
  filtered_file="$(mktemp "${TMPDIR:-/tmp}/mac-setup-brewfile.filtered.XXXXXX")"
  referenced_taps_file="$(mktemp "${TMPDIR:-/tmp}/mac-setup-brewfile.taps.XXXXXX")"
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

ensure_macos_defaults_file() {
  local defaults_file="${REPO_DIR}/macos-defaults.sh"

  if [[ -f "$defaults_file" ]]; then
    echo "==> Keeping existing macos-defaults.sh"
    return
  fi

  echo "==> Creating macos-defaults.sh template"
  cat > "$defaults_file" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Dock: auto-hide
defaults write com.apple.dock autohide -bool true

# Restart Dock & Finder to apply some settings
killall Dock Finder 2>/dev/null || true
EOF
  chmod +x "$defaults_file"
}

if command -v brew >/dev/null 2>&1; then
  echo "==> Exporting portable Homebrew packages to Brewfile"
  tmp_brewfile="$(mktemp "${TMPDIR:-/tmp}/mac-setup-brewfile.raw.XXXXXX")"
  HOMEBREW_NO_AUTO_UPDATE=1 brew bundle dump --file="$tmp_brewfile" --force "${BREW_DUMP_FLAGS[@]}"
  filter_brewfile "$tmp_brewfile" "$BREWFILE_PATH"
  rm -f "$tmp_brewfile"
else
  echo "Homebrew not found; skipping Brewfile export."
fi

ensure_macos_defaults_file

cat <<EOF

Done.

Refreshed automatically:
  - Brewfile

Review manually when needed:
  - dotfiles in $REPO_DIR
  - macos-defaults.sh

EOF
