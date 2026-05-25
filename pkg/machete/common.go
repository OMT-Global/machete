// Package machete provides shared utilities for the machete macOS setup tool.
package machete

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"slices"
	"sort"
	"strings"
	"time"
)

var homeDirCache string

func homeDir() string {
	if homeDirCache == "" {
		homeDirCache = os.Getenv("HOME")
		if homeDirCache == "" && runtime.GOOS == "darwin" {
		 ud, err := exec.Command("dscl", ".", "read", os.Getenv("USER"), ".homeDirectory").CombinedOutput()
			if err == nil {
				homeDirCache = strings.TrimSpace(strings.TrimPrefix(string(ud), "homeDirectory: /Users/"))
			}
		}
	}
	return homeDirCache
}

// ExecCmd runs a command with inherited stdio.
func ExecCmd(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

// CombinedOutput runs a command and returns combined output.
func CombinedOutput(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).CombinedOutput()
	return strings.TrimSpace(string(out)), err
}

// HasCommand returns the path to the named executable or empty string.
func HasCommand(name string) string {
	p, err := exec.LookPath(name)
	if err != nil {
		return ""
	}
	return p
}

// FindBrewBin returns the path to brew or an error.
func FindBrewBin() (string, error) {
	if p := HasCommand("brew"); p != "" {
		return p, nil
	}
	if _, err := os.Stat("/opt/homebrew/bin/brew"); err == nil {
		return "/opt/homebrew/bin/brew", nil
	}
	if _, err := os.Stat("/usr/local/bin/brew"); err == nil {
		return "/usr/local/bin/brew", nil
	}
	return "", fmt.Errorf("brew not found")
}

const (
	MACHETE_DEFAULT_PROFILE = "default"
	MACHETE_BASE_PROFILE    = "base"
	SNAPSHOT_TAG_PREFIX     = "snapshot"
)

// ProfilesPath returns the profiles directory for a repo.
func ProfilesPath(repoDir string) string {
	return filepath.Join(repoDir, "profiles")
}

// BaseProfileRoot returns the base profile directory.
func BaseProfileRoot(repoDir string) string {
	return filepath.Join(ProfilesPath(repoDir), MACHETE_BASE_PROFILE)
}

// ProfileRoot returns the root directory for a named profile.
func ProfileRoot(repoDir, name string) string {
	switch name {
	case MACHETE_DEFAULT_PROFILE:
		return repoDir
	case MACHETE_BASE_PROFILE:
		return BaseProfileRoot(repoDir)
	default:
		return filepath.Join(ProfilesPath(repoDir), name)
	}
}

// ProfileExists returns true if the profile directory exists.
func ProfileExists(repoDir, name string) bool {
	switch name {
	case MACHETE_DEFAULT_PROFILE:
		return true
	case MACHETE_BASE_PROFILE:
		_, err := os.Stat(BaseProfileRoot(repoDir))
		return err == nil
	default:
		_, err := os.Stat(filepath.Join(ProfilesPath(repoDir), name))
		return err == nil
	}
}

// DotfilesDir returns the dotfiles directory for a profile.
func DotfilesDir(repoDir, name string) string {
	return filepath.Join(ProfileRoot(repoDir, name), "dotfiles")
}

// PackagesDir returns the packages directory for a profile.
func PackagesDir(repoDir, name string) string {
	return filepath.Join(ProfileRoot(repoDir, name), "packages")
}

// DefaultsDir returns the defaults directory for a profile.
func DefaultsDir(repoDir, name string) string {
	return filepath.Join(ProfileRoot(repoDir, name), "defaults")
}

// BrewfilePath returns the Brewfile path for a profile.
func BrewfilePath(repoDir, name string) string {
	return filepath.Join(ProfileRoot(repoDir, name), "Brewfile")
}

// DefaultsScriptPath returns the macOS defaults script path.
func DefaultsScriptPath(repoDir, name string) string {
	return filepath.Join(DefaultsDir(repoDir, name), "macos-defaults.sh")
}

// BrewServicesFile returns the brew services state file path.
func BrewServicesFile(repoDir, name string) string {
	return filepath.Join(DefaultsDir(repoDir, name), "brew-services.txt")
}

