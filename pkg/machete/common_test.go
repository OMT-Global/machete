package machete

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestProfileLayerDirsDefaultIncludesRepository(t *testing.T) {
	repoDir := t.TempDir()

	if got, want := ProfileLayerDirs(repoDir, MACHETE_DEFAULT_PROFILE), []string{repoDir}; !sameStrings(got, want) {
		t.Fatalf("ProfileLayerDirs(default) = %v, want %v", got, want)
	}

	if err := os.MkdirAll(filepath.Join(repoDir, "profiles", "base"), 0o755); err != nil {
		t.Fatal(err)
	}
	if got, want := ProfileLayerDirs(repoDir, MACHETE_DEFAULT_PROFILE), []string{filepath.Join(repoDir, "profiles", "base"), repoDir}; !sameStrings(got, want) {
		t.Fatalf("ProfileLayerDirs(default with base) = %v, want %v", got, want)
	}
}

func TestBrewfileMergeDefaultProfileIncludesRootBrewfile(t *testing.T) {
	repoDir := t.TempDir()
	rootBrewfile := "brew \"ripgrep\"\n"
	if err := os.WriteFile(filepath.Join(repoDir, "Brewfile"), []byte(rootBrewfile), 0o644); err != nil {
		t.Fatal(err)
	}

	output := filepath.Join(t.TempDir(), "Brewfile")
	if err := BrewfileMerge(repoDir, MACHETE_DEFAULT_PROFILE, output); err != nil {
		t.Fatal(err)
	}
	data, err := os.ReadFile(output)
	if err != nil {
		t.Fatal(err)
	}
	if got := strings.TrimSpace(string(data)); got != strings.TrimSpace(rootBrewfile) {
		t.Fatalf("merged Brewfile = %q, want %q", got, strings.TrimSpace(rootBrewfile))
	}
}

func TestMiseConfigPathDefaultProfileUsesRepository(t *testing.T) {
	repoDir := t.TempDir()
	if got, want := MiseConfigPath(repoDir, MACHETE_DEFAULT_PROFILE), filepath.Join(repoDir, "mise.toml"); got != want {
		t.Fatalf("MiseConfigPath(default) = %q, want %q", got, want)
	}
}

func TestUnmanagedApplicationsMatchesNormalizedCaskNames(t *testing.T) {
	apps := []string{"Google Chrome.app", "Machete.app", "Visual Studio Code.app"}
	casks := []string{"google-chrome", "visual-studio-code"}
	if got, want := UnmanagedApplications(apps, casks), []string{"Machete.app"}; !sameStrings(got, want) {
		t.Fatalf("UnmanagedApplications() = %v, want %v", got, want)
	}
}

func TestMiseConfigPathNamedProfileUsesProfileDirectory(t *testing.T) {
	repoDir := t.TempDir()
	if got, want := MiseConfigPath(repoDir, "ubuntu"), filepath.Join(repoDir, "profiles", "ubuntu", "mise.toml"); got != want {
		t.Fatalf("MiseConfigPath(ubuntu) = %q, want %q", got, want)
	}
}

func TestReadPackageListSkipsCommentsAndDuplicates(t *testing.T) {
	path := filepath.Join(t.TempDir(), "apt.txt")
	if err := os.WriteFile(path, []byte("# comment\ngit\n\nufw\ngit\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	got, err := ReadPackageList(path)
	if err != nil {
		t.Fatal(err)
	}
	if want := []string{"git", "ufw"}; !sameStrings(got, want) {
		t.Fatalf("ReadPackageList() = %v, want %v", got, want)
	}
}

func sameStrings(got, want []string) bool {
	if len(got) != len(want) {
		return false
	}
	for i := range got {
		if got[i] != want[i] {
			return false
		}
	}
	return true
}
