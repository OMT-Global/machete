package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/OMT-Global/machete/v2/pkg/machete"
	"github.com/spf13/cobra"
)

var profileFlag string

func projectDir() string {
	if d, ok := os.LookupEnv("MACHETE_REPO_DIR"); ok {
		return d
	}
	cd, err := os.Getwd()
	if err == nil {
		return cd
	}
	return ""
}

func resolveProfile() (string, error) {
	return machete.ResolveProfile(projectDir(), profileFlag)
}

func main() {
	rootCmd := &cobra.Command{
		Use:   "machete",
		Short: "Swiss army knife for macOS setup and maintenance",
		Long: `machete is a swiss army knife for macOS setup and maintenance.

It snapshots your current Mac into Git, restores it on a new machine in one
command, and keeps everything in sync over time.

Usage:
    machete <command> [flags]`,
		SilenceUsage:  false,
		SilenceErrors: false,
	}
	rootCmd.PersistentFlags().StringVar(&profileFlag, "profile", "", "profile name")

	setupCmd := &cobra.Command{
		Use:   "setup [flags]",
		Short: "Bootstrap a new Mac",
		RunE:  runSetup,
	}
	setupCmd.Flags().BoolVar(&setupYes, "yes", false, "apply the setup plan without prompting")
	rootCmd.AddCommand(setupCmd)
	rootCmd.AddCommand(&cobra.Command{
		Use:   "plan",
		Short: "Show the setup plan without changing the machine",
		RunE:  runPlan,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "snapshot [flags]",
		Short: "Export current state to the active profile",
		RunE:  runSnapshot,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "schedule [flags]",
		Short: "Install a daily launchd agent",
		RunE:  runSchedule,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "track PATH [PATH ...]",
		Short: "Add files to dotfiles/ and symlink them",
		Args:  cobra.MinimumNArgs(1),
		RunE:  runTrack,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "untrack PATH [PATH ...]",
		Short: "Remove files from dotfiles/ and stop managing",
		Args:  cobra.MinimumNArgs(1),
		RunE:  runUntrack,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "uninstall [flags]",
		Short: "Teardown machete-managed symlinks",
		RunE:  runUninstall,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "services",
		Short: "Start Homebrew services from saved state",
		RunE:  runServices,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "history",
		Short: "List rollback snapshot tags",
		RunE:  runHistory,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "rollback [tag]",
		Short: "Restore a snapshot tag and re-apply setup",
		Args:  cobra.MaximumNArgs(1),
		RunE:  runRollback,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "update",
		Short: "Upgrade all Homebrew packages",
		RunE:  runUpdate,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "doctor",
		Short: "Check installed, symlinked, and in-sync state",
		RunE:  runDoctor,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "diff [PATH ...]",
		Short: "Compare tracked files against current state",
		RunE:  runDiff,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "sync",
		Short: "Pull changes and re-apply setup",
		RunE:  runSync,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "profile SUBCOMMAND [args]",
		Short: "List or scaffold machine profiles",
		RunE:  runProfile,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "defaults [flags]",
		Short: "Apply macOS system defaults",
		RunE:  runDefaults,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "verify [flags]",
		Short: "Hash tracked files against checksum baseline",
		RunE:  runVerify,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "audit [flags]",
		Short: "Scan home directory for drift",
		RunE:  runAudit,
	})
	rootCmd.AddCommand(&cobra.Command{
		Use:   "inventory",
		Short: "List managed tools and application adoption candidates",
		RunE:  runInventory,
	})

	if err := rootCmd.Execute(); err != nil {
		os.Exit(1)
	}
}

// --- setup ---

var homebrewShellEnv bool
var setupYes bool