// EditorExtensionsFile returns the VS Code extensions list path.
func EditorExtensionsFile(repoDir, name string) string {
	return filepath.Join(PackagesDir(repoDir, name), "vscode-extensions.txt")
}

// ProfileLayerDirs returns all profile layer directories, base first.
func ProfileLayerDirs(repoDir, name string) []string {
	base := BaseProfileRoot(repoDir)
	if name == MACHETE_DEFAULT_PROFILE || name == MACHETE_BASE_PROFILE {
		if _, err := os.Stat(base); err == nil {
			return []string{base}
		}
		return []string{}
	}
	if _, err := os.Stat(base); err == nil {
		return []string{base, filepath.Join(ProfilesPath(repoDir), name)}
	}
	return []string{repoDir}
}

// ProfileLayerBrewfiles returns Brewfile paths from all profile layers.
func ProfileLayerBrewfiles(repoDir, name string) []string {
	var files []string
	for _, dir := range ProfileLayerDirs(repoDir, name) {
		bf := filepath.Join(dir, "Brewfile")
		if _, err := os.Stat(bf); err == nil {
			files = append(files, bf)
		}
	}
	return files
}

// ProfileLayerDotfilesDirs returns dotfiles/ dirs from all profile layers.
func ProfileLayerDotfilesDirs(repoDir, name string) []string {
	var dirs []string
	for _, dir := range ProfileLayerDirs(repoDir, name) {
		dd := filepath.Join(dir, "dotfiles")
		if _, err := os.Stat(dd); err == nil {
			dirs = append(dirs, dd)
		}
	}
	return dirs
}

const activeProfileFile = ".machete/profile"

// ActiveProfileFile returns the global active profile file path.
func ActiveProfileFile() string {
	return filepath.Join(homeDir(), activeProfileFile)
}

// ReadActiveProfile reads the active profile name from storage.
func ReadActiveProfile(repoDir string) string {
	af := ActiveProfileFile()
	if data, err := os.ReadFile(af); err == nil {
		if name := strings.TrimSpace(string(data)); name != "" {
			return name
		}
	}
	legacy := filepath.Join(repoDir, activeProfileFile)
	if data, err := os.ReadFile(legacy); err == nil {
		if name := strings.TrimSpace(string(data)); name != "" {
			return name
		}
	}
	return MACHETE_DEFAULT_PROFILE
}

// WriteActiveProfile writes the active profile name to both global and local files.
func WriteActiveProfile(repoDir, name string) error {
	af := ActiveProfileFile()
	if err := os.MkdirAll(filepath.Dir(af), 0755); err != nil {
		return err
	}
	if err := os.WriteFile(af, []byte(name+"\n"), 0644); err != nil {
		return err
	}
	legacy := filepath.Join(repoDir, activeProfileFile)
	if err := os.MkdirAll(filepath.Dir(legacy), 0755); err != nil {
		return err
	}
	return os.WriteFile(legacy, []byte(name+"\n"), 0644)
}

var validProfileNameRe = regexp.MustCompile(`^[A-Za-z0-9._-]+$`)

// ResolveProfile returns the effective profile name.
func ResolveProfile(repoDir, explicitName string) (string, error) {
	name := explicitName
	if name == "" {
		name = ReadActiveProfile(repoDir)
	}
	if name == "" {
		name = MACHETE_DEFAULT_PROFILE
	}
	if !validProfileNameRe.MatchString(name) {
		return "", fmt.Errorf("invalid profile name: %s", name)
	}
	if explicitName != "" {
		if !ProfileExists(repoDir, name) {
			return "", fmt.Errorf("unknown profile: %s", name)
		}
		if err := WriteActiveProfile(repoDir, name); err != nil {
			return "", err
		}
		return name, nil
	}
	if ProfileExists(repoDir, name) {
		return name, nil
	}
	return MACHETE_DEFAULT_PROFILE, nil
}

