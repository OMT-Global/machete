#!/usr/bin/env bash

SNAPSHOT_TAG_PREFIX="${SNAPSHOT_TAG_PREFIX:-snapshot}"

snapshot_tag_name() {
  local repo_dir="$1"
  local timestamp
  local candidate
  local suffix

  timestamp="$(date +%Y-%m-%dT%H-%M-%S)"
  candidate="${SNAPSHOT_TAG_PREFIX}/${timestamp}"
  suffix=2

  while git -C "${repo_dir}" rev-parse --verify --quiet "refs/tags/${candidate}" >/dev/null; do
    candidate="${SNAPSHOT_TAG_PREFIX}/${timestamp}-${suffix}"
    suffix=$((suffix + 1))
  done

  echo "${candidate}"
}

create_snapshot_tag() {
  local repo_dir="$1"
  local reason="$2"
  local tag

  if ! git -C "${repo_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "Not inside a git worktree; cannot create rollback snapshot tag." >&2
    return 1
  fi

  if ! git -C "${repo_dir}" rev-parse --verify --quiet HEAD >/dev/null; then
    echo "Git repository has no commits; cannot create rollback snapshot tag." >&2
    return 1
  fi

  tag="$(snapshot_tag_name "${repo_dir}")"
  git -C "${repo_dir}" tag -a "${tag}" -m "machete snapshot before ${reason}" HEAD
  echo "${tag}"
}

list_snapshot_tags() {
  local repo_dir="$1"
  git -C "${repo_dir}" tag --list "${SNAPSHOT_TAG_PREFIX}/*" --sort=-creatordate \
    --format="%(refname:short)%09%(creatordate:iso8601)%09%(subject)"
}

latest_snapshot_tag() {
  local repo_dir="$1"
  git -C "${repo_dir}" tag --list "${SNAPSHOT_TAG_PREFIX}/*" --sort=-creatordate | head -n 1
}
