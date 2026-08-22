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

MIN_FREE_BYTES="${INSTALL_MIN_FREE_BYTES:-536870912}"
MIN_FREE_INODES="${INSTALL_MIN_FREE_INODES:-5000}"
if ! [[ "$MIN_FREE_BYTES" =~ ^[0-9]+$ ]] || (( MIN_FREE_BYTES < 134217728 )); then
  printf "INSTALL_MIN_FREE_BYTES must be an integer of at least 134217728.\n" >&2
  exit 2
fi
if ! [[ "$MIN_FREE_INODES" =~ ^[0-9]+$ ]]; then
  printf "INSTALL_MIN_FREE_INODES must be a non-negative integer.\n" >&2
  exit 2
fi

check_live_space() {
  local path="$1" label="$2" available_bytes available_inodes
  available_bytes=$(df -PB1 --output=avail "$path" | tail -n 1 | tr -d '[:space:]')
  available_inodes=$(df -Pi --output=iavail "$path" | tail -n 1 | tr -d '[:space:]')
  if ! [[ "$available_bytes" =~ ^[0-9]+$ && "$available_inodes" =~ ^[0-9]+$ ]]; then
    printf "Cannot determine free space for %s (%s).\n" "$label" "$path" >&2
    exit 2
  fi
  printf "  %-12s %8s MiB free, %s inodes free (%s)\n" \
    "$label" "$(( available_bytes / 1024 / 1024 ))" "$available_inodes" "$path"
  if (( available_bytes < MIN_FREE_BYTES || available_inodes < MIN_FREE_INODES )); then
    printf "Insufficient writable space for installation in %s.\n" "$path" >&2
    printf "Required: at least %s MiB and %s inodes.\n" \
      "$(( MIN_FREE_BYTES / 1024 / 1024 ))" "$MIN_FREE_INODES" >&2
    return 1
  fi
}

ensure_store_space() {
  if check_live_space /nix/store "Nix store"; then
    return 0
  fi

  printf "Formatting the target SSD will not free the live-ISO Nix store.\n" >&2
  printf "Type YES to garbage-collect unused paths from the live store: " > /dev/tty
  GC_CONFIRM=""
  IFS= read -r GC_CONFIRM < /dev/tty || true
  if [[ "$GC_CONFIRM" != "YES" ]]; then
    printf "Aborted because the live Nix store has insufficient space.\n" >&2
    exit 2
  fi

  nix --extra-experimental-features "nix-command flakes" store gc
  printf "Rechecking live Nix store after garbage collection:\n"
  if ! check_live_space /nix/store "Nix store"; then
    printf "The live Nix store is still too small. Reboot the ISO and run the installer before any test builds.\n" >&2
    exit 2
  fi
}

printf "Checking writable live-system space before collecting install inputs:\n"
ensure_store_space
if ! check_live_space "${TMPDIR:-/tmp}" "Temporary"; then
  printf "The temporary filesystem is too small; clear /tmp or reboot the live ISO.\n" >&2
  exit 2
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"
if ! check_live_space "$REPO_ROOT" "Repository"; then
  printf "The filesystem containing the repository is too small.\n" >&2
  exit 2
fi

if [[ -n "${NIX_CONFIG:-}" ]] && grep -Eq '(^|[[:space:]])no-write-lock-file[[:space:]]*=' <<< "$NIX_CONFIG"; then
  printf "WARNING: NIX_CONFIG contains 'no-write-lock-file = ...', which is not a valid nix.conf setting.\n" >&2
  printf "Use the CLI flag --no-write-lock-file instead or remove that line from NIX_CONFIG.\n" >&2
fi

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
