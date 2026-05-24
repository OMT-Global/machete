/*
Package dotfiles handles dotfile tracking, symlink management, and portable
path filtering. Ported from scripts/lib/dotfiles.sh.

Key concepts:
  - A "dotfile" is a file in $HOME managed by machute and stored in dotfiles/
  - Tracking creates a symlink from $HOME/file -> dotfiles/file
  - Untracking removes the symlink and restores the original file
  - Portable paths are those safe to store in git (no .env, .ssh, secrets, etc.)
*/
package dotfiles
