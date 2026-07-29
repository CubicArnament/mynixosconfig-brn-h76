#!/usr/bin/env sh
# trustedinstaller/remote/install.sh
#
# POSIX sh — удалённая установка NixOS через nixos-anywhere по SSH.
#
# Использование:
#   install.sh <host-name> <ssh-target> <local-device-paths-file>
set -eu

HOST_NAME="${1:-}"
SSH_TARGET="${2:-}"
LOCAL_DEVICE_PATHS_REL="${3:-}"

if [ -z "$HOST_NAME" ] || [ -z "$SSH_TARGET" ] || [ -z "$LOCAL_DEVICE_PATHS_REL" ]; then
  printf "usage: %s <host-name> <ssh-target> <local-device-paths-file>\n" "$0" >&2
  exit 1
fi

if VIRTUALIZATION=$(ssh "$SSH_TARGET" "systemd-detect-virt 2>/dev/null" 2>/dev/null); then
  printf "Refusing installation on virtualized target %s: %s\n" "$SSH_TARGET" "$VIRTUALIZATION" >&2
  printf "Disk discovery and nix builds are allowed in VMs/WSL; installation requires the physical Honor laptop.\n" >&2
  exit 2
fi

DISK_DEVICE=$(grep 'diskDevice' "$LOCAL_DEVICE_PATHS_REL" | sed 's/.*"\(.*\)".*/\1/')

printf "\n"
printf "WARNING: ALL DATA ON THE FOLLOWING DISK WILL BE PERMANENTLY DESTROYED:\n"
printf "  diskDevice = %s\n" "$DISK_DEVICE"
printf "  target     = %s\n" "$SSH_TARGET"
printf "  mode       = remote (nixos-anywhere)\n"
printf "\n"

if [ -t 0 ]; then
  printf "Type YES to confirm, anything else aborts: "
  CONFIRM=""
  IFS= read -r CONFIRM || true
  CONFIRM_UC=$(printf "%s" "$CONFIRM" | tr '[:lower:]' '[:upper:]')
  if [ "$CONFIRM_UC" != "YES" ]; then
    printf "Aborted.\n" >&2; exit 3
  fi
else
  printf "Non-interactive: proceeding automatically.\n"
fi

printf "Running nixos-anywhere on %s...\n" "$SSH_TARGET"

nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/nixos-anywhere -- \
  --flake ".#${HOST_NAME}" \
  "$SSH_TARGET"

printf "\nInstallation complete.\n"
