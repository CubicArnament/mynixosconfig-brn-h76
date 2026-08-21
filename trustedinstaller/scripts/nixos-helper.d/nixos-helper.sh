#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="${NIXOS_HELPER_COMMANDS_DIR:-$SCRIPT_DIR/commands}"
if [[ ! -d "$COMMANDS_DIR" ]]; then
  printf "nixos-helper command directory is missing: %s\n" "$COMMANDS_DIR" >&2
  exit 1
fi

COMMAND="${1:-switch}"
[[ "$#" -gt 0 ]] && shift

case "$COMMAND" in
  -h|--help) COMMAND="help" ;;
  switch|boot|test|build|home|update|status|generations|rollback|clean|diff|config-setup|prefetch|set-password) ;;
  *)
    printf "Unknown command: %s\n" "$COMMAND" >&2
    "$COMMANDS_DIR/help.sh" >&2
    exit 2
    ;;
esac

exec "$COMMANDS_DIR/$COMMAND.sh" "$@"