// ListProfiles lists all known profiles in the repo.
func ListProfiles(repoDir string) []string {
	base := BaseProfileRoot(repoDir)
	profiles := []string{MACHETE_DEFAULT_PROFILE}
	active := ReadActiveProfile(repoDir)
	if active != MACHETE_DEFAULT_PROFILE {
		profiles = append(profiles, active)
	}
	if _, err := os.Stat(base); err == nil {
		profiles = append(profiles, MACHETE_BASE_PROFILE)
	}
	pr := ProfilesPath(repoDir)
	if _, err := os.Stat(pr); err == nil {
		entries, err := os.ReadDir(pr)
		if err == nil {
			for _, e := range entries {
				if e.IsDir() && e.Name() != MACHETE_BASE_PROFILE {
					profiles = append(profiles, e.Name())
				}
			}
		}
	}
	sort.Strings(profiles)
	seen := make(map[string]bool)
	var deduped []string
	for _, p := range profiles {
		if !seen[p] {
			seen[p] = true
			deduped = append(deduped, p)
		}
	}
	return deduped
}

// MakeDirs creates parent directories for a path.
func MakeDirs(path string) error {
	return os.MkdirAll(filepath.Dir(path), 0755)
}

// DirExists returns true if the path is a directory.
func DirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

// FileExists returns true if the path exists.
func FileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

// IsRegularFile returns true if the path is a regular file.
func IsRegularFile(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.Mode().IsRegular()
}

// WalkFiles returns all regular files under root.
func WalkFiles(root string) ([]string, error) {
	var files []string
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() && info.Name() == ".gitkeep" {
			return filepath.SkipDir
		}
		if !info.IsDir() && info.Name() == ".gitkeep" {
			return nil
		}
		if !info.IsDir() {
			files = append(files, path)
		}
		return nil
	})
	return files, err
}

var defaultDotfiles = []string{".zshrc", ".zprofile", ".gitconfig", ".gitignore_global", ".vimrc"}

// DotfilesDefaultPaths returns the default dotfiles to track.
func DotfilesDefaultPaths() []string {
	return slices.Clone(defaultDotfiles)
}

// DotfilesList returns all tracked files in the dotfiles directory.
func DotfilesList(dotfilesDir string) ([]string, error) {
	if !DirExists(dotfilesDir) {
		return nil, nil
	}
	return WalkFiles(dotfilesDir)
}

// DotfilesHasTrackedFiles returns true if the dotfiles directory has files.
func DotfilesHasTrackedFiles(dotfilesDir string) bool {
	files, err := DotfilesList(dotfilesDir)
	return err == nil && len(files) > 0
}

var portableDenyPatterns = []struct {
	re     *regexp.Regexp
	reason string
}{
	{regexp.MustCompile(`(?i)^\.env(\.\*)?$`), "machine-local environment file"},
	{regexp.MustCompile(`^\.claude(?:/|$)`), "local agent auth, sessions, or cache state"},
	{regexp.MustCompile(`^\.codex(?:/|$)`), "local agent auth, sessions, or cache state"},
	{regexp.MustCompile(`^\.machete(?:/|$)`), "local agent auth, sessions, or cache state"},
	{regexp.MustCompile(`^\.cache(?:/|$)`), "cache directory"},
	{regexp.MustCompile(`Library/Caches(?:/|$)`), "cache directory"},
	{regexp.MustCompile(`^\.ssh(?:/|$)`), "auth state or machine-local credential file"},
	{regexp.MustCompile(`^\.gnupg(?:/|$)`), "auth state or machine-local credential file"},
	{regexp.MustCompile(`^\.aws/credentials$`), "auth state or machine-local credential file"},
	{regexp.MustCompile(`^\.aws/config$`), "auth state or machine-local credential file"},
	{regexp.MustCompile(`^\.netrc$`), "auth state or machine-local credential file"},
	{regexp.MustCompile(`^\.pypirc$`), "auth state or machine-local credential file"},
	{regexp.MustCompile(`^\.npmrc$`), "auth state or machine-local credential file"},
	{regexp.MustCompile(`^\.docker/config\.json$`), "auth state or machine-local credential file"},
	{regexp.MustCompile(`^\.config/gh/hosts\.yml$`), "auth state or machine-local credential file"},
	{regexp.MustCompile(`^\.kube/config$`), "auth state or machine-local credential file"},
	{regexp.MustCompile(`(?i)token`), "secret-bearing filename"},
	{regexp.MustCompile(`(?i)session`), "secret-bearing filename"},
	{regexp.MustCompile(`(?i)cookie`), "secret-bearing filename"},
	{regexp.MustCompile(`(?i)credential`), "secret-bearing filename"},
	{regexp.MustCompile(`(?i)secret`), "secret-bearing filename"},
}

