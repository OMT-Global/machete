/*
Package commands holds all machete subcommand implementations.

Each command is a standalone .go file that implements a cobra.Command with
its flags, arguments, and execution logic. The command implements a specific
aspect of macOS setup and maintenance:

  - setup: Bootstrap a new Mac
  - snapshot: Export current machine state
  - schedule: Install daily launchd agent
  - track: Add files to dotfiles/ management
  - untrack: Remove files from dotfiles/ management
  - uninstall: Reverse machute-managed symlinks
  - services: Restore Homebrew services
  - history: List snapshot tags
  - rollback: Revert to a snapshot
  - update: Upgrade Homebrew packages
  - doctor: Health check the system
  - diff: Compare tracked files against current state
  - sync: Pull latest changes and re-apply setup
  - profile: Manage machine profiles
  - defaults: Apply macOS system defaults
  - verify: Check tracked file checksums
  - audit: Scan home directory for drift

Commands are registered in cmd/machute/main.go.
*/
package commands
