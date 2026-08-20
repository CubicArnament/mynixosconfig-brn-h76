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

if [[ "$DISK_DEVICE" == *"CONFIGURE-ME"* ]]; then
  printf "CRITICAL: Placeholder disk device detected at runtime\n" >&2
  exit 2
fi
if ! LC_ALL=C printf '%s' "${DISK_DEVICE##*/}" | grep -q '^[A-Za-z0-9._+:-]*$'; then
  printf "Refusing disk path with non-ASCII characters: %s\n" "$DISK_DEVICE" >&2
  exit 2
fi
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

DISK_SIZE=$(lsblk -dnbo SIZE "$DISK_REAL" 2>/dev/null | tr -d '[:space:]')
DISK_MODEL=$(lsblk -dnro MODEL "$DISK_REAL" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
if [[ ! "$DISK_SIZE" =~ ^[0-9]+$ || "$DISK_SIZE" -lt 34359738368 ]]; then
  printf "Refusing install disk smaller than 32 GiB: %s\n" "$DISK_DEVICE" >&2
  exit 2
fi
if [[ "$DISK_SIZE" -gt 10995116277760 ]]; then
  printf "Refusing suspiciously large disk (>10TB): %s bytes\n" "$DISK_SIZE" >&2
  exit 2
fi

OCCUPANCY_REASONS=()
if lsblk -nrpo MOUNTPOINT "$DISK_REAL" 2>/dev/null | awk 'NF { found=1 } END { exit !found }'; then
  OCCUPANCY_REASONS+=(mountpoints)
fi
while IFS= read -r NODE; do
  [[ -n "$NODE" ]] || continue
  HOLDER_DIR="/sys/class/block/$(basename "$NODE")/holders"
  if [[ -d "$HOLDER_DIR" ]] && compgen -G "$HOLDER_DIR/*" > /dev/null; then
    OCCUPANCY_REASONS+=(holders)
    break
  fi
done < <(lsblk -nrpo PATH "$DISK_REAL" 2>/dev/null)
ROOT_SOURCE=$(findmnt -n -o SOURCE / 2>/dev/null || true)
ROOT_SOURCE=${ROOT_SOURCE%%\[*}
if [[ -n "$ROOT_SOURCE" ]] && lsblk -snpo PATH,TYPE "$ROOT_SOURCE" 2>/dev/null \
  | awk -v disk="$DISK_REAL" '$2 == "disk" && $1 == disk { found=1 } END { exit !found }'; then
  OCCUPANCY_REASONS+=(current-root)
fi
if (( ${#OCCUPANCY_REASONS[@]} > 0 )) && [[ "${INSTALL_ALLOW_OCCUPIED_DISK:-}" != "YES" ]]; then
  printf "Refusing occupied install disk (%s): %s\n" "$(IFS=,; printf '%s' "${OCCUPANCY_REASONS[*]}")" "$DISK_DEVICE" >&2
  printf "For an intentional reinstall, re-run with INSTALL_ALLOW_OCCUPIED_DISK=YES.\n" >&2
  exit 2
fi

printf "\n"
printf "WARNING: ALL DATA ON THE FOLLOWING DISK WILL BE PERMANENTLY DESTROYED:\n"
printf "  diskDevice = %s\n" "$DISK_DEVICE"
printf "  realPath   = %s\n" "$DISK_REAL"
printf "  model      = %s\n" "${DISK_MODEL:-unknown}"
printf "  size       = %s bytes\n" "$DISK_SIZE"
printf "  host       = %s\n" "$HOST_NAME"
printf "  mode       = local (disko-install)\n"
printf "\n"

CONFIRM_TOKEN=${DISK_DEVICE##*/}
if [[ -c /dev/tty && -r /dev/tty && -w /dev/tty ]] && (: < /dev/tty) 2>/dev/null; then
  printf "Type %s to confirm: " "$CONFIRM_TOKEN" > /dev/tty
  CONFIRM=""; IFS= read -r -t 60 CONFIRM < /dev/tty || true
  if [[ "$CONFIRM" != "$CONFIRM_TOKEN" ]]; then
    printf "Aborted.\n" >&2; exit 3
  fi
else
  printf "Non-interactive installation explicitly approved.\n"
fi

DISK_REAL_FINAL=$(readlink -f "$DISK_DEVICE" 2>/dev/null || true)
if [[ "$DISK_REAL_FINAL" != "$DISK_REAL" ]]; then
  printf "CRITICAL: Disk symlink changed during confirmation. Aborting.\n" >&2
  exit 2
fi

if lsblk -nrpo MOUNTPOINT "$DISK_REAL" 2>/dev/null | awk 'NF { found=1 } END { exit !found }'; then
  printf "CRITICAL: Disk became mounted during confirmation. Aborting.\n" >&2
  exit 2
fi
while IFS= read -r NODE; do
  [[ -n "$NODE" ]] || continue
  HOLDER_DIR="/sys/class/block/$(basename "$NODE")/holders"
  if [[ -d "$HOLDER_DIR" ]] && compgen -G "$HOLDER_DIR/*" > /dev/null; then
    printf "CRITICAL: Disk acquired holders during confirmation. Aborting.\n" >&2
    exit 2
  fi
done < <(lsblk -nrpo PATH "$DISK_REAL" 2>/dev/null)

printf "Running disko-install...\n"

if ! nix --extra-experimental-features "nix-command flakes" \
  run .#disko-install -- \
  --flake ".#${HOST_NAME}" \
  --disk main "$DISK_DEVICE"; then
  printf "Installation failed; the selected disk may be partially modified. Do not reboot until the failure is resolved.\n" >&2
  exit 1
fi

printf "\nDone. You can reboot now.\n"
