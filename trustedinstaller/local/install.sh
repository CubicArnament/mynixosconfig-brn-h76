#!/usr/bin/env bash
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

DISK_DEVICE=$(
  LC_ALL=C awk '
    /^[[:space:]]*diskDevice[[:space:]]*=/ {
      seen++
      if ($0 !~ /^[[:space:]]*diskDevice[[:space:]]*=[[:space:]]*"\/dev\/disk\/by-id\/[A-Za-z0-9._+:-]+";[[:space:]]*$/) {
        invalid = 1
      }
      value = $0
      sub(/^[^"]*"/, "", value)
      sub(/".*$/, "", value)
    }
    END {
      if (seen != 1 || invalid) exit 1
      print value
    }
  ' "$LOCAL_DEVICE_PATHS_REL"
) || {
  printf "Refusing invalid or ambiguous diskDevice in %s.\n" "$LOCAL_DEVICE_PATHS_REL" >&2
  exit 2
}

if [[ ! "$DISK_DEVICE" =~ ^/dev/disk/by-id/[A-Za-z0-9._+:-]+$ ]]; then
  printf "Refusing unsafe install disk path: %s\n" "$DISK_DEVICE" >&2
  exit 2
fi
if [[ "${DISK_DEVICE##*/}" == *-part* ]]; then
  printf "Refusing partition path as install disk: %s\n" "$DISK_DEVICE" >&2
  exit 2
fi

DISK_REAL=$(readlink -f "$DISK_DEVICE" 2>/dev/null || true)
if [[ ! -L "$DISK_DEVICE" || -z "$DISK_REAL" || ! -b "$DISK_REAL" \
      || "$(lsblk -ndo TYPE "$DISK_REAL" 2>/dev/null)" != "disk" ]]; then
  printf "Refusing diskDevice that is not a whole block disk: %s\n" "$DISK_DEVICE" >&2
  exit 2
fi

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

nix --extra-experimental-features "nix-command flakes" \
  run .#disko-install -- \
  --flake ".#${HOST_NAME}" \
  --disk main "$DISK_DEVICE"

printf "\nDone. You can reboot now.\n"
