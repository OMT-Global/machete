# machete

Swiss army knife for macOS setup and maintenance.

Snapshot your current Mac into Git, restore it on a new machine in one command, and keep everything in sync over time.

## Command Safety

`machete` is intentionally high-impact: it can install packages, symlink files into `$HOME`, apply macOS defaults, start Homebrew services, and rewrite tracked snapshots from the current machine state.

Review the commands below before running them on a machine you care about:

- `./machete setup` installs or restores Homebrew packages, global packages, services, dotfile symlinks, and macOS defaults. Existing home files are backed up with timestamped names before symlinks are created.
- `./machete sync` pulls the latest repo changes and re-runs setup for the active profile.
- `./machete snapshot` copies selected live machine state into this repository. Review `git diff` before committing so private paths, identities, or secrets do not become portable profile data.
- `./machete defaults` applies the shell commands in `defaults/macos-defaults.sh` to the current macOS user.
- `./machete schedule` installs a per-user `launchd` job that runs `sync` and `update` on a schedule.

Read-only inspection commands are `doctor`, `diff`, `history`, `verify` without `--init`, and `audit`.

## Commands

```
./machete setup      Bootstrap a new Mac: Xcode tools, Homebrew, global packages, services, dotfiles, defaults
./machete snapshot   Export current state to the active profile or --profile target
./machete schedule   Install a daily launchd agent that runs sync + update automatically
./machete track      Add one or more home-directory files to dotfiles/ and symlink them back into $HOME
./machete untrack    Remove one or more files from dotfiles/ and stop managing them
./machete uninstall  Dry-run or apply a reversible teardown of machete-managed home dotfile symlinks
./machete services   Start Homebrew services listed in defaults/brew-services.txt
./machete history    List rollback snapshot tags, newest first
./machete rollback   Restore the latest snapshot tag and re-apply setup
./machete verify     Hash tracked files and compare them to the checksum baseline
./machete audit      Scan $HOME and report new, changed, or missing files since the last snapshot baseline
./machete update     Upgrade all Homebrew packages and clean up
./machete doctor     Check what's installed, symlinked, and in sync for the active profile
./machete diff       Compare tracked dotfiles and Brewfile for the active profile
./machete sync       Pull latest repo changes and re-apply setup (idempotent)
./machete profile list
./machete profile create work
./machete defaults   Apply macOS system preferences from defaults/macos-defaults.sh
./machete defaults --init
                    Create defaults/macos-defaults.sh with an interactive preset picker
```

## How It Works

```
Current Mac                   Git Repository              New Mac
┌──────────────────────┐      ┌──────────────────┐      ┌──────────────────────┐
│ ./machete snapshot   │ ───► │ Brewfile         │ ───► │ ./machete setup      │
│  - brew bundle dump  │      │ packages/        │      │  - Xcode CLI tools   │
│  - global pkg lists  │      │ dotfiles/        │      │  - Homebrew          │
│  - copy dotfiles     │      │ defaults/        │      │  - brew bundle       │
│  - brew services     │      │   brew-services  │      │  - global pkg restore│
│  - defaults template │      │   macos-defaults │      │  - brew services     │
│                      │      │                  │      │  - symlink dotfiles  │
│                      │      │                  │      │  - apply defaults    │
└──────────────────────┘      └──────────────────┘      └──────────────────────┘
```

## Quick Start

### On your current Mac (first time)

```bash
git clone https://github.com/your-org/machete.git
cd machete
./machete snapshot          # captures the default profile in the repo root
./machete snapshot --with-extensions
./machete profile create work
./machete snapshot --profile work  # captures a separate machine under profiles/work/
vim defaults/macos-defaults.sh  # customize your system preferences
git status --short
git diff --stat
git add Brewfile dotfiles defaults packages profiles
git commit -m "snapshot: $(date +%Y-%m-%d)" && git push
```

`setup`, `snapshot`, and `sync` create rollback tags before they modify state. Tags are named `snapshot/YYYY-MM-DDTHH-MM-SS`.

Before committing a snapshot, inspect `git status --short`, `git diff --stat`, and the full diff for private paths, API tokens, machine-local shell snippets, and personal identity fields that should stay out of a shared repo.

