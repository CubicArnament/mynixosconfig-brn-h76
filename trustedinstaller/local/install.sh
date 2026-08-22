#!/usr/bin/env bash
set -euo pipefail

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

HOST_NAME="${1:-}"
LOCAL_DEVICE_PATHS_REL="${2:-}"
FLAKE_REF="${3:-path:$PWD}"

if [[ -z "$HOST_NAME" || -z "$LOCAL_DEVICE_PATHS_REL" ]]; then
  printf "usage: %s <host-name> <local-device-paths-file> [flake-ref]\n" "$0" >&2
  exit 1
fi

if [[ ! -f "$LOCAL_DEVICE_PATHS_REL" ]]; then
  printf "Missing generated device file: %s\n" "$LOCAL_DEVICE_PATHS_REL" >&2
  printf "Run the complete installer or fetch-target-device-paths first.\n" >&2
  exit 2
fi

HPASSWD_REL="$(dirname "$LOCAL_DEVICE_PATHS_REL")/env.hpasswd"
HPASSWD=""
if [[ -s "$HPASSWD_REL" ]]; then
  IFS= read -r HPASSWD < "$HPASSWD_REL" || true
fi
case "$HPASSWD" in
  "\$y\$"*|"\$6\$"*) ;;
  *)
    printf "Missing or invalid generated password hash: %s\n" "$HPASSWD_REL" >&2
    printf "Run the complete installer or gen-hpasswd first.\n" >&2
    exit 2
    ;;
esac

if VIRTUALIZATION=$(systemd-detect-virt 2>/dev/null); then
  printf "Refusing installation in virtualized environment: %s\n" "$VIRTUALIZATION" >&2
  printf "Disk discovery and nix builds are allowed in VMs/WSL; installation requires the physical Honor laptop.\n" >&2
  exit 2
fi

if [[ ! -d /sys/firmware/efi ]]; then
  printf "Refusing installation: boot the NixOS ISO in UEFI mode.\n" >&2
  exit 2
fi

if [[ ! -c /dev/tty || ! -r /dev/tty || ! -w /dev/tty ]] || ! (: < /dev/tty) 2>/dev/null; then
  printf "Refusing installation without a directly accessible interactive TTY.\n" >&2
  exit 2
fi

read_dmi() {
  local path="/sys/class/dmi/id/$1"
  if [[ -r "$path" ]]; then
    tr -d '\000\r\n' < "$path" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
  else
    printf '<unavailable>'
  fi
}

normalize_dmi() {
  printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | sed 's/[[:space:]][[:space:]]*/ /g'
}

DMI_SYS_VENDOR=$(read_dmi sys_vendor)
DMI_PRODUCT_NAME=$(read_dmi product_name)
DMI_PRODUCT_VERSION=$(read_dmi product_version)
DMI_PRODUCT_FAMILY=$(read_dmi product_family)
DMI_BOARD_VENDOR=$(read_dmi board_vendor)
DMI_BOARD_NAME=$(read_dmi board_name)

DMI_VENDOR_TEXT=$(normalize_dmi "$DMI_SYS_VENDOR $DMI_BOARD_VENDOR")
DMI_MODEL_TEXT=$(normalize_dmi "$DMI_PRODUCT_NAME $DMI_PRODUCT_VERSION $DMI_PRODUCT_FAMILY $DMI_BOARD_NAME")

KNOWN_VENDOR=0
KNOWN_MODEL=0
[[ "$DMI_VENDOR_TEXT" == *HONOR* || "$DMI_VENDOR_TEXT" == *HUAWEI* ]] && KNOWN_VENDOR=1
[[ "$DMI_MODEL_TEXT" == *BRN-H76* || "$DMI_MODEL_TEXT" == *"MAGICBOOK X16 PRO"* ]] && KNOWN_MODEL=1

printf "Detected target hardware:\n"
printf "  sys_vendor      = %s\n" "$DMI_SYS_VENDOR"
printf "  product_name    = %s\n" "$DMI_PRODUCT_NAME"
printf "  product_version = %s\n" "$DMI_PRODUCT_VERSION"
printf "  product_family  = %s\n" "$DMI_PRODUCT_FAMILY"
printf "  board_vendor    = %s\n" "$DMI_BOARD_VENDOR"
printf "  board_name      = %s\n" "$DMI_BOARD_NAME"

if (( KNOWN_VENDOR == 0 || KNOWN_MODEL == 0 )); then
  DMI_CONFIRM_TOKEN="ALLOW-UNRECOGNIZED-HOST"
  printf "\nWARNING: DMI does not match a known Honor MagicBook X16 Pro variant.\n" > /dev/tty
  printf "The configuration may still work, but hardware-specific settings can be incompatible.\n" > /dev/tty
  printf "Type %s to continue: " "$DMI_CONFIRM_TOKEN" > /dev/tty
  DMI_CONFIRM=""
  IFS= read -r DMI_CONFIRM < /dev/tty || true
  if [[ "$DMI_CONFIRM" != "$DMI_CONFIRM_TOKEN" ]]; then
    printf "Aborted due to unrecognized target hardware.\n" >&2
    exit 2
  fi
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
  CONFIRM=""; IFS= read -r CONFIRM < /dev/tty || true
  if [[ "$CONFIRM" != "$CONFIRM_TOKEN" ]]; then
    printf "Aborted.\n" >&2; exit 3
  fi
fi

DISK_REAL_FINAL=$(readlink -f "$DISK_DEVICE" 2>/dev/null || true)
if [[ "$DISK_REAL_FINAL" != "$DISK_REAL" ]]; then
  printf "CRITICAL: Disk symlink changed during confirmation. Aborting.\n" >&2
  exit 2
fi

# Probe for exclusive access without holding the lock: disko needs to reread the
# partition table, and a retained exclusive open would make that fail with EBUSY.
if ! flock --exclusive --nonblock "$DISK_REAL" true; then
  printf "CRITICAL: Disk %s is in exclusive use by another process. Aborting.\n" "$DISK_REAL" >&2
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

set +e
nix --extra-experimental-features "nix-command flakes" \
  run .#disko-install -- \
  --flake "${FLAKE_REF}#${HOST_NAME}" \
  --disk main "$DISK_DEVICE"
INSTALL_STATUS=$?
set -e

if [[ "$INSTALL_STATUS" -ne 0 ]]; then
  printf "Installation failed; the selected disk may be partially modified. Do not reboot until the failure is resolved.\n" >&2
  exit 1
fi

unset HPASSWD
printf "\nDone. You can reboot now.\n"
printf "\n"
printf "==============================================\n"
printf "  CRITICAL: CHANGE YOUR PASSWORD IMMEDIATELY\n"
printf "==============================================\n"
printf "\n"
printf "After reboot, login with the password you set during installation,\n"
printf "then immediately change it:\n"
printf "\n"
printf "  run0 passwd wkubearnament\n"
printf "\n"
printf "The initial password from env.hpasswd is for first login only.\n"
printf "\n"
