export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

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
if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
eval "$(zoxide init zsh)"

alias cat="bat"
alias ls="eza"
alias ll="eza -l"
alias la="eza -a"
alias lla="eza -la"
alias tasks="glances"
alias gs="git status"
alias gc="git commit -m"
alias ..="cd .."
alias ...="cd ../.."
alias weather="curl wttr.in"

export PATH="$PATH:$HOME/.local/bin"

macsetup_refresh() {
  local repo_dir="${MAC_SETUP_REPO_DIR:-$HOME/src/mac-setup}"
  "$repo_dir/export_current_mac.sh"
}

alias brewup='macsetup_refresh'

[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
