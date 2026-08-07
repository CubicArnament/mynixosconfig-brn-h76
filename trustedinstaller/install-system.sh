#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-}"
if [[ -z "$HOST" ]]; then
  printf "usage: install-honor-magicbook <localhost|user@host>\n\n" >&2
  printf "  localhost   — live ISO, local disko-install\n" >&2
  printf "  user@host   — remote nixos-anywhere over SSH\n\n" >&2
  printf "env: INSTALL_DISK_FILTER=<filter>  INSTALL_DISK_INDEX=<n>\n" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$BIN_DIR/../libexec" ]]; then
  LIBEXEC_DIR="$(cd "$BIN_DIR/../libexec" && pwd)"
else
  LIBEXEC_DIR="$BIN_DIR"
fi

HOST_NAME="honor-magicbook-x16-pro"
LOCAL_DEVICE_PATHS_REL="hosts/${HOST_NAME}/local-device-paths.nix"

if [[ ! -f flake.nix || ! -f "hosts/${HOST_NAME}/configuration.nix" ]]; then
  printf "Refusing installation outside the expected NixOS repository: %s\n" "$REPO_ROOT" >&2
  exit 2
fi

case "$HOST" in
  -*|*[!A-Za-z0-9._:@%+-]*)
    printf "Refusing unsafe host target: %s\n" "$HOST" >&2
    exit 2
    ;;
esac

case "$HOST" in
  localhost|127.0.0.1|::1)
    printf "==> [local] Detecting disks...\n"
    bash "$LIBEXEC_DIR/local/fetch.sh" "$LOCAL_DEVICE_PATHS_REL"

    printf "\n==> [local] Installing...\n"
    exec bash "$LIBEXEC_DIR/local/install.sh" "$HOST_NAME" "$LOCAL_DEVICE_PATHS_REL"
    ;;
  *)
    printf "==> [remote] Detecting disks on %s...\n" "$HOST"
    FETCH_RESULT=$(ssh "$HOST" "sh -s -- '' ''" < "$LIBEXEC_DIR/remote/fetch.sh")
    export FETCH_RESULT
    bash "$LIBEXEC_DIR/local/fetch.sh" "$LOCAL_DEVICE_PATHS_REL"

    printf "\n==> [remote] Installing on %s...\n" "$HOST"
    exec sh "$LIBEXEC_DIR/remote/install.sh" "$HOST_NAME" "$HOST" "$LOCAL_DEVICE_PATHS_REL"
    ;;
esac
