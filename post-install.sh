#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -eq 0 ]]; then
  printf "Run this script as the installed user, not as root. It will request elevation for the switch.\n" >&2
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

export NIX_CONFIG="experimental-features = nix-command flakes"

printf "Detecting the disk that backs the currently running root filesystem...\n"
INSTALL_DISK_FILTER=system nix run --no-write-lock-file \
  .#fetch-target-device-paths -- localhost local-device-paths.nix

if [[ ! -s local-device-paths.nix ]]; then
  printf "Failed to generate local-device-paths.nix.\n" >&2
  exit 2
fi

printf "Building and activating the full configuration...\n"
run0 nixos-rebuild switch \
  --no-reexec \
  --flake "path:$SCRIPT_DIR#honor-magicbook-x16-pro" \
  --show-trace \
  --print-build-logs \
  --log-format bar-with-logs

printf "\nFull configuration activated. Link this checkout to /etc/nixos with:\n"
printf "  nix-hlp config-setup %s\n" "$SCRIPT_DIR"
