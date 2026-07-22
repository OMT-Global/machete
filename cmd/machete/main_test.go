package main

import (
	"reflect"
	"testing"
)

func TestLinuxMiseInstallCommandUsesRequestedPath(t *testing.T) {
	cmd := linuxMiseInstallCommand("/tmp/mise-installer", "/tmp/mise")
	if got, want := cmd.Args, []string{"sh", "/tmp/mise-installer"}; !reflect.DeepEqual(got, want) {
		t.Fatalf("installer command = %#v, want %#v", got, want)
	}
	if !containsEnv(cmd.Env, "MISE_INSTALL_PATH=/tmp/mise") {
		t.Fatalf("installer environment does not set MISE_INSTALL_PATH: %#v", cmd.Env)
	}
}

func TestLinuxMiseInstallPathIsSystemWide(t *testing.T) {
	if linuxMiseInstallPath != "/usr/local/bin/mise" {
		t.Fatalf("linuxMiseInstallPath = %q, want /usr/local/bin/mise", linuxMiseInstallPath)
	}
}

func containsEnv(env []string, entry string) bool {
	for _, value := range env {
		if value == entry {
			return true
		}
	}
	return false
}
