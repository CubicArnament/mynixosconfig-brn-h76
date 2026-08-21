#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-$PWD}"
[[ "$#" -gt 0 ]] && shift
if [[ ! -e "$TARGET" ]]; then
  printf "Format target does not exist: %s\n" "$TARGET" >&2
  exit 2
fi

TARGET=$(realpath "$TARGET")
exec "$NIX_HLP_FORMATTER" --tree-root "$TARGET" "$TARGET" "$@"