// IsPortablePath returns true if relPath is safe to commit.
func IsPortablePath(relPath string) bool {
	for _, p := range portableDenyPatterns {
		if p.re.MatchString(relPath) {
			return false
		}
	}
	return true
}

// PortableReason returns why relPath is not portable, or empty.
func PortableReason(relPath string) string {
	for _, p := range portableDenyPatterns {
		if p.re.MatchString(relPath) {
			return p.reason
		}
	}
	return ""
}

// NormalizeDotfilePath converts a path to a relative path under HOME.
func NormalizeDotfilePath(path string) (string, error) {
	path = strings.TrimPrefix(path, "~/")
	home := homeDir()
	path = strings.TrimPrefix(path, home+"/")
	path = strings.TrimPrefix(path, "dotfiles/")
	for strings.HasPrefix(path, "./") {
		path = path[2:]
	}
	if path == "" || path == "." || path == ".." {
		return "", fmt.Errorf("invalid dotfile path: %s", path)
	}
	if strings.HasPrefix(path, "../") || strings.Contains(path, "/..") {
		return "", fmt.Errorf("dotfile path must be relative: %s", path)
	}
	return path, nil
}

// DotfileHomePath returns the path in the user's home directory.
func DotfileHomePath(relPath string) string {
	return filepath.Join(homeDir(), relPath)
}

// DotfileRepoPath returns the path in the repo's dotfiles/ directory.
func DotfileRepoPath(dotfilesDir, relPath string) string {
	return filepath.Join(dotfilesDir, relPath)
}

// DotfileCanonicalPath returns the canonical absolute path.
func DotfileCanonicalPath(path string) (string, error) {
	dir := filepath.Dir(path)
	base := filepath.Base(path)
	if DirExists(dir) {
		cd, err := os.Getwd()
		if err != nil {
			return path, nil
		}
		if err := os.Chdir(dir); err != nil {
			return path, nil
		}
		defer os.Chdir(cd)
		cwd, _ := os.Getwd()
		return filepath.Join(cwd, base), nil
	}
	return path, nil
}

// CopyHomeToRepo copies a home file into the repo's dotfiles/.
func CopyHomeToRepo(dotfilesDir, relPath string) error {
	src := DotfileHomePath(relPath)
	dst := DotfileRepoPath(dotfilesDir, relPath)
	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	if err := MakeDirs(dst); err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0644)
}

// SymlinkRepoToHome creates a symlink from home to the repo file.
func SymlinkRepoToHome(dotfilesDir, relPath string) error {
	src := DotfileRepoPath(dotfilesDir, relPath)
	dst := DotfileHomePath(relPath)
	if err := MakeDirs(dst); err != nil {
		return err
	}
	return os.Symlink(src, dst)
}

// RemoveEmptyParentDirs removes empty parent directories up to root.
func RemoveEmptyParentDirs(root, target string) error {
	currentDir := filepath.Dir(target)
	for currentDir != root && currentDir != "." && currentDir != "/" {
		if err := os.Remove(filepath.Join(currentDir, ".gitkeep")); err != nil {
			break
		}
		if err := os.Remove(currentDir); err != nil {
			break
		}
		currentDir = filepath.Dir(currentDir)
	}
	return nil
}

// DotfileSymlinkPointsTo returns true if the symlink target matches expected.
func DotfileSymlinkPointsTo(linkPath, expectedPath string) bool {
	target, err := os.Readlink(linkPath)
	if err != nil {
		return false
	}
	if !filepath.IsAbs(target) {
		target = filepath.Join(filepath.Dir(linkPath), target)
	}
	canonicalTarget, _ := DotfileCanonicalPath(target)
	canonicalExpected, _ := DotfileCanonicalPath(expectedPath)
	return canonicalTarget == canonicalExpected
}

