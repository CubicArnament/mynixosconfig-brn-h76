#!/usr/bin/env bash
set -euo pipefail

TEMPLATE="${1:-}"
TARGET="${2:-$PWD}"

if [[ -z "$TEMPLATE" ]]; then
  printf "Usage: nix-hlp create <project_flake|nix_shell|app_run|app_build|btp> [directory]\n" >&2
  exit 2
fi

case "$TEMPLATE" in
  project_flake|nix_shell|app_run|app_build|btp) ;;
  *)
    printf "Unknown template: %s\n" "$TEMPLATE" >&2
    exit 2
    ;;
esac

mkdir -p "$TARGET"
TARGET=$(cd "$TARGET" && pwd)
exec bash "$NIX_HLP_TEMPLATES_DIR/$TEMPLATE.sh" "$TARGET"
