#!/usr/bin/env bash
set -euo pipefail
exec home-manager switch --flake "$NIXOS_HELPER_HOME_FLAKE" "$@"
