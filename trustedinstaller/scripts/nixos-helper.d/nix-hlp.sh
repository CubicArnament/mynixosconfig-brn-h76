#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="${NIX_HLP_COMMANDS_DIR:-$SCRIPT_DIR/commands}"
TEMPLATES_DIR="${NIX_HLP_TEMPLATES_DIR:-$SCRIPT_DIR/templates}"
if [[ ! -d "$COMMANDS_DIR" ]]; then
  printf "nix-hlp command directory is missing: %s\n" "$COMMANDS_DIR" >&2
  exit 1
fi
export NIX_HLP_TEMPLATES_DIR="$TEMPLATES_DIR"

COMMAND="${1:-switch}"
[[ "$#" -gt 0 ]] && shift

case "$COMMAND" in
  -h|--help) COMMAND="help" ;;
  switch|boot|test|build|home|update|status|generations|rollback|clean|diff|config-setup|prefetch|set-password|fmt|gen) ;;
  *)
    printf "Unknown command: %s\n" "$COMMAND" >&2
    bash "$COMMANDS_DIR/help.sh" >&2
    exit 2
    ;;
esac

exec bash "$COMMANDS_DIR/$COMMAND.sh" "$@"
