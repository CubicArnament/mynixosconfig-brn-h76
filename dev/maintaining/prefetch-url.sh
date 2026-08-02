#!/usr/bin/env bash
set -euo pipefail

URL="${1:-}"

if [[ -z "$URL" || "$URL" == "-h" || "$URL" == "--help" ]]; then
  printf '%s\n' "Usage: nix-prefetch-maintaining <url>" >&2
  printf '%s\n' "Prints an SRI hash for a fetchurl source in dev/maintaining/*.nix." >&2
  exit 2
fi

nix store prefetch-file --json "$URL" | jq --raw-output .hash