// SnapshotTag generate snapshot tag.
func SnapshotTag(repoDir string) (string, error) {
	ts := time.Now().UTC().Format("2006-01-02T15-04-05")
	candidate := fmt.Sprintf("%s/%s", SNAPSHOT_TAG_PREFIX, ts)
	for i := 0; i < 5; i++ {
		out, err := CombinedOutput("git", "-C", repoDir, "rev-parse", "--verify", "--quiet", "refs/tags/"+candidate)
		if err != nil || strings.TrimSpace(out) == "" {
			return candidate, nil
		}
		candidate = fmt.Sprintf("%s/%s-%d", SNAPSHOT_TAG_PREFIX, ts, i+2)
	}
	return "", fmt.Errorf("unable to generate unique tag name")
}

// CreateSnapshotTag creates an annotated git tag.
func CreateSnapshotTag(repoDir, reason string) (string, error) {
	out, err := CombinedOutput("git", "-C", repoDir, "rev-parse", "--is-inside-work-tree")
	if err != nil || strings.TrimSpace(out) != "true" {
		return "", fmt.Errorf("not inside a git worktree")
	}
	out, err = CombinedOutput("git", "-C", repoDir, "rev-parse", "--verify", "--quiet", "HEAD")
	if err != nil || strings.TrimSpace(out) == "" {
		return "", fmt.Errorf("git repository has no commits")
	}
	tagName, err := SnapshotTag(repoDir)
	if err != nil {
		return "", err
	}
	message := fmt.Sprintf("machete snapshot before %s", reason)
	_, err = CombinedOutput("git", "-C", repoDir, "tag", "-a", tagName, "-m", message, "HEAD")
	if err != nil {
		return "", err
	}
	return tagName, nil
}

// ListSnapshotTags lists all snapshot tags by creation date.
func ListSnapshotTags(repoDir string) ([]string, error) {
	out, err := CombinedOutput("git", "-C", repoDir, "tag", "--list", SNAPSHOT_TAG_PREFIX+"/*", "--sort=-creatordate")
	if err != nil {
		return nil, err
	}
	var tags []string
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if strings.TrimSpace(line) != "" {
			tags = append(tags, strings.TrimSpace(line))
		}
	}
	return tags, nil
}

// LatestSnapshotTag returns the most recent snapshot tag.
func LatestSnapshotTag(repoDir string) (string, error) {
	out, err := CombinedOutput("git", "-C", repoDir, "tag", "--list", SNAPSHOT_TAG_PREFIX+"/*", "--sort=-creatordate")
	if err != nil {
		return "", err
	}
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if strings.TrimSpace(line) != "" {
			return strings.TrimSpace(line), nil
		}
	}
	return "", nil
}

// BrewServicesRestore starts each service from the saved list.
func BrewServicesRestore(servicesFile string) error {
	data, err := os.ReadFile(servicesFile)
	if err != nil {
		return nil
	}
	var services []string
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		s := strings.TrimSpace(scanner.Text())
		s = strings.TrimLeft(s, "-")
		s = strings.TrimSpace(s)
		if s != "" && !strings.HasPrefix(s, "#") {
			services = append(services, s)
		}
	}
	if len(services) == 0 {
		return nil
	}
	for _, svc := range services {
		fmt.Printf("    - Starting %s\n", svc)
		if _, err := CombinedOutput("brew", "services", "start", svc); err != nil {
			fmt.Printf("    [!] %s: failed to start\n", svc)
		}
	}
	return nil
}

