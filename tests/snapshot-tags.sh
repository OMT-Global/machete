#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/snapshot-tags.sh"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

git -C "${tmp_dir}" init --quiet
git -C "${tmp_dir}" config user.email "machete-tests@example.invalid"
git -C "${tmp_dir}" config user.name "machete tests"
git -C "${tmp_dir}" config commit.gpgsign false
git -C "${tmp_dir}" config tag.gpgsign false

printf "one\n" >"${tmp_dir}/state.txt"
git -C "${tmp_dir}" add state.txt
git -C "${tmp_dir}" commit --quiet -m "initial"

first_tag="$(create_snapshot_tag "${tmp_dir}" "test one")"

sleep 1
printf "two\n" >"${tmp_dir}/state.txt"
git -C "${tmp_dir}" commit --quiet -am "second"
second_tag="$(create_snapshot_tag "${tmp_dir}" "test two")"

if [[ "${first_tag}" != snapshot/* || "${second_tag}" != snapshot/* ]]; then
  echo "Expected snapshot tags, got '${first_tag}' and '${second_tag}'" >&2
  exit 1
fi

if [[ "$(latest_snapshot_tag "${tmp_dir}")" != "${second_tag}" ]]; then
  echo "Expected latest snapshot tag to be ${second_tag}" >&2
  exit 1
fi

first_history_tag="$(list_snapshot_tags "${tmp_dir}" | awk 'NR == 1 { print $1 }')"
if [[ "${first_history_tag}" != "${second_tag}" ]]; then
  echo "Expected history to list newest tag first" >&2
  exit 1
fi

git -C "${tmp_dir}" checkout --quiet "${first_tag}"
if [[ "$(cat "${tmp_dir}/state.txt")" != "one" ]]; then
  echo "Expected checkout of ${first_tag} to restore the initial state" >&2
  exit 1
fi

echo "snapshot tag tests passed"
