#!/usr/bin/env bash
# scripts/install-remote.sh
#
# bash — удалённая установка NixOS через nixos-anywhere по SSH.
#
# Использование:
#   install-remote.sh <host-name> <ssh-target> <local-device-paths-file>
set -euo pipefail

HOST_NAME="${1:-}"
SSH_TARGET="${2:-}"
LOCAL_DEVICE_PATHS_REL="${3:-}"

if [[ -z "$HOST_NAME" || -z "$SSH_TARGET" || -z "$LOCAL_DEVICE_PATHS_REL" ]]; then
  printf "usage: %s <host-name> <ssh-target> <local-device-paths-file>\n" "$0" >&2
  exit 1
fi

DISK_DEVICE=$(grep 'diskDevice' "$LOCAL_DEVICE_PATHS_REL" | sed 's/.*"\(.*\)".*/\1/')

printf "\n"
printf "WARNING: ALL DATA ON THE FOLLOWING DISK WILL BE PERMANENTLY DESTROYED:\n"
printf "  diskDevice = %s\n" "$DISK_DEVICE"
printf "  target     = %s\n" "$SSH_TARGET"
printf "\n"

if [[ -t 0 ]]; then
  printf "Type 'YES' to confirm destructive install, anything else aborts: "
  CONFIRM=""
  IFS= read -r -t 30 CONFIRM || true
  if [[ "${CONFIRM^^}" != "YES" ]]; then
    printf "Aborted.\n" >&2
    exit 3
  fi
else
  printf "Non-interactive mode: proceeding automatically.\n"
fi

printf "Remote install: running nixos-anywhere on %s...\n" "$SSH_TARGET"
nix --extra-experimental-features "nix-command flakes" run github:nix-community/nixos-anywhere -- \
  --flake ".#${HOST_NAME}" \
  "$SSH_TARGET"

printf "Installation complete.\n"