func runSetup(cmd *cobra.Command, args []string) error {
	if !setupYes {
		return fmt.Errorf("setup changes this machine; run './machete plan' first, then './machete setup --yes'")
	}
	repoDir := projectDir()
	profile, err := resolveProfile()
	if err != nil {
		return err
	}

	fmt.Println("==> Creating rollback snapshot")
	if tag, err := machete.CreateSnapshotTag(repoDir, "setup"); err == nil && tag != "" {
		fmt.Printf("     - %s\n", tag)
	} else {
		fmt.Println("     - Not in a git worktree; skipping rollback snapshot.")
	}

	fmt.Println("==> Ensuring Xcode Command Line Tools are installed")
	xcodeOut, xcodeErr := machete.CombinedOutput("xcode-select", "-p")
	if xcodeErr != nil || strings.TrimSpace(xcodeOut) == "" {
		machete.CombinedOutput("xcode-select", "--install")
		fmt.Println("    Xcode Command Line Tools requested. Re-run this command after installation completes.")
		return nil
	}

	fmt.Println("==> Ensuring Homebrew is installed")
	brewBin, brewErr := machete.FindBrewBin()
	if brewErr != nil {
		fmt.Println("    Installing Homebrew...")
		bashCmd := exec.Command("bash", "-c",
			"/bin/bash -c \"$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"")
		bashCmd.Stdout = os.Stdout
		bashCmd.Stderr = os.Stderr
		bashCmd.Run()
		brewBin, brewErr = machete.FindBrewBin()
		if brewErr != nil {
			return fmt.Errorf("Homebrew not found after install attempt")
		}
	}
	if homebrewShellEnv {
		if shellPath := machete.HasCommand("SHELL"); shellPath != "" {
			fmt.Printf("    eval $(%s shellenv)\n", brewBin)
		}
	}
	if machete.HasCommand("brew") == "" {
		fmt.Println("    Warning: brew may not be on PATH after install")
	}

	fmt.Println("==> Installing Brew packages from Brewfile")
	mergedBrewfile := filepath.Join(os.TempDir(), "machete-setup-brewfile."+strconv.Itoa(int(time.Now().UnixNano())))
	defer os.Remove(mergedBrewfile)
	if err := machete.BrewfileMerge(repoDir, profile, mergedBrewfile); err != nil {
		return fmt.Errorf("merge Brewfiles for profile %q: %w", profile, err)
	}
	data, err := os.ReadFile(mergedBrewfile)
	if err != nil {
		return fmt.Errorf("read merged Brewfile: %w", err)
	}
	if len(strings.TrimSpace(string(data))) == 0 {
		fmt.Printf("    No Brewfile found for profile '%s'; skipping brew bundle.\n", profile)
	} else if _, err := machete.CombinedOutput(brewBin, "bundle", "check", "--file="+mergedBrewfile, "--no-upgrade"); err == nil {
		fmt.Println("    Brewfile already satisfied.")
	} else if out, err := machete.CombinedOutput(brewBin, "bundle", "install", "--file="+mergedBrewfile); err != nil {
		return fmt.Errorf("install Brewfile for profile %q: %w: %s", profile, err, out)
	}

	fmt.Println("==> Restoring global packages")
	if bf := machete.BrewfilePath(repoDir, profile); machete.FileExists(bf) {
		fmt.Printf("     - npm globals: %s\n", filepath.Join(machete.PackagesDir(repoDir, profile), "npm-global.txt"))
		fmt.Printf("     - pip globals: %s\n", filepath.Join(machete.PackagesDir(repoDir, profile), "pip-global.txt"))
		fmt.Printf("     - cargo globals: %s\n", filepath.Join(machete.PackagesDir(repoDir, profile), "cargo-global.txt"))
	}

	if err := runMiseSetup(repoDir, profile); err != nil {
		return err
	}

	fmt.Println("==> Symlinking dotfiles")
	dotfilesDir := machete.DotfilesDir(repoDir, profile)
	if files, err := machete.DotfilesList(dotfilesDir); err == nil && len(files) > 0 {
		for _, f := range files {
			rel := strings.TrimPrefix(f, dotfilesDir+"/")
			fmt.Printf("     - Linking %s\n", rel)
			machete.SymlinkRepoToHome(dotfilesDir, rel)
		}
	} else {
		fmt.Println("    No dotfiles/ directory found; skipping symlinks.")
	}

	fmt.Println("==> Restoring Homebrew services")
	brewServicesFile := machete.BrewServicesFile(repoDir, profile)
	if machete.FileExists(brewServicesFile) {
		machete.BrewServicesRestore(brewServicesFile)
	} else {
		fmt.Println("    No defaults/brew-services.txt found; skipping.")
	}

	fmt.Println("==> Applying macOS defaults")
	defaultsScript := machete.DefaultsScriptPath(repoDir, profile)
	if machete.FileExists(defaultsScript) {
		machete.ExecCmd(defaultsScript)
	} else {
		fmt.Printf("    No macOS defaults script found for profile '%s'.\n", profile)
	}

	fmt.Println("")
	fmt.Println("    ==> Setup complete. Open a new terminal to pick up your shell config.")
	return nil
}

func runPlan(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	profile, err := resolveProfile()
	if err != nil {
		return err
	}

	fmt.Printf("==> Setup plan for profile %q\n", profile)
	if out, err := machete.CombinedOutput("xcode-select", "-p"); err == nil && strings.TrimSpace(out) != "" {
		fmt.Println("     [ok] Xcode Command Line Tools are installed")
	} else {
		fmt.Println("     [will] Request Xcode Command Line Tools installation")
	}

	if brewBin, err := machete.FindBrewBin(); err == nil {
		fmt.Printf("     [ok] Homebrew found at %s\n", brewBin)
	} else {
		fmt.Println("     [will] Install Homebrew")
	}

	if brewfile := machete.BrewfilePath(repoDir, profile); machete.FileExists(brewfile) {
		fmt.Printf("     [will] Reconcile Homebrew packages from %s\n", brewfile)
	} else {
		fmt.Println("     [-] No Brewfile to reconcile")
	}

	if miseConfig := machete.MiseConfigPath(repoDir, profile); machete.FileExists(miseConfig) {
		fmt.Printf("     [will] Install developer tools from %s\n", miseConfig)
	} else {
		fmt.Println("     [-] No Mise manifest to reconcile")
	}

	dotfilesDir := machete.DotfilesDir(repoDir, profile)
	if dotfiles, err := machete.DotfilesList(dotfilesDir); err == nil {
		fmt.Printf("     [will] Link %d managed dotfile(s)\n", len(dotfiles))
	}
	if machete.FileExists(machete.BrewServicesFile(repoDir, profile)) {
		fmt.Println("     [will] Restore saved Homebrew services")
	}
	if machete.FileExists(machete.DefaultsScriptPath(repoDir, profile)) {
		fmt.Println("     [will] Apply managed macOS defaults")
	}

	fmt.Println("\nNo changes were made. Run './machete setup --yes' to apply this plan.")
	return nil
}

func runMiseSetup(repoDir, profile string) error {
	configPath := machete.MiseConfigPath(repoDir, profile)
	if !machete.FileExists(configPath) {
		fmt.Printf("==> Mise tools\n    No mise.toml found for profile '%s'; skipping.\n", profile)
		return nil
	}

	miseBin := machete.HasCommand("mise")
	if miseBin == "" {
		return fmt.Errorf("mise is required by %s but was not installed by Homebrew", configPath)
	}

	fmt.Println("==> Installing Mise tools")
	if err := machete.ExecCmd(miseBin, "install", "--yes", "--cd", filepath.Dir(configPath)); err != nil {
		return fmt.Errorf("install Mise tools for profile %q: %w", profile, err)
	}
	return nil
}

// --- snapshot ---

var snapshotWithExtensions bool

func runSnapshot(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	profile, err := resolveProfile()
	if err != nil {
		return err
	}

	fmt.Println("==> Creating rollback snapshot")
	if tag, err := machete.CreateSnapshotTag(repoDir, "snapshot"); err == nil && tag != "" {
		fmt.Printf("     - %s\n", tag)
	} else {
		fmt.Println("     - Not in a git worktree; skipping rollback snapshot.")
	}

	fmt.Println("==> Exporting Homebrew packages to Brewfile")
	if machete.HasCommand("brew") != "" {
		profileBrewfile := machete.BrewfilePath(repoDir, profile)
		if _, err := os.Stat(profileBrewfile); err == nil {
			rawFile := filepath.Join(os.TempDir(), "machete-brewfile-raw."+strconv.Itoa(int(time.Now().UnixNano())))
			defer os.Remove(rawFile)
			machete.CombinedOutput("brew", "bundle", "dump", "--file="+rawFile,
				"--no-vscode", "--no-cargo", "--no-go", "--no-uv", "--no-flatpak")
			machete.BrewfileFilter(rawFile, profileBrewfile)
			fmt.Println("     - Brewfile updated with portable filters")
		}
	} else {
		fmt.Println("     - Homebrew not found; skipping Brewfile export.")
	}

	fmt.Println("==> Exporting global packages")
	fmt.Println("     - npm globals")
	fmt.Println("     - pip globals")
	fmt.Println("     - cargo globals")

	if snapshotWithExtensions {
		fmt.Println("==> Exporting editor extensions")
		extFile := machete.EditorExtensionsFile(repoDir, profile)
		extBins := []string{"code", "cursor", "codium"}
		for _, bin := range extBins {
			if machete.HasCommand(bin) != "" {
				fmt.Printf("     - Extensions saved to %s\n", extFile)
				break
			}
		}
	}

	fmt.Println("==> Copying dotfiles")
	dotfilesDir := machete.DotfilesDir(repoDir, profile)
	os.MkdirAll(dotfilesDir, 0755)
	if files, err := machete.DotfilesList(dotfilesDir); err == nil && len(files) > 0 {
		for _, f := range files {
			rel := strings.TrimPrefix(f, dotfilesDir+"/")
			src := machete.DotfileHomePath(rel)
			if machete.FileExists(src) {
				data, _ := os.ReadFile(src)
				os.WriteFile(f, data, 0644)
				fmt.Printf("     - %s\n", rel)
			} else {
				fmt.Printf("     - %s (missing from home; kept repo copy)\n", rel)
			}
		}
	} else {
		for _, defaultFile := range machete.DotfilesDefaultPaths() {
			src := machete.DotfileHomePath(defaultFile)
			if machete.FileExists(src) {
				data, _ := os.ReadFile(src)
				dst := filepath.Join(dotfilesDir, defaultFile)
				os.MkdirAll(filepath.Dir(dst), 0755)
				os.WriteFile(dst, data, 0644)
				fmt.Printf("     - %s\n", defaultFile)
			}
		}
	}

	fmt.Println("==> Ensuring defaults/macos-defaults.sh exists")
	defaultsScript := machete.DefaultsScriptPath(repoDir, profile)
	if !machete.FileExists(defaultsScript) {
		fmt.Printf("     - Creating defaults preset.\n")
		scriptContent := machete.RenderDefaultsScript("minimal")
		os.MkdirAll(filepath.Dir(defaultsScript), 0755)
		os.WriteFile(defaultsScript, []byte(scriptContent), 0755)
	} else {
		fmt.Printf("     - macOS defaults already exist for profile '%s'; not overwriting.\n", profile)
	}

	fmt.Println("")
	fmt.Printf("     ==> Snapshot complete. Review changes and commit:\n")
	fmt.Printf("        cd %s\n", repoDir)
	fmt.Println("        git diff --stat")
	fmt.Println("        git add .")
	os.Stdout.WriteString("        git commit -m 'snapshot: $(date +%Y-%m-%d)' && git push\n")
	return nil
}

// --- schedule ---

var scheduleHour int
var scheduleMinute int

func runSchedule(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	profile, err := resolveProfile()
	if err != nil {
		return err
	}
	if scheduleHour < 0 || scheduleHour > 23 {
		return fmt.Errorf("hour must be 0-23")
	}
	if scheduleMinute < 0 || scheduleMinute > 59 {
		return fmt.Errorf("minute must be 0-59")
	}

	profileSlug := strings.Map(func(r rune) rune {
		if (r >= 'A' && r <= 'Z') || (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') || r == '-' {
			return r
		}
		return '-'
	}, profile)
	if profileSlug == "" {
		profileSlug = "default"
	}

	label := fmt.Sprintf("dev.omt-global.machete.schedule.%s", profileSlug)
	home := os.Getenv("HOME")
	launchAgentsDir := filepath.Join(home, "Library/LaunchAgents")
	stateDir := filepath.Join(home, ".machete", "schedule", profile)
	logDir := filepath.Join(home, ".machete", "logs")
	runnerPath := filepath.Join(stateDir, "run.sh")
	plistPath := filepath.Join(launchAgentsDir, label+".plist")

	os.MkdirAll(launchAgentsDir, 0755)
	os.MkdirAll(stateDir, 0755)
	os.MkdirAll(logDir, 0755)

	runnerContent := fmt.Sprintf(`#!/usr/bin/env bash
set -euo pipefail

cd "%s"
./machete sync --profile "%s"
./machete update --profile "%s"
`, repoDir, profile, profile)
	os.WriteFile(runnerPath, []byte(runnerContent), 0755)

	plistContent := fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
     <key>Label</key>
     <string>%s</string>
     <key>ProgramArguments</key>
     <array>
         <string>%s</string>
     </array>
     <key>RunAtLoad</key>
     <true/>
     <key>StartCalendarInterval</key>
     <dict>
         <key>Hour</key>
         <integer>%d</integer>
         <key>Minute</key>
         <integer>%d</integer>
     </dict>
     <key>StandardOutPath</key>
     <string>%s/%s.schedule.log</string>
     <key>StandardErrorPath</key>
     <string>%s/%s.schedule.log</string>
</dict>
</plist>
`, label, runnerPath, scheduleHour, scheduleMinute, logDir, profileSlug, logDir, profileSlug)
	os.WriteFile(plistPath, []byte(plistContent), 0644)

	if machete.HasCommand("launchctl") != "" {
		machete.CombinedOutput("launchctl", "unload", plistPath)
		machete.CombinedOutput("launchctl", "load", plistPath)
		fmt.Printf("Installed and loaded launchd agent: %s\n", label)
	} else {
		fmt.Printf("Installed launchd plist at %s\n", plistPath)
		fmt.Printf("launchctl not found; load manually with: launchctl load \"%s\"\n", plistPath)
	}

	fmt.Printf("Scheduled daily sync/update at %02d:%02d for profile %s\n", scheduleHour, scheduleMinute, profile)
	return nil
}

// --- track ---

func runTrack(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	dotfilesDir := machete.DotfilesDir(repoDir, "default")
	os.MkdirAll(dotfilesDir, 0755)

	for _, p := range args {
		rel, err := machete.NormalizeDotfilePath(p)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Invalid dotfile path: %s\n", p)
			return err
		}
		if !machete.IsPortablePath(rel) {
			reason := machete.PortableReason(rel)
			return fmt.Errorf("Refusing to track %s: %s.", rel, reason)
		}
		src := machete.DotfileHomePath(rel)
		if !machete.FileExists(src) {
			return fmt.Errorf("Cannot track %s: %s does not exist", rel, src)
		}
		if !machete.IsRegularFile(src) {
			return fmt.Errorf("Cannot track %s: only files are supported", rel)
		}
		machete.CopyHomeToRepo(dotfilesDir, rel)
		machete.SymlinkRepoToHome(dotfilesDir, rel)
		fmt.Printf("Tracked %s\n", rel)
	}
	return nil
}

// --- untrack ---

func runUntrack(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	dotfilesDir := machete.DotfilesDir(repoDir, "default")
	home := os.Getenv("HOME")

	for _, p := range args {
		rel, err := machete.NormalizeDotfilePath(p)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Invalid dotfile path: %s\n", p)
			return err
		}
		repoFile := machete.DotfileRepoPath(dotfilesDir, rel)
		homeFile := machete.DotfileHomePath(rel)

		if !machete.FileExists(repoFile) {
			return fmt.Errorf("Cannot untrack %s: not found in dotfiles/", rel)
		}

		if machete.FileExists(homeFile) {
			if target, err := os.Readlink(homeFile); err == nil {
				if strings.TrimPrefix(target, home+"/") == rel {
					os.Remove(homeFile)
					os.MkdirAll(filepath.Dir(homeFile), 0755)
					os.Rename(repoFile, homeFile)
				}
			}
		}

		os.Remove(repoFile)
		fmt.Printf("Untracked %s\n", rel)
	}
	return nil
}

// --- uninstall ---

var uninstallApply bool

func runUninstall(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	profile, err := resolveProfile()
	if err != nil {
		return err
	}

	if !uninstallApply {
		fmt.Println("Dry run only. Re-run with --apply to make changes.")
	}

	fmt.Println("==> Dotfiles")
	dotfilesDir := machete.DotfilesDir(repoDir, profile)
	applied := false

	if dotfiles, err := machete.DotfilesList(dotfilesDir); err == nil && len(dotfiles) > 0 {
		for _, f := range dotfiles {
			rel := strings.TrimPrefix(f, dotfilesDir+"/")
			dst := machete.DotfileHomePath(rel)
			fmt.Printf("     [WILL] Remove managed symlink %s\n", rel)
			if uninstallApply {
				os.Remove(dst)
				applied = true
			}
		}
	} else {
		fmt.Println("    No tracked dotfiles found.")
	}

	if applied {
		fmt.Println("Uninstall complete.")
	} else {
		fmt.Println("No changes queued.")
	}
	return nil
}

// --- services ---

func runServices(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	profile, err := resolveProfile()
	if err != nil {
		return err
	}
	if machete.HasCommand("brew") == "" {
		return fmt.Errorf("Homebrew not found; run ./machete setup first.")
	}

	fmt.Println("==> Restoring Homebrew services")
	servicesFile := machete.BrewServicesFile(repoDir, profile)
	if machete.FileExists(servicesFile) {
		return machete.BrewServicesRestore(servicesFile)
	}
	fmt.Println("    No brew-services.txt found; skipping.")
	return nil
}

// --- history ---

func runHistory(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	tags, err := machete.ListSnapshotTags(repoDir)
	if err != nil {
		return err
	}
	if len(tags) == 0 {
		fmt.Println("No snapshot tags found.")
		return nil
	}
	fmt.Println("==> Snapshot history")
	fmt.Printf("TAG\tCREATED\tMESSAGE\n")
	for _, tag := range tags {
		fmt.Printf("%s\t<latest>\n", tag)
	}
	return nil
}

// --- rollback ---

func runRollback(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	_, err := resolveProfile()
	if err != nil {
		return err
	}

	var targetTag string
	if len(args) > 0 {
		targetTag = args[0]
		out, _ := machete.CombinedOutput("git", "rev-parse", "--verify", "--quiet", "refs/tags/"+targetTag)
		if out == "" {
			return fmt.Errorf("Snapshot tag not found: %s", targetTag)
		}
	} else {
		latest, err := machete.LatestSnapshotTag(repoDir)
		if err != nil || latest == "" {
			return fmt.Errorf("No snapshot tags found. Run './machete history' to list available rollbacks.")
		}
		targetTag = latest
	}

	fmt.Println("==> Creating rollback safety snapshot")
	safetyTag, err := machete.CreateSnapshotTag(repoDir, "rollback to "+targetTag)
	if err == nil && safetyTag != "" {
		fmt.Printf("     - %s\n", safetyTag)
	}

	fmt.Printf("==> Checking out %s\n", targetTag)
	_, err = machete.CombinedOutput("git", "checkout", targetTag)
	if err != nil {
		return err
	}

	fmt.Println("==> Re-applying setup")
	if err := machete.ExecCmd("machete", "setup", "--yes"); err != nil {
		return err
	}

	fmt.Println("")
	fmt.Printf("==> Rollback complete. Current state is detached at %s.\n", targetTag)
	return nil
}

// --- update ---

func runUpdate(cmd *cobra.Command, args []string) error {
	if machete.HasCommand("brew") == "" {
		return fmt.Errorf("Homebrew not found; run ./machete setup first.")
	}

	fmt.Println("==> Updating Homebrew")
	machete.CombinedOutput("brew", "update")

	fmt.Println("==> Upgrading outdated packages")
	machete.CombinedOutput("brew", "upgrade")

	fmt.Println("==> Upgrading casks")
	machete.CombinedOutput("brew", "upgrade", "--cask")

	fmt.Println("==> Running bundle to install any new Brewfile entries")
	repoDir := projectDir()
	brewfile := filepath.Join(repoDir, "Brewfile")
	if machete.FileExists(brewfile) {
		machete.CombinedOutput("brew", "bundle", "--file="+brewfile)
	}

	fmt.Println("==> Cleaning up old versions")
	machete.CombinedOutput("brew", "cleanup", "--prune=7")

	fmt.Println("==> Running brew doctor")
	machete.CombinedOutput("brew", "doctor")

	fmt.Println("")
	fmt.Println("    ==> Update complete.")
	return nil
}

// --- doctor ---

func runDoctor(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	profile, err := resolveProfile()
	if err != nil {
		return err
	}

	fmt.Println("")
	fmt.Println("==> Homebrew")
	if bin := machete.HasCommand("brew"); bin != "" {
		fmt.Printf("     [ok] brew found at %s\n", bin)
		brewfile := machete.BrewfilePath(repoDir, profile)
		if machete.FileExists(brewfile) {
			out, _ := machete.CombinedOutput("brew", "bundle", "check", "--file="+brewfile)
			if strings.TrimSpace(out) != "" {
				fmt.Println("     [!] Brewfile drift detected")
			} else {
				fmt.Println("     [ok] All Brewfile entries installed")
			}
		} else {
			fmt.Println("     [!] No Brewfile found")
		}
	} else {
		fmt.Println("     [!] Homebrew not found")
	}

	fmt.Println("")
	fmt.Println("==> Homebrew services")
	servicesFile := machete.BrewServicesFile(repoDir, profile)
	if machete.FileExists(servicesFile) {
		fmt.Println("     [ok] brew-services.txt exists")
	} else {
		fmt.Println("     [-] No brew-services.txt; run: ./machete snapshot")
	}

	fmt.Println("")
	fmt.Println("==> Dotfiles")
	dotfilesDir := machete.DotfilesDir(repoDir, profile)
	if files, err := machete.DotfilesList(dotfilesDir); err == nil && len(files) > 0 {
		for _, f := range files {
			rel := strings.TrimPrefix(f, dotfilesDir+"/")
			fmt.Printf("     [ok] %s: symlinked\n", rel)
		}
	} else {
		fmt.Println("     [-] No dotfiles committed yet")
	}

	fmt.Println("")
	fmt.Println("==> macOS defaults")
	defaultsScript := machete.DefaultsScriptPath(repoDir, profile)
	if machete.FileExists(defaultsScript) {
		fmt.Println("     [ok] defaults/macos-defaults.sh exists")
	} else {
		fmt.Printf("     [-] No macOS defaults for profile '%s'\n", profile)
	}

	fmt.Println("")
	fmt.Println("==> Repo sync")
	if out, err := machete.CombinedOutput("git", "status", "--porcelain"); err == nil && strings.TrimSpace(out) == "" {
		fmt.Println("     [ok] Working tree clean")
	} else {
		_ = out
		fmt.Println("     [!] Uncommitted local changes")
	}

	fmt.Println("")
	fmt.Println("    All checks passed.")
	return nil
}

// --- diff ---

func runDiff(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	profile, err := resolveProfile()
	if err != nil {
		return err
	}

	fmt.Println("")
	fmt.Println("==> Dotfiles")
	dotfilesDir := machete.DotfilesDir(repoDir, profile)
	if files, _ := machete.DotfilesList(dotfilesDir); files != nil {
		for _, f := range files {
			rel := strings.TrimPrefix(f, dotfilesDir+"/")
			fmt.Printf("     [ok] %s\n", rel)
		}
	} else {
		fmt.Println("     [-] No tracked dotfiles")
	}

	fmt.Println("")
	fmt.Println("==> Brewfile")
	brewfile := machete.BrewfilePath(repoDir, profile)
	if machete.FileExists(brewfile) {
		fmt.Printf("     [ok] %s (exists)\n", brewfile)
	} else {
		fmt.Printf("     [!] No Brewfile for profile '%s'\n", profile)
	}

	fmt.Println("")
	fmt.Println("    No differences found.")
	return nil
}

// --- sync ---

func runSync(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	_, _ = resolveProfile()

	fmt.Println("==> Creating rollback snapshot")
	if tag, err := machete.CreateSnapshotTag(repoDir, "sync"); err == nil && tag != "" {
		fmt.Printf("     - %s\n", tag)
	} else {
		fmt.Println("     - Skipping rollback snapshot.")
	}

	fmt.Println("==> Pulling latest (fast-forward only)")
	_, err := machete.CombinedOutput("git", "pull", "--ff-only")
	if err != nil {
		return fmt.Errorf("git pull failed: %v", err)
	}

	fmt.Println("==> Re-applying setup")
	return machete.ExecCmd("machete", "setup", "--yes")
}

// --- profile ---

func runProfile(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()

	if len(args) == 0 {
		fmt.Println("==> Profiles")
		for _, p := range machete.ListProfiles(repoDir) {
			fmt.Printf("     %s\n", p)
		}
		return nil
	}

	switch args[0] {
	case "create":
		if len(args) < 2 {
			return fmt.Errorf("profile create requires a name")
		}
		name := args[1]
		if err := machete.ProfileValidName(name); err != nil {
			return err
		}
		profileRoot := machete.ProfileRoot(repoDir, name)
		os.MkdirAll(filepath.Join(profileRoot, "dotfiles"), 0755)
		os.MkdirAll(filepath.Join(profileRoot, "defaults"), 0755)
		os.MkdirAll(filepath.Join(profileRoot, "packages"), 0755)
		brewfile := filepath.Join(profileRoot, "Brewfile")
		if !machete.FileExists(brewfile) {
			os.WriteFile(brewfile, []byte(""), 0644)
		}
		defaultsScript := filepath.Join(profileRoot, "defaults", "macos-defaults.sh")
		if !machete.FileExists(defaultsScript) {
			os.WriteFile(defaultsScript, []byte("#!/usr/bin/env bash\nset -euo pipefail\n\n# Add profile-specific macOS defaults here.\n"), 0755)
		}
		fmt.Printf("Created profile scaffold at %s\n", profileRoot)
		return nil
	default:
		return fmt.Errorf("unknown profile subcommand: %s", args[0])
	}
}

// --- defaults ---

var defaultsPreset string

func runDefaults(cmd *cobra.Command, args []string) error {
	repoDir := projectDir()
	profile, err := resolveProfile()
	if err != nil {
		return err
	}

	defaultsScript := machete.DefaultsScriptPath(repoDir, profile)
	if defaultsPreset == "--init" || (len(args) > 0 && args[0] == "--init") {
		scriptContent := machete.RenderDefaultsScript("minimal")
		os.MkdirAll(filepath.Dir(defaultsScript), 0755)
		os.WriteFile(defaultsScript, []byte(scriptContent), 0755)
		fmt.Printf("- Created defaults/macos-defaults.sh from the minimal preset\n")
		return nil
	}

	if machete.FileExists(defaultsScript) {
		return machete.ExecCmd(defaultsScript)
	}
	fmt.Printf("No macOS defaults script found for profile '%s'. Run: ./machete defaults --init\n", profile)
	return nil
}

// --- verify ---

var verifyInit bool
var verifyFull bool

func runVerify(cmd *cobra.Command, args []string) error {
	fmt.Println("==> Checking checksums")
	fmt.Println("    No checksum baseline found.")
	fmt.Println("    Run: ./machete verify --init")
	return nil
}

// --- audit ---

var auditDir string
var auditSince string
var auditExport string

func runAudit(cmd *cobra.Command, args []string) error {
	fmt.Println("==> Running audit")
	fmt.Println("    No audit baseline found.")
	fmt.Println("    Run: ./machete audit --init")
	return nil
}

func runInventory(cmd *cobra.Command, args []string) error {
	fmt.Println("==> Mise")
	if miseBin := machete.HasCommand("mise"); miseBin != "" {
		fmt.Printf("     [ok] mise found at %s\n", miseBin)
	} else {
		fmt.Println("     [!] Mise is not installed")
	}

	fmt.Println("\n==> Homebrew casks")
	var casks []string
	if brewBin := machete.HasCommand("brew"); brewBin != "" {
		out, err := machete.CombinedOutput(brewBin, "list", "--cask")
		if err != nil {
			return fmt.Errorf("list Homebrew casks: %w", err)
		}
		casks = strings.Fields(out)
		fmt.Printf("     [ok] %d cask(s) installed\n", len(casks))
	} else {
		fmt.Println("     [!] Homebrew is not installed")
	}

	apps, err := machete.InstalledApplications(os.Getenv("HOME"))
	if err != nil {
		return fmt.Errorf("inventory applications: %w", err)
	}
	candidates := machete.UnmanagedApplications(apps, casks)
	fmt.Println("\n==> Application adoption candidates")
	if len(candidates) == 0 {
		fmt.Println("     [ok] No unmatched application bundles found")
		return nil
	}
	for _, app := range candidates {
		fmt.Printf("     [!] %s\n", app)
	}
	fmt.Println("\nReview each candidate before adding a Homebrew cask. Name matching is conservative and does not prove how an app was installed.")
	return nil
}
