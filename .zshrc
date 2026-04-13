export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

if [ -d "$HOME/.docker/completions" ]; then
  fpath=("$HOME/.docker/completions" $fpath)
fi
autoload -Uz compinit
compinit

export PATH="$HOME/Library/Python/3.10/bin:$PATH"

if [ -f /opt/homebrew/opt/fzf/shell/completion.zsh ]; then
  source /opt/homebrew/opt/fzf/shell/completion.zsh
fi
if [ -f /opt/homebrew/opt/fzf/shell/key-bindings.zsh ]; then
  source /opt/homebrew/opt/fzf/shell/key-bindings.zsh
fi
eval "$(zoxide init zsh)"

alias cat="bat"
alias ls="eza"
alias ll="eza -l"
alias la="eza -a"
alias lla="eza -la"

export PATH="$PATH:$HOME/.local/bin"

macsetup_refresh() {
  local repo_dir="${MAC_SETUP_REPO_DIR:-$HOME/src/mac-setup}"
  "$repo_dir/export_current_mac.sh"
}

alias brewup='macsetup_refresh'

[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Load common API tokens from the macOS keychain when present.
if [[ -z "$FIGMA_ACCESS_TOKEN" ]]; then
  if figma_token="$(security find-generic-password -a "$USER" -s "FIGMA_ACCESS_TOKEN" -w 2>/dev/null)"; then
    export FIGMA_ACCESS_TOKEN="$figma_token"
  else
    echo "warning: FIGMA_ACCESS_TOKEN not found in keychain" >&2
  fi
  unset figma_token
fi
if [[ -z "$GITHUB_TOKEN" ]]; then
  if github_token="$(security find-generic-password -a "$USER" -s "GITHUB_TOKEN" -w 2>/dev/null)"; then
    export GITHUB_TOKEN="$github_token"
  else
    echo "warning: GITHUB_TOKEN not found in keychain" >&2
  fi
  unset github_token
fi
if [[ -z "$CONTEXT7_API_KEY" ]]; then
  if context7_api_key="$(security find-generic-password -a "$USER" -s "CONTEXT7_API_KEY" -w 2>/dev/null)"; then
    export CONTEXT7_API_KEY="$context7_api_key"
  else
    echo "warning: CONTEXT7_API_KEY not found in keychain" >&2
  fi
  unset context7_api_key
fi
