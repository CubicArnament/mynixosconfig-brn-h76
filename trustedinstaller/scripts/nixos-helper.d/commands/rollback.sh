#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
elevate nixos-rebuild switch --flake "$NIXOS_HELPER_FLAKE" --rollback "$@"
