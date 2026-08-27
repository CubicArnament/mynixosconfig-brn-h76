#!/usr/bin/env bash
set -euo pipefail

export LANG=C.UTF-8
export LC_ALL=C.UTF-8

HOST_NAME="${1:-}"
SSH_TARGET="${2:-}"
LOCAL_DEVICE_PATHS_REL="${3:-}"
FLAKE_REF="${4:-path:$PWD}"

if [[ -z "$HOST_NAME" || -z "$SSH_TARGET" || -z "$LOCAL_DEVICE_PATHS_REL" ]]; then
  printf "usage: %s <host-name> <user@IPv4> <device-file> [flake-ref]\n" "$0" >&2
  exit 1
fi

if [[ "$EUID" -ne 0 ]]; then
  printf "Remote installation must be started as root.\n" >&2
  exit 2
fi

if [[ ! -c /dev/tty || ! -r /dev/tty || ! -w /dev/tty ]]; then
  printf "An interactive terminal is required.\n" >&2
  exit 2
fi

if ! [[ "$SSH_TARGET" =~ ^[A-Za-z_][A-Za-z0-9._-]*@([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
  printf "Invalid SSH target: %s\n" "$SSH_TARGET" >&2
  exit 2
fi
IP_PART=${SSH_TARGET#*@}
IFS='.' read -r -a IP_OCTETS <<< "$IP_PART"
for IP_OCTET in "${IP_OCTETS[@]}"; do
  if ! [[ "$IP_OCTET" =~ ^[0-9]{1,3}$ ]] || (( 10#$IP_OCTET > 255 )); then
    printf "Invalid IPv4 address in SSH target: %s\n" "$SSH_TARGET" >&2
    exit 2
  fi
done

if [[ ! -f "$LOCAL_DEVICE_PATHS_REL" ]]; then
  printf "Missing generated device file: %s\n" "$LOCAL_DEVICE_PATHS_REL" >&2
  exit 2
fi

HPASSWD_REL="$(dirname "$LOCAL_DEVICE_PATHS_REL")/env.hpasswd"
HPASSWD=""
[[ -s "$HPASSWD_REL" ]] && IFS= read -r HPASSWD < "$HPASSWD_REL" || true
case "$HPASSWD" in
  "\$y\$"*|"\$6\$"*) ;;
  *) printf "Missing or invalid generated password hash: %s\n" "$HPASSWD_REL" >&2; exit 2 ;;
esac

if ! ssh -o ConnectTimeout=10 "$SSH_TARGET" true; then
  printf "Cannot access %s over SSH.\n" "$SSH_TARGET" >&2
  exit 2
fi

if VIRTUALIZATION=$(ssh -n "$SSH_TARGET" "systemd-detect-virt 2>/dev/null" 2>/dev/null); then
  printf "Refusing virtualized target %s: %s\n" "$SSH_TARGET" "$VIRTUALIZATION" >&2
  exit 2
fi

if ! ssh -n "$SSH_TARGET" "test -d /sys/firmware/efi"; then
  printf "Target is not booted in UEFI mode.\n" >&2
  exit 2
fi

DMI_RESULT=$(ssh -n "$SSH_TARGET" sh -s <<'EOF'
read_dmi() { path="/sys/class/dmi/id/$1"; [ -r "$path" ] && tr -d '\000\r\n|' < "$path" || printf '<unavailable>'; }
printf '%s|%s|%s|%s|%s|%s\n' "$(read_dmi sys_vendor)" "$(read_dmi product_name)" \
  "$(read_dmi product_version)" "$(read_dmi product_family)" "$(read_dmi board_vendor)" "$(read_dmi board_name)"
EOF
)
IFS='|' read -r DMI_SYS_VENDOR DMI_PRODUCT_NAME DMI_PRODUCT_VERSION DMI_PRODUCT_FAMILY DMI_BOARD_VENDOR DMI_BOARD_NAME <<< "$DMI_RESULT"
DMI_VENDOR_TEXT=$(printf '%s' "$DMI_SYS_VENDOR $DMI_BOARD_VENDOR" | tr '[:lower:]' '[:upper:]')
DMI_MODEL_TEXT=$(printf '%s' "$DMI_PRODUCT_NAME $DMI_PRODUCT_VERSION $DMI_PRODUCT_FAMILY $DMI_BOARD_NAME" | tr '[:lower:]' '[:upper:]')

printf "Detected remote hardware:\n"
printf "  sys_vendor      = %s\n" "$DMI_SYS_VENDOR"
printf "  product_name    = %s\n" "$DMI_PRODUCT_NAME"
printf "  product_version = %s\n" "$DMI_PRODUCT_VERSION"
printf "  product_family  = %s\n" "$DMI_PRODUCT_FAMILY"
printf "  board_vendor    = %s\n" "$DMI_BOARD_VENDOR"
printf "  board_name      = %s\n" "$DMI_BOARD_NAME"

if [[ "$DMI_VENDOR_TEXT" != *HONOR* && "$DMI_VENDOR_TEXT" != *HUAWEI* ]] \
  || { [[ ! "$DMI_MODEL_TEXT" =~ BRN-H[A-Z0-9]{2} ]] && [[ "$DMI_MODEL_TEXT" != *"MAGICBOOK X16 PRO"* ]]; }; then
  printf "Type YES to continue with this unrecognized remote host: " > /dev/tty
  DMI_CONFIRM=""; IFS= read -r DMI_CONFIRM < /dev/tty || true
  [[ "$DMI_CONFIRM" == "YES" ]] || { printf "Aborted.\n" >&2; exit 2; }
fi

DISK_DEVICE=$(LC_ALL=C awk '
  /^[[:space:]]*diskDevice[[:space:]]*=/ {
    seen++; valid = $0 ~ /^[[:space:]]*diskDevice[[:space:]]*=[[:space:]]*"\/dev\/disk\/by-id\/[A-Za-z0-9._+:-]+";[[:space:]]*$/;
    value=$0; sub(/^[^"]*"/, "", value); sub(/".*$/, "", value)
  }
  END { if (seen != 1 || !valid) exit 1; print value }
' "$LOCAL_DEVICE_PATHS_REL") || { printf "Invalid diskDevice.\n" >&2; exit 2; }
if [[ "${DISK_DEVICE##*/}" == *-part* ]]; then
  printf "Refusing partition path as remote install disk: %s\n" "$DISK_DEVICE" >&2
  exit 2
fi

DISK_STATUS=$(ssh -n "$SSH_TARGET" sh -s -- "$DISK_DEVICE" <<'EOF'
set -eu
[ -L "$disk" ] && [ -b "$real" ] && [ "$(lsblk -ndo TYPE "$real")" = disk ] || exit 1
size=$(lsblk -dnbo SIZE "$real" | tr -d '[:space:]'); model=$(lsblk -dnro MODEL "$real" | sed 's/^ *//; s/ *$//')
case "$size" in ''|*[!0-9]*) exit 1 ;; esac
[ "$size" -ge 34359738368 ] && [ "$size" -le 10995116277760 ] || exit 1
reasons=""
lsblk -nrpo MOUNTPOINT "$real" | awk 'NF { found=1 } END { exit !found }' && reasons=mountpoints || true
for node in $(lsblk -nrpo PATH "$real"); do
  holders="/sys/class/block/$(basename "$node")/holders"
  if [ -d "$holders" ] && [ -n "$(ls -A "$holders" 2>/dev/null || true)" ]; then
    reasons="${reasons:+$reasons,}holders"; break
  fi
done
printf '%s|%s|%s|%s\n' "$real" "$size" "$model" "$reasons"
EOF
)
IFS='|' read -r DISK_REAL DISK_SIZE DISK_MODEL OCCUPANCY_REASONS <<< "$DISK_STATUS"

if [[ -n "$OCCUPANCY_REASONS" ]]; then
  printf "WARNING: remote disk is occupied (%s). Type YES to continue: " "$OCCUPANCY_REASONS" > /dev/tty
  OCCUPIED_CONFIRM=""; IFS= read -r OCCUPIED_CONFIRM < /dev/tty || true
  [[ "$OCCUPIED_CONFIRM" == "YES" ]] || { printf "Aborted.\n" >&2; exit 2; }
fi

printf "\nWARNING: ALL DATA WILL BE DESTROYED\n"
printf "  target = %s\n  disk   = %s\n  real   = %s\n  model  = %s\n  size   = %s bytes\n" \
  "$SSH_TARGET" "$DISK_DEVICE" "$DISK_REAL" "$DISK_MODEL" "$DISK_SIZE"
printf "Type YES to permanently destroy all data on this remote disk: " > /dev/tty
CONFIRM=""; IFS= read -r CONFIRM < /dev/tty || true
[[ "$CONFIRM" == "YES" ]] || { printf "Aborted.\n" >&2; exit 3; }

printf "Validating path-based NixOS flake before remote partitioning...\n"
nix --extra-experimental-features "nix-command flakes" \
  eval --raw "${FLAKE_REF}#nixosConfigurations.${HOST_NAME}.config.system.build.toplevel.drvPath" \
  --no-write-lock-file > /dev/null

if ! ssh -n "$SSH_TARGET" sh -s -- "$DISK_DEVICE" "$DISK_REAL" "$OCCUPANCY_REASONS" <<'EOF'
set -eu
disk=$1; expected=$2; expected_reasons=$3; real=$(readlink -f "$disk" 2>/dev/null || true)
[ "$real" = "$expected" ] && [ -b "$real" ] || exit 1
reasons=""
if lsblk -nrpo MOUNTPOINT "$real" | awk 'NF { found=1 } END { exit !found }'; then reasons=mountpoints; fi
for node in $(lsblk -nrpo PATH "$real"); do
  holders="/sys/class/block/$(basename "$node")/holders"
  if [ -d "$holders" ] && [ -n "$(ls -A "$holders" 2>/dev/null || true)" ]; then
    reasons="${reasons:+$reasons,}holders"; break
  fi
done
[ "$reasons" = "$expected_reasons" ]
EOF
then
  printf "Remote disk identity or occupancy changed after confirmation. Aborting.\n" >&2
  exit 2
fi

printf "Running nixos-anywhere on %s...\n" "$SSH_TARGET"
if ! nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/nixos-anywhere/036bd2423203b1432f36621404289832183cfecd -- \
  --flake "${FLAKE_REF}#${HOST_NAME}" "$SSH_TARGET"; then
  printf "nixos-anywhere failed; the remote disk may be partially modified.\n" >&2
  exit 1
fi

unset HPASSWD
printf "Remote bootstrap complete. Reboot the target, clone the repository and perform the documented full switch.\n"
