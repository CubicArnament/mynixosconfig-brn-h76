#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

elevate nixos-rebuild build --flake "$NIXOS_HELPER_FLAKE" "$@"
nix store diff-closures /run/current-system ./result
