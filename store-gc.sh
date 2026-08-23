#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
  printf "Run this script as root, for example: sudo ./store-gc.sh\n" >&2
  exit 2
fi

export NIX_CONFIG="
experimental-features = nix-command flakes
fallback = false
"
exec nix store gc
