#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

DAYS="${1:-7}"
if ! [[ "$DAYS" =~ ^[1-9][0-9]*$ ]]; then
  printf "Usage: nix-hlp clean [positive-days]\n" >&2
  exit 2
fi

printf "Removing generations older than %s days...\n" "$DAYS"
elevate nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than "${DAYS}d"
elevate nix-collect-garbage --delete-older-than "${DAYS}d"