### On a new Mac

```bash
git clone https://github.com/your-org/machete.git
cd machete
./machete setup
```

### Day-to-day maintenance

```bash
./machete doctor     # see what's drifted
./machete diff       # compare live state before snapshotting
./machete verify --init  # record a checksum baseline
./machete verify     # check tracked files against that baseline
./machete audit      # full-home drift report since the last snapshot baseline
./machete schedule   # install a daily sync + update launch agent
./machete doctor --profile work
./machete services   # start saved Homebrew services
./machete update     # upgrade all packages
./machete sync       # pull latest + re-apply
./machete track .config/ghostty/config
./machete untrack .vimrc
./machete history    # list rollback snapshots
./machete rollback   # restore the newest snapshot and re-apply setup
```

`./machete verify --init` records SHA256 checksums for the active profile's tracked dotfiles and Brewfile in `~/.machete/checksums.sqlite`. Later `./machete verify` runs report `NEW`, `CHANGED`, or `MISSING` files and exit non-zero when drift is found. Use `./machete verify --full --init` and `./machete verify --full` for a broader `$HOME` scan.

`./machete snapshot` also refreshes a full-home audit baseline in the background. `./machete audit` compares the current filesystem against that baseline, groups output into `NEW FILES`, `CHANGED FILES`, and `MISSING FILES`, and exits non-zero when drift is found. Use `--dir` to limit the report to a subtree, `--since YYYY-MM-DD` to filter recent changes, and `--export report.csv` to write CSV output.
`./machete schedule` installs a per-user `launchd` plist in `~/Library/LaunchAgents/` and a small runner script in `~/.machete/schedule/<profile>/run.sh`. By default it runs daily at `09:00` local time, calling `./machete sync` and then `./machete update` for the active profile. Use `--hour` and `--minute` to change the schedule.

To restore a specific snapshot, pass its tag:

```bash
./machete rollback snapshot/2026-04-22T09-30-00
```

## File Structure

```
machete/
  machete                  # unified entrypoint
  Brewfile                 # default-profile Homebrew packages
  packages/                # default-profile global package snapshots
    npm-global.txt
    pip-global.txt
    cargo-global.txt
    vscode-extensions.txt  # VS Code-compatible editor extensions (opt-in snapshot)
  dotfiles/                # default-profile dotfiles, symlinked to $HOME by setup
    .zshrc
    .zprofile
    .gitconfig
    ...
  defaults/                # default-profile defaults
    macos-defaults.sh
    brew-services.txt
  profiles/
    base/
      Brewfile
      dotfiles/
    work/
      Brewfile
      dotfiles/
      packages/
      defaults/
        macos-defaults.sh
        brew-services.txt
  scripts/
    setup.sh               # internals for ./machete setup
    snapshot.sh            # internals for ./machete snapshot
    services.sh            # internals for ./machete services
    history.sh             # internals for ./machete history
    rollback.sh            # internals for ./machete rollback
    update.sh              # internals for ./machete update
    doctor.sh              # internals for ./machete doctor
    audit.sh               # internals for ./machete audit
    diff.sh                # internals for ./machete diff
    sync.sh                # internals for ./machete sync
```

## Profiles

`machete` supports multiple machine profiles in one repo.

- `default` keeps the existing flat repo layout for backward compatibility.
- When `profiles/base/` exists, it is always applied first and named profiles layer on top of it.
- Named profiles live under `profiles/<name>/`.
- `--profile <name>` works with `setup`, `snapshot`, `sync`, `doctor`, and `diff`.
- The last explicit `--profile` is stored in `~/.machete/profile` and reused on later commands.

```bash
mkdir -p profiles/base
./machete profile create work
./machete snapshot --profile work
./machete doctor           # now uses the persisted work profile
./machete profile list
```

## Global packages

`./machete snapshot` now also records user/global packages for:
- `npm -g` → `packages/npm-global.txt`
- `pip install --user` → `packages/pip-global.txt`
- `cargo install` → `packages/cargo-global.txt`

