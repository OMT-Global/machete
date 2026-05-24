/*
Package machete provides the CLI root for the machete macOS setup tool.

machete is a swiss army knife for macOS setup and maintenance. It snapshots
your current Mac into Git, restores it on a new machine in one command,
and keeps everything in sync over time.

Usage:
    machete <command> [flags]

Commands:
    setup        Bootstrap a new Mac: Xcode tools, Homebrew, global packages, services, dotfiles, defaults
    snapshot     Export current state to the active profile or a --profile target
    schedule     Install a daily launchd agent that runs sync + update automatically
    track        Add one or more home-directory files to dotfiles/ and symlink them
    untrack      Remove one or more files from dotfiles/ and stop managing them
    uninstall    Teardown machete-managed home dotfile symlinks (dry-run or apply)
    services     Start Homebrew services listed in defaults/brew-services.txt
    history      List rollback snapshot tags, newest first
    rollback     Restore the latest snapshot tag and re-apply setup
    update       Upgrade all Homebrew packages and clean up
    doctor       Check what's installed, symlinked, and in sync for the active profile
    diff         Compare tracked dotfiles and Brewfile against the current machine
    sync         Pull latest repo changes and re-apply setup (idempotent)
    profile      List profiles or scaffold a new one
    defaults     Apply macOS system preferences or run interactive preset picker
    verify       Hash tracked files and compare against the checksum baseline
    audit        Scan home-directory files and report drift since the last baseline

This phase scaffolds the Go project structure. Subcommand implementations
will be populated in subsequent migration phases.
*/
package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

const (
	version = "v2.0.0-dev"
	name    = "machete"
	short   = "Swiss army knife for macOS setup and maintenance"
	long = `machete is a swiss army knife for macOS setup and maintenance.

It snapshots your current Mac into Git, restores it on a new machine in one
command, and keeps everything in sync over time.

For installation instructions and a full command reference, see:
    https://github.com/OMT-Global/machete
`
)

func main() {
	rootCmd := &cobra.Command{
		Use:   name,
		Short: short,
		Long:  long,
		// No PersistentPreRun - shell dispatch handled by machete script during migration.
		// Once fully ported, this will be replaced per-command logic.
	}
	rootCmd.SetVersionTemplate("machete " + version + "\n")
	rootCmd.AddCommand(versionCmd)
	rootCmd.AddCommand(stubCmd("setup", "Bootstrap a new Mac"))
	rootCmd.AddCommand(stubCmd("snapshot", "Export current state to the active profile"))
	rootCmd.AddCommand(stubCmd("schedule", "Install a daily launchd agent"))
	rootCmd.AddCommand(stubCmd("track", "Add files to dotfiles/ and symlink them"))
	rootCmd.AddCommand(stubCmd("untrack", "Remove files from dotfiles/ and stop managing"))
	rootCmd.AddCommand(stubCmd("uninstall", "Teardown machete-managed symlinks"))
	rootCmd.AddCommand(stubCmd("services", "Start Homebrew services from saved state"))
	rootCmd.AddCommand(stubCmd("history", "List rollback snapshot tags"))
	rootCmd.AddCommand(stubCmd("rollback", "Restore a snapshot tag and re-apply setup"))
	rootCmd.AddCommand(stubCmd("update", "Upgrade all Homebrew packages"))
	rootCmd.AddCommand(stubCmd("doctor", "Check installed, symlinked, and in-sync state"))
	rootCmd.AddCommand(stubCmd("diff", "Compare tracked files against current state"))
	rootCmd.AddCommand(stubCmd("sync", "Pull changes and re-apply setup"))
	rootCmd.AddCommand(stubCmd("profile", "List or scaffold machine profiles"))
	rootCmd.AddCommand(stubCmd("defaults", "Apply macOS system defaults"))
	rootCmd.AddCommand(stubCmd("verify", "Hash tracked files against checksum baseline"))
	rootCmd.AddCommand(stubCmd("audit", "Scan home directory for drift"))
	rootCmd.CompletionOptions.DisableDefaultCmd = true

	if err := rootCmd.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, "Error:", err)
		os.Exit(1)
	}
}

// versionCmd is the "machete version" subcommand.
var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the machete version",
	Long:  `Print the machete CLI version.`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println(version)
	},
}

// stubCmd creates a no-op cobra.Command that prints a "not yet implemented"
// message. Use this as a placeholder until full implementations are ported.
func stubCmd(name, description string) *cobra.Command {
	return &cobra.Command{
		Use:   name,
		Short: description,
		RunE: func(cmd *cobra.Command, args []string) error {
			_, _ = fmt.Fprintln(cmd.OutOrStdout(),
				fmt.Sprintf("[%s] not yet implemented (running shell backend)", name))
			_, _ = fmt.Fprintln(cmd.OutOrStdout(),
				"To run the shell backend: ./machete "+name)
			return nil
		},
	}
}
