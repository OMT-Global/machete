#!/usr/bin/env bash
set -euo pipefail

input="${1:-"-"}"

if [[ "$input" == "-" ]]; then
  body="$(cat)"
else
  if [[ ! -f "$input" ]]; then
    echo "ERROR: PR body file not found: $input" >&2
    exit 1
  fi
  body="$(cat "$input")"
fi

failures=()

add_failure() {
  failures+=("$1")
}

has_meaningful_content() {
  local content="$1"

  awk '
    {
      line=$0
      sub(/\r$/, "", line)
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)

      if (line == "" || line ~ /^<!--/ || line == "-" || line == "*" || line == "TBD" || line == "TODO") {
        next
      }

      if (line ~ /^[-*][[:space:]]+\[[xX]\][[:space:]]+/) {
        found=1
        next
      }

      if (line ~ /^[-*][[:space:]]*$/) {
        next
      }

      found=1
    }
    END {
      exit found ? 0 : 1
    }
  ' <<<"$content"
}

section_content() {
  local heading="$1"

  printf '%s\n' "$body" | perl -0e '
    use strict;
    use warnings;

    my $heading = shift @ARGV;
    my $body = <STDIN>;

    if ($body =~ /^##[ \t]+\Q$heading\E[ \t]*(?:\r?\n)(.*?)(?=^##[ \t]+|\z)/ms) {
      print $1;
      exit 0;
    }

    exit 2;
  ' "$heading"
}

require_section() {
  local heading="$1"
  local content

  if ! content="$(section_content "$heading")"; then
    add_failure "Missing required section: ## $heading"
    return
  fi

  if ! has_meaningful_content "$content"; then
    add_failure "Section has no completed content: ## $heading"
  fi
}

if ! grep -Eiq '(close[sd]?|fix(e[sd])?|resolve[sd]?|refs?)[[:space:]]+#[0-9]+' <<<"$body"; then
  add_failure "PR body must link a governing issue with Closes/Fixes/Resolves/Refs #number."
fi

required_sections=(
  "Governing Issue"
  "Summary"
  "Scope"
  "Verification"
  "Risk / Rollback"
  "Secrets / Environment"
  "Agent Ownership"
)

for section in "${required_sections[@]}"; do
  require_section "$section"
done

if grep -Eq '^[[:space:]]*[-*][[:space:]]+\[[[:space:]]\][[:space:]]+' <<<"$body"; then
  add_failure "PR body contains unchecked required checklist items."
fi

if [[ "${#failures[@]}" -gt 0 ]]; then
  echo "PR description validation failed:" >&2
  for failure in "${failures[@]}"; do
    echo "- $failure" >&2
  done
  exit 1
fi

echo "PR description contains the required template information."
