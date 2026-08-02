#!/usr/bin/env bash
# trustedinstaller/local/install.sh
#
# bash — локальная установка NixOS через disko-install.
# Запускать с minimal NixOS ISO на целевом железе.
#
# Использование:
#   install.sh <host-name> <local-device-paths-file>
set -euo pipefail

HOST_NAME="${1:-}"
LOCAL_DEVICE_PATHS_REL="${2:-}"

if [[ -z "$HOST_NAME" || -z "$LOCAL_DEVICE_PATHS_REL" ]]; then
  printf "usage: %s <host-name> <local-device-paths-file>\n" "$0" >&2
  exit 1
fi

if VIRTUALIZATION=$(systemd-detect-virt 2>/dev/null); then
  printf "Refusing installation in virtualized environment: %s\n" "$VIRTUALIZATION" >&2
  printf "Disk discovery and nix builds are allowed in VMs/WSL; installation requires the physical Honor laptop.\n" >&2
  exit 2
fi

if [[ ! -d /sys/firmware/efi ]]; then
  printf "Refusing installation: boot the NixOS ISO in UEFI mode.\n" >&2
  exit 2
fi

if [[ "$(< /sys/class/dmi/id/sys_vendor)" != "HONOR" || "$(< /sys/class/dmi/id/product_name)" != "BRN-H76" ]]; then
  printf "Refusing installation: this installer is restricted to HONOR BRN-H76.\n" >&2
  exit 2
fi

if [[ ! -t 0 && "${INSTALL_NONINTERACTIVE:-}" != "YES" ]]; then
  printf "Refusing non-interactive installation. Set INSTALL_NONINTERACTIVE=YES to opt in.\n" >&2
  exit 2
fi

DISK_DEVICE=$(grep 'diskDevice' "$LOCAL_DEVICE_PATHS_REL" | sed 's/.*"\(.*\)".*/\1/')

printf "\n"
printf "WARNING: ALL DATA ON THE FOLLOWING DISK WILL BE PERMANENTLY DESTROYED:\n"
printf "  diskDevice = %s\n" "$DISK_DEVICE"
printf "  host       = %s\n" "$HOST_NAME"
printf "  mode       = local (disko-install)\n"
printf "\n"

if [[ -t 0 ]]; then
  printf "Type YES to confirm, anything else aborts: "
  CONFIRM=""; IFS= read -r -t 30 CONFIRM || true
  if [[ "${CONFIRM^^}" != "YES" ]]; then
    printf "Aborted.\n" >&2; exit 3
  fi
else
  printf "Non-interactive installation explicitly approved.\n"
fi

printf "Running disko-install...\n"

# disko-install = разметка диска + nixos-install в один шаг.
# --disk main <device> переопределяет disko.devices.disk.main.device из CLI.
nix --extra-experimental-features "nix-command flakes" \
  run .#disko-install -- \
  --flake ".#${HOST_NAME}" \
  --disk main "$DISK_DEVICE"

printf "\nDone. You can reboot now.\n"
