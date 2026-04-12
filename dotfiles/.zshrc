
export PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/johnteneyckjr./.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions
export PATH="$HOME/Library/Python/3.10/bin:$PATH"

# Tooling quality-of-life
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

# Created by `pipx` on 2025-12-30 03:27:14
export PATH="$PATH:/Users/johnteneyckjr./.local/bin"

# Keep Brewfile up to date
brewup() {
  brew bundle dump --describe --force --file /Users/johnteneyckjr./src/mac-setup/Brewfile
}

# bun completions
[ -s "/Users/johnteneyckjr./.bun/_bun" ] && source "/Users/johnteneyckjr./.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
# codex-keychain-tokens
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

eval "$(starship init zsh)"
eval "$(fzf --zsh)"
neofetch
alias c="clear && neofetch"
alias tasks="glances"
alias gs="git status"
alias gc="git commit -m"
alias ..="cd .."
alias ...="cd ../.."
alias parrot="curl parrot.live"
alias weather="curl wttr.in"
alias screensaver="python3 -c 'from asciimatics.effects import Stars; from asciimatics.scene import Scene; from asciimatics.screen import Screen; Screen.wrapper(lambda s: s.play([Scene([Stars(s, 200)], 300)]))'"
