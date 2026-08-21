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
    printf "Root privilege required. Install sudo, doas, or systemd (run0).\n" >&2
    exit 1
  fi
}

case "${1:-switch}" in
  -h|--help)
    cat <<'EOF'
Usage: nixos-helper [command] [options]

Uses the configured host flake at /etc/nixos. System rebuilds also
activate the configured Home Manager user environment.

Commands:
  switch        Build and apply now. This is the default.
  boot          Build now, activate on the next boot.
  test          Build and activate until the next boot.
  build         Build without activating.
  update        Update flake.lock in /etc/nixos.
  status        Show current generation and boot entry.
  generations   List recent system generations.
  rollback      Roll back to the previous generation.
  clean         Remove old generations (keeps 7 days by default).
  diff          Show pending configuration changes.
  config-setup  Setup userspace development with /etc/nixos symlink.
  prefetch <url>
                Print a fetchurl SRI hash for dev/maintaining packages.
  set-password  Set the local password for wkubearnament.

All nixos-rebuild options are passed through.
EOF
    ;;
  update)
    shift
    elevate nix flake update --flake /etc/nixos "$@"
    ;;
  status)
    printf "Current generation: "
    readlink /nix/var/nix/profiles/system | sed 's/.*system-//'
    printf "Boot entry: "
    readlink /run/booted-system | sed 's/.*system-//' || printf "not booted from NixOS\n"
    ;;
  generations)
    nix profile history --profile /nix/var/nix/profiles/system | tail -20
    ;;
  rollback)
    shift
    elevate nixos-rebuild switch --flake "$NIXOS_HELPER_FLAKE" --rollback "$@"
    ;;
  clean)
    DAYS="${2:-7}"
    printf "Removing generations older than %s days...\n" "$DAYS"
    elevate nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than "${DAYS}d"
    elevate nix-collect-garbage -d
    ;;
  diff)
    elevate nixos-rebuild build --flake "$NIXOS_HELPER_FLAKE"
    nix store diff-closures /run/current-system ./result
    ;;
  config-setup)
    TARGET_DIR="${2:-$PWD}"
    if [[ ! -f "$TARGET_DIR/flake.nix" ]]; then
      printf "No flake.nix found in %s\n" "$TARGET_DIR" >&2
      exit 2
    fi
    TARGET_DIR=$(cd "$TARGET_DIR" && pwd)
    printf "Setting up userspace NixOS config development:\n"
    printf "  Source: %s\n" "$TARGET_DIR"
    printf "  Target: /etc/nixos (symlink)\n"
    if [[ -e /etc/nixos && ! -L /etc/nixos ]]; then
      printf "ERROR: /etc/nixos exists and is not a symlink. Move it first.\n" >&2
      exit 2
    fi
    elevate rm -f /etc/nixos
    elevate ln -s "$TARGET_DIR" /etc/nixos
    elevate chown -h "$USER:users" /etc/nixos 2>/dev/null || true
    printf "Done. You can now edit configs in %s and run:\n" "$TARGET_DIR"
    printf "  nixos-helper switch\n"
    ;;
  prefetch)
    shift
    exec nix-prefetch-maintaining "$@"
    ;;
  set-password)
    if [[ "$#" -ne 1 ]]; then
      printf '%s\n' "Usage: nixos-helper set-password" >&2
      exit 2
    fi
    cat <<'EOF'
This sets the local password for wkubearnament.
The installer-generated password works for the initial login. Change it
immediately after installation and whenever account recovery is needed.
EOF
    exec passwd
    ;;
  *)
    elevate nixos-rebuild "$@" --flake "$NIXOS_HELPER_FLAKE"
    ;;
esac