`./machete setup` restores each list when the corresponding tool is available, and `./machete doctor` reports drift if the live machine no longer matches the saved snapshot.

## Dotfiles

Files in `dotfiles/` are **symlinked** (not copied) into `$HOME` by `./machete setup`. This means:
- Editing `~/.zshrc` edits the repo file directly
- No manual syncing required
- `./machete snapshot` re-copies them if you add new dotfiles to track

To start tracking a new file, run `./machete track PATH`. This copies `~/PATH` into `dotfiles/PATH` and replaces the home file with a symlink back into the repo. Machete refuses non-portable paths such as auth state, sessions, caches, `.env` files, SSH/GitHub/AWS/Kubernetes credentials, and filenames that look token-, cookie-, credential-, session-, or secret-bearing.

To stop tracking a file, run `./machete untrack PATH`. If the home file is still symlinked to the repo copy, machete converts it back into a regular file before removing `dotfiles/PATH`.

To undo the machine-local dotfile install without touching the repo copy, run `./machete uninstall --dotfiles` for a dry run, then `./machete uninstall --dotfiles --apply` to remove repo-managed symlinks and restore the newest `<file>.bak.<timestamp>` backup when one exists.

`./machete snapshot` refreshes portable files already tracked under `dotfiles/` and skips any tracked path that matches the non-portable denylist. On a brand-new repo with no tracked dotfiles yet, it still seeds the default starter set (`.zshrc`, `.zprofile`, `.gitconfig`, `.gitignore_global`, `.vimrc`) when those files exist.

Before publishing or sharing a machete repo, template personal identity fields in dotfiles such as `.gitconfig` and remove shell snippets that load local API tokens from the keychain or environment.

## macOS Defaults

`defaults/macos-defaults.sh` is generated on first `./machete snapshot`, or any time with `./machete defaults --init`.
The preset picker offers:
- `minimal`: conservative Finder, dialog, and screenshot defaults
- `developer`: minimal defaults plus fast keyboard, power-user Finder, Dock, and Activity Monitor settings
- `privacy`: minimal defaults plus reduced ad personalization and web search leakage

After choosing a base preset, answer yes/no prompts to layer individual settings. In non-interactive runs such as `CI=true`, machete skips prompts and writes the safe `minimal` preset.

Edit it freely and re-run `./machete defaults` to apply changes.

## Homebrew Services

`./machete snapshot` writes currently running Homebrew services to `defaults/brew-services.txt`.
`./machete setup` starts each saved service after installing packages, and `./machete services` can re-run that step by itself.

If a saved service is not installed, machete prints a warning and skips it. `./machete doctor` reports saved services that are missing or not running.

## Editor Extensions

`./machete snapshot --with-extensions` writes extensions from the first available VS Code-compatible CLI (`code`, `cursor`, or `codium`) to `packages/vscode-extensions.txt`.
When that file exists, `./machete setup` installs each saved extension with the first available editor CLI. If no supported editor CLI is installed, setup prints a warning and continues. `./machete doctor` reports extension drift only when `packages/vscode-extensions.txt` exists.

## Requirements

- macOS (Intel or Apple Silicon)
- Git
- Internet connection (for Homebrew)

## Troubleshooting

- **Homebrew not found after install**: ensure `/opt/homebrew/bin` (Apple Silicon) or `/usr/local/bin` (Intel) is in your `PATH`
- **Permission denied**: `chmod +x machete`
- **Symlink conflicts**: `./machete setup` backs up existing files to `<file>.bak` before symlinking
- **Back out a setup run**: `./machete uninstall --dotfiles` shows which repo-managed symlinks would be removed; add `--apply` to perform the teardown. It does not uninstall Homebrew packages, clear caches, or restore shell history.

## Privacy

Do not commit private keys, SSH configs, auth files, shell history, session state, cache directories, local Claude/Codex worktrees, or files that contain tokens, passwords, cookies, or machine-local secrets. Keep local tool state such as `.claude/` and `.codex/` out of the repo unless you have separated a small, portable scaffold from generated runtime data.

The bootstrap docs under `docs/bootstrap/` are maintainer/operator notes for this repository. They are not required for normal public `machete` usage.

## License

MIT
