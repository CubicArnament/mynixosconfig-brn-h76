#!/usr/bin/env bash
set -euo pipefail
if [[ ! -f /etc/nixos/flake.nix ]]; then
  printf "The home command requires a flake-based /etc/nixos.\n" >&2
  exit 2
fi
exec home-manager switch --flake "$NIX_HLP_HOME_FLAKE" "$@"
