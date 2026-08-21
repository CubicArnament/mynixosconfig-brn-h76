#!/usr/bin/env bash
set -euo pipefail

elevate() {
  if [[ "$EUID" -eq 0 ]]; then
    "$@"
  elif command -v run0 &>/dev/null; then
    run0 "$@"
  elif command -v sudo &>/dev/null; then
    sudo "$@"
  elif command -v doas &>/dev/null; then
    doas "$@"
  else
    printf "Root privilege required. Run nixos-helper as root or install run0, sudo, or doas.\n" >&2
    exit 1
  fi
}

run_system_rebuild() {
  local action="$1"
  shift
  elevate nixos-rebuild "$action" --flake "$NIXOS_HELPER_FLAKE" "$@"
}
