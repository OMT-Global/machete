#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/profiles.sh"
MACHETE_PROFILE="${MACHETE_PROFILE:-$(resolve_profile "${REPO_DIR}")}"

DEFAULT_HOUR=9
DEFAULT_MINUTE=0

usage() {
  cat <<EOF
Usage:
  ./machete schedule [--hour N] [--minute N]

Installs a per-user launchd agent that runs:
  ./machete sync
  ./machete update

Defaults:
  --hour 9
  --minute 0
EOF
}

require_number_in_range() {
  local name="$1"
  local value="$2"
  local min="$3"
  local max="$4"

  if [[ ! "${value}" =~ ^[0-9]+$ ]] || (( value < min || value > max )); then
    echo "Invalid ${name}: ${value} (expected ${min}-${max})" >&2
    exit 1
  fi
}

HOUR="${DEFAULT_HOUR}"
MINUTE="${DEFAULT_MINUTE}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hour)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --hour" >&2
        exit 1
      fi
      HOUR="$2"
      shift 2
      ;;
    --hour=*)
      HOUR="${1#--hour=}"
      shift
      ;;
    --minute)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --minute" >&2
        exit 1
      fi
      MINUTE="$2"
      shift 2
      ;;
    --minute=*)
      MINUTE="${1#--minute=}"
      shift
      ;;
    help|--help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo >&2
      usage >&2
      exit 1
      ;;
  esac
done

require_number_in_range "hour" "${HOUR}" 0 23
require_number_in_range "minute" "${MINUTE}" 0 59

profile_slug="${MACHETE_PROFILE//[^A-Za-z0-9]/-}"
if [[ -z "${profile_slug}" ]]; then
  profile_slug="default"
fi

label="dev.omt-global.machete.schedule.${profile_slug}"
launch_agents_dir="${HOME}/Library/LaunchAgents"
state_dir="${HOME}/.machete/schedule/${MACHETE_PROFILE}"
log_dir="${HOME}/.machete/logs"
runner_path="${state_dir}/run.sh"
plist_path="${launch_agents_dir}/${label}.plist"

mkdir -p "${launch_agents_dir}" "${state_dir}" "${log_dir}"

cat > "${runner_path}" <<EOF
#!/usr/bin/env bash
set -euo pipefail

cd "${REPO_DIR}"
"${REPO_DIR}/machete" sync --profile "${MACHETE_PROFILE}"
"${REPO_DIR}/machete" update --profile "${MACHETE_PROFILE}"
EOF
chmod +x "${runner_path}"

cat > "${plist_path}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${label}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${runner_path}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>${HOUR}</integer>
    <key>Minute</key>
    <integer>${MINUTE}</integer>
  </dict>
  <key>StandardOutPath</key>
  <string>${log_dir}/${profile_slug}.schedule.log</string>
  <key>StandardErrorPath</key>
  <string>${log_dir}/${profile_slug}.schedule.log</string>
</dict>
</plist>
EOF

if command -v launchctl >/dev/null 2>&1; then
  launchctl unload "${plist_path}" >/dev/null 2>&1 || true
  launchctl load "${plist_path}"
  echo "Installed and loaded launchd agent: ${label}"
else
  echo "Installed launchd plist at ${plist_path}"
  echo "launchctl not found; load it manually on macOS with: launchctl load \"${plist_path}\""
fi

printf 'Scheduled daily sync/update at %02d:%02d for profile %s\n' "${HOUR}" "${MINUTE}" "${MACHETE_PROFILE}"