// BrewServicesSnapshot reads running services and writes them to a file.
func BrewServicesSnapshot(servicesFile string) error {
	if DirExists(filepath.Dir(servicesFile)) || true {
		if err := os.MkdirAll(filepath.Dir(servicesFile), 0755); err != nil {
			return err
		}
	}
	out, err := CombinedOutput("brew", "services", "list")
	if err != nil {
		return err
	}
	var lines []string
	scanner := bufio.NewScanner(strings.NewReader(strings.TrimSpace(out)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		parts := strings.Fields(line)
		if len(parts) >= 2 && parts[1] == "started" {
			lines = append(lines, parts[0])
		}
	}
	return os.WriteFile(servicesFile, []byte(strings.Join(lines, "\n")+"\n"), 0644)
}

// BrewfileMerge merges Brewfiles from all profile layers.
func BrewfileMerge(repoDir, profileName, output string) error {
	seen := make(map[string]bool)
	var merged []string
	for _, dir := range ProfileLayerDirs(repoDir, profileName) {
		bf := filepath.Join(dir, "Brewfile")
		data, err := os.ReadFile(bf)
		if err != nil {
			continue
		}
		scanner := bufio.NewScanner(strings.NewReader(string(data)))
		for scanner.Scan() {
			line := strings.TrimSpace(scanner.Text())
			if line == "" {
				continue
			}
			if !seen[line] {
				seen[line] = true
				merged = append(merged, line)
			}
		}
	}
	if err := os.MkdirAll(filepath.Dir(output), 0755); err != nil {
		return err
	}
	return os.WriteFile(output, []byte(strings.Join(merged, "\n")+"\n"), 0644)
}

// BrewfileFilter removes local/ entries and unnecessary tap lines.
func BrewfileFilter(inputFile, outputFile string) error {
	data, err := os.ReadFile(inputFile)
	if err != nil {
		return err
	}
	var lines []string
	scanner := bufio.NewScanner(strings.NewReader(string(data)))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, `local "`) {
			continue
		}
		lines = append(lines, line)
	}
	return os.WriteFile(outputFile, []byte(strings.Join(lines, "\n")+"\n"), 0644)
}

// RenderDefaultsScript renders a macOS defaults script from a preset.
func RenderDefaultsScript(preset string) string {
	var sb strings.Builder
	sb.WriteString("#!/usr/bin/env bash\nset -euo pipefail\n\n")
	sb.WriteString("# macOS system preferences generated by machete defaults --init.\n")
	sb.WriteString("# Preset: " + preset + "\n")
	sb.WriteString("# Re-run safely via: ./machete defaults\n\n")
	sb.WriteString("# --- Dialogs ---\n")
	sb.WriteString("defaults write -g NSNavPanelExpandedStateForSaveMode -bool true\n")
	sb.WriteString("defaults write -g NSNavPanelExpandedStateForSaveMode2 -bool true\n")
	sb.WriteString("defaults write -g PMPrintingExpandedStateForPrint -bool true\n")
	sb.WriteString("defaults write -g PMPrintingExpandedStateForPrint2 -bool true\n\n")
	switch preset {
	case "developer":
		sb.WriteString("# --- Keyboard ---\n")
		sb.WriteString("defaults write -g ApplePressAndHoldEnabled -bool false\n")
		sb.WriteString("defaults write NSGlobalDomain KeyRepeat -int 2\n")
		sb.WriteString("defaults write NSGlobalDomain InitialKeyRepeat -int 15\n\n")
		sb.WriteString("# --- Finder ---\n")
		sb.WriteString("defaults write com.apple.finder AppleShowAllFiles -bool true\n")
		sb.WriteString("defaults write com.apple.finder ShowPathbar -bool true\n")
		sb.WriteString("defaults write com.apple.finder ShowStatusBar -bool true\n")
		sb.WriteString("defaults write com.apple.finder FXPreferredViewStyle -string \"Nlsv\"\n")
		sb.WriteString("defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false\n\n")
		sb.WriteString("# --- Activity Monitor ---\n")
		sb.WriteString("defaults write com.apple.ActivityMonitor OpenMainWindow -bool true\n")
		sb.WriteString("defaults write com.apple.ActivityMonitor ShowCategory -int 0\n\n")
	case "privacy":
		sb.WriteString("# --- Privacy ---\n")
		sb.WriteString("defaults write com.apple.AdLib allowApplePersonalizedAdvertising -bool false\n")
		sb.WriteString("defaults write com.apple.Safari UniversalSearchEnabled -bool false\n")
		sb.WriteString("defaults write com.apple.Safari SuppressSearchSuggestions -bool true\n\n")
	}
	sb.WriteString("# --- Apply ---\n")
	sb.WriteString("killall Dock Finder SystemUIServer 2>/dev/null || true\n")
	sb.WriteString("echo \"    - macOS defaults applied\"\n")
	return sb.String()
}

// ProfileValidName validates a profile name.
func ProfileValidName(name string) error {
	if !validProfileNameRe.MatchString(name) {
		return fmt.Errorf("invalid profile name: %s (use only letters, numbers, dots, dashes, and underscores)", name)
	}
	return nil
}
