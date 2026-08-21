#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
if [[ ! -f /etc/nixos/flake.nix ]]; then
  printf "The update command requires a flake-based /etc/nixos.\n" >&2
  exit 2
fi
elevate nix flake update --flake /etc/nixos "$@"
