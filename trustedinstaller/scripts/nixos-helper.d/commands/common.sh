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
    printf "Root privilege required. Run nix-hlp as root or install run0, sudo, or doas.\n" >&2
    exit 1
  fi
}

run_system_rebuild() {
  local action="$1"
  shift
  if [[ -f /etc/nixos/flake.nix ]]; then
    elevate nixos-rebuild "$action" --flake "$NIX_HLP_FLAKE" "$@"
  elif [[ -f /etc/nixos/configuration.nix ]]; then
    elevate nixos-rebuild "$action" -I nixos-config=/etc/nixos/configuration.nix "$@"
  else
    printf "No flake.nix or configuration.nix found under /etc/nixos.\n" >&2
    exit 2
  fi
}

validate_nixos_config() {
  local root="$1"
  local configuration=""

  if [[ -f "$root/flake.nix" ]]; then
    if ! grep -Eq 'nixosConfigurations[[:space:]]*(=|\.)|nixosSystem[[:space:]]*\{' "$root/flake.nix"; then
      printf "flake.nix does not expose a NixOS configuration.\n" >&2
      return 1
    fi
    configuration=$(find "$root" -maxdepth 4 -type f -name configuration.nix -print -quit)
    if [[ -z "$configuration" ]]; then
      printf "NixOS flake has no configuration.nix within four directory levels.\n" >&2
      return 1
    fi
    if ! grep -Eq 'system\.stateVersion|boot\.loader|fileSystems|networking\.hostName|services\.' "$configuration"; then
      printf "The flake configuration.nix does not contain recognizable NixOS options.\n" >&2
      return 1
    fi
    return 0
  fi

  if [[ -f "$root/configuration.nix" ]]; then
    if ! grep -Eq 'system\.stateVersion|boot\.loader|fileSystems|networking\.hostName|services\.' "$root/configuration.nix"; then
      printf "configuration.nix does not contain recognizable NixOS options.\n" >&2
      return 1
    fi
    return 0
  fi

  printf "Expected a NixOS flake or a legacy configuration.nix in %s.\n" "$root" >&2
  return 1
}
