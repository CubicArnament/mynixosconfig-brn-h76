#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-}"
if [[ -z "$HOST" ]]; then
  printf "usage: install-honor-magicbook localhost\n" >&2
  exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
  printf "Installation requires root privileges. Re-run with sudo/run0 or from a root shell:\n" >&2
  printf "  sudo nix run .#install-honor-magicbook -- localhost\n" >&2
  exit 2
fi

if [[ ! -c /dev/tty || ! -r /dev/tty || ! -w /dev/tty ]] || ! (: < /dev/tty) 2>/dev/null; then
  printf "Installation requires direct access to an interactive TTY.\n" >&2
  exit 2
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
LOCAL_DEVICE_PATHS_REL="local-device-paths.nix"

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

HPASSWD_REL="env.hpasswd"

case "$HOST" in
  localhost|127.0.0.1|::1)
    printf "==> [local] Detecting disks...\n"
    bash "$LIBEXEC_DIR/local/fetch.sh" "$LOCAL_DEVICE_PATHS_REL"

    printf "\n==> [local] Generating initial password...\n"
    bash "$LIBEXEC_DIR/local/gen-hpasswd.sh" "$HPASSWD_REL"

    printf "\n==> [local] Installing...\n"
    exec bash "$LIBEXEC_DIR/local/install.sh" \
      "$HOST_NAME" "$LOCAL_DEVICE_PATHS_REL" "path:$REPO_ROOT"
    ;;
  *)
    printf "ERROR: Only localhost installation is supported.\n" >&2
    printf "This installer requires direct physical access to the keyboard and screen.\n" >&2
    printf "Boot the NixOS ISO on the Honor MagicBook and run as root: nix run .#install-honor-magicbook -- localhost\n" >&2
    exit 2
    ;;
esac
