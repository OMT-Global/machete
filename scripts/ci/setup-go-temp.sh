#!/usr/bin/env bash
set -euo pipefail

go_version="${GO_VERSION:-}"
if [[ -z "${go_version}" ]]; then
  go_version="$(awk '$1 == "go" { print $2; exit }' go.mod)"
fi

case "${go_version}" in
  1.21)
    go_version="1.21.13"
    ;;
esac

system="$(uname -s)"
machine="$(uname -m)"

case "${system}" in
  Linux)
    go_os="linux"
    ;;
  Darwin)
    go_os="darwin"
    ;;
  *)
    echo "Unsupported OS for Go install: ${system}" >&2
    exit 1
    ;;
esac

case "${machine}" in
  x86_64|amd64)
    go_arch="amd64"
    ;;
  arm64|aarch64)
    go_arch="arm64"
    ;;
  *)
    echo "Unsupported architecture for Go install: ${machine}" >&2
    exit 1
    ;;
esac

install_root="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/machete-go-${go_version}-${go_os}-${go_arch}"
go_bin="${install_root}/go/bin/go"

if [[ ! -x "${go_bin}" ]]; then
  archive="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/go${go_version}.${go_os}-${go_arch}.tar.gz"
  url="https://go.dev/dl/go${go_version}.${go_os}-${go_arch}.tar.gz"

  rm -rf "${install_root}"
  mkdir -p "${install_root}"

  echo "Downloading ${url}"
  curl -fsSL "${url}" -o "${archive}"

  echo "Extracting Go ${go_version} to ${install_root}"
  if tar --help 2>&1 | grep -q -- '--no-same-owner'; then
    tar -xzf "${archive}" --no-same-owner -C "${install_root}"
  else
    tar -xzf "${archive}" -C "${install_root}"
  fi
fi

if [[ -n "${GITHUB_PATH:-}" ]]; then
  echo "${install_root}/go/bin" >>"${GITHUB_PATH}"
else
  echo "Add to PATH: ${install_root}/go/bin"
fi

"${go_bin}" version
