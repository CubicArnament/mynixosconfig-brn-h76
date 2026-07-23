#!/usr/bin/env bash
# scripts/install-local.sh
#
# bash — локальная установка NixOS через disko + nixos-install.
# Запускать с live-ISO NixOS на целевом железе.
#
# Использование:
#   install-local.sh <host-name> <local-device-paths-file>
set -euo pipefail

HOST_NAME="${1:-}"
LOCAL_DEVICE_PATHS_REL="${2:-}"

if [[ -z "$HOST_NAME" || -z "$LOCAL_DEVICE_PATHS_REL" ]]; then
  printf "usage: %s <host-name> <local-device-paths-file>\n" "$0" >&2
  exit 1
fi

DISK_DEVICE=$(grep 'diskDevice' "$LOCAL_DEVICE_PATHS_REL" | sed 's/.*"\(.*\)".*/\1/')

printf "\n"
printf "WARNING: ALL DATA ON THE FOLLOWING DISK WILL BE PERMANENTLY DESTROYED:\n"
printf "  diskDevice = %s\n" "$DISK_DEVICE"
printf "  target     = localhost\n"
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

printf "Local install: running disko...\n"
nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- \
  --mode destroy,format,mount \
  --flake ".#${HOST_NAME}"

printf "Running nixos-install...\n"
nixos-install \
  --no-root-passwd \
  --flake ".#${HOST_NAME}"

printf "Installation complete.\n"
