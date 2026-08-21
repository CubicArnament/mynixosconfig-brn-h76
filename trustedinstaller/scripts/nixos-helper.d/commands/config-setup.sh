#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

TARGET_DIR="${1:-$PWD}"
if [[ ! -f "$TARGET_DIR/flake.nix" ]]; then
  printf "No flake.nix found in %s\n" "$TARGET_DIR" >&2
  exit 2
fi

TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
OWNER=$(id -un)
printf "Setting up userspace NixOS config development:\n"
printf "  Source: %s\n" "$TARGET_DIR"
printf "  Target: /etc/nixos (symlink)\n"

if [[ -e /etc/nixos && ! -L /etc/nixos ]]; then
  printf "ERROR: /etc/nixos exists and is not a symlink. Move it first.\n" >&2
  exit 2
fi

elevate rm -f /etc/nixos
elevate ln -s "$TARGET_DIR" /etc/nixos
elevate chown -h "$OWNER:users" /etc/nixos 2>/dev/null || true
printf "Done. Run: nixos-helper switch\n"
