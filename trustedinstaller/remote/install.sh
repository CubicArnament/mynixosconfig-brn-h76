#!/usr/bin/env sh
set -eu

HOST_NAME="${1:-}"
SSH_TARGET="${2:-}"
LOCAL_DEVICE_PATHS_REL="${3:-}"

if [ -z "$HOST_NAME" ] || [ -z "$SSH_TARGET" ] || [ -z "$LOCAL_DEVICE_PATHS_REL" ]; then
  printf "usage: %s <host-name> <ssh-target> <local-device-paths-file>\n" "$0" >&2
  exit 1
fi
case "$SSH_TARGET" in
  -*|*[!A-Za-z0-9._:@%+-]*)
    printf "Refusing unsafe SSH target: %s\n" "$SSH_TARGET" >&2
    exit 2
    ;;
esac

if VIRTUALIZATION=$(ssh -n "$SSH_TARGET" "systemd-detect-virt 2>/dev/null" 2>/dev/null); then
  printf "Refusing installation on virtualized target %s: %s\n" "$SSH_TARGET" "$VIRTUALIZATION" >&2
  printf "Disk discovery and nix builds are allowed in VMs/WSL; installation requires the physical Honor laptop.\n" >&2
  exit 2
fi

if ! ssh -n "$SSH_TARGET" "test -d /sys/firmware/efi"; then
  printf "Refusing installation: target %s is not booted in UEFI mode.\n" "$SSH_TARGET" >&2
  exit 2
fi

if ! ssh -n "$SSH_TARGET" "test \"\$(cat /sys/class/dmi/id/sys_vendor)\" = HONOR && test \"\$(cat /sys/class/dmi/id/product_name)\" = BRN-H76"; then
  printf "Refusing installation: target %s is not an HONOR BRN-H76.\n" "$SSH_TARGET" >&2
  exit 2
fi

if [ ! -t 0 ] && [ "${INSTALL_NONINTERACTIVE:-}" != "YES" ]; then
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

if ! printf '%s\n' "$DISK_DEVICE" | grep -Eq '^/dev/disk/by-id/[A-Za-z0-9._+:-]+$'; then
  printf "Refusing unsafe install disk path: %s\n" "$DISK_DEVICE" >&2
  exit 2
fi
case "${DISK_DEVICE##*/}" in
  *-part*)
    printf "Refusing partition path as install disk: %s\n" "$DISK_DEVICE" >&2
    exit 2
    ;;
esac

if ! DISK_STATUS=$(ssh "$SSH_TARGET" sh -s -- "$DISK_DEVICE" <<'EOF'
disk=$1
real=$(readlink -f "$disk" 2>/dev/null || true)
[ -L "$disk" ] && [ -n "$real" ] && [ -b "$real" ] && [ "$(lsblk -ndo TYPE "$real" 2>/dev/null)" = "disk" ] || exit 1
size=$(lsblk -dnbo SIZE "$real" 2>/dev/null | tr -d '[:space:]')
case "$size" in ''|*[!0-9]*) exit 1 ;; esac
[ "$size" -ge 34359738368 ] || exit 1
model=$(lsblk -dnro MODEL "$real" 2>/dev/null | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
reasons=""
if lsblk -nrpo MOUNTPOINT "$real" 2>/dev/null | grep -q '[^[:space:]]'; then reasons="mountpoints"; fi
for node in $(lsblk -nrpo PATH "$real" 2>/dev/null); do
  holders="/sys/class/block/$(basename "$node")/holders"
  if [ -d "$holders" ] && [ -n "$(ls -A "$holders" 2>/dev/null || true)" ]; then
    reasons="${reasons:+$reasons,}holders"; break
  fi
done
root=$(findmnt -n -o SOURCE / 2>/dev/null || true); root=${root%%\[*}
if [ -n "$root" ] && lsblk -snpo PATH,TYPE "$root" 2>/dev/null | awk -v disk="$real" '$2 == "disk" && $1 == disk { found=1 } END { exit !found }'; then
  reasons="${reasons:+$reasons,}current-root"
fi
printf '%s|%s|%s|%s\n' "$real" "$size" "$model" "$reasons"
EOF
); then
  printf "Refusing diskDevice that is not a whole block disk on %s: %s\n" "$SSH_TARGET" "$DISK_DEVICE" >&2
  exit 2
fi

IFS='|' read -r DISK_REAL DISK_SIZE DISK_MODEL OCCUPANCY_REASONS <<EOF
$DISK_STATUS
EOF
if [ -n "$OCCUPANCY_REASONS" ] && [ "${INSTALL_ALLOW_OCCUPIED_DISK:-}" != "YES" ]; then
  printf "Refusing occupied install disk (%s): %s\n" "$OCCUPANCY_REASONS" "$DISK_DEVICE" >&2
  printf "For an intentional reinstall, re-run with INSTALL_ALLOW_OCCUPIED_DISK=YES.\n" >&2
  exit 2
fi

printf "\n"
printf "WARNING: ALL DATA ON THE FOLLOWING DISK WILL BE PERMANENTLY DESTROYED:\n"
printf "  diskDevice = %s\n" "$DISK_DEVICE"
printf "  realPath   = %s\n" "$DISK_REAL"
printf "  model      = %s\n" "${DISK_MODEL:-unknown}"
printf "  size       = %s bytes\n" "$DISK_SIZE"
printf "  target     = %s\n" "$SSH_TARGET"
printf "  mode       = remote (nixos-anywhere)\n"
printf "\n"

CONFIRM_TOKEN=${DISK_DEVICE##*/}
if [ -c /dev/tty ] && [ -r /dev/tty ] && [ -w /dev/tty ] && (: < /dev/tty) 2>/dev/null; then
  printf "Type %s to confirm: " "$CONFIRM_TOKEN" > /dev/tty
  CONFIRM=""
  IFS= read -r CONFIRM < /dev/tty || true
  if [ "$CONFIRM" != "$CONFIRM_TOKEN" ]; then
    printf "Aborted.\n" >&2; exit 3
  fi
else
  printf "Non-interactive installation explicitly approved.\n"
fi

if ! DISK_STATUS_FINAL=$(ssh -n "$SSH_TARGET" sh -s -- "$DISK_DEVICE" "$DISK_REAL" <<'EOF'
disk=$1; expected_real=$2
real=$(readlink -f "$disk" 2>/dev/null || true)
[ "$real" = "$expected_real" ] || exit 1
if lsblk -nrpo MOUNTPOINT "$real" 2>/dev/null | grep -q '[^[:space:]]'; then exit 2; fi
for node in $(lsblk -nrpo PATH "$real" 2>/dev/null); do
  holders="/sys/class/block/$(basename "$node")/holders"
  if [ -d "$holders" ] && [ -n "$(ls -A "$holders" 2>/dev/null || true)" ]; then exit 3; fi
done
printf 'OK\n'
EOF
); then
  case "$?" in
    1) printf "CRITICAL: Disk symlink changed during confirmation. Aborting.\n" >&2 ;;
    2) printf "CRITICAL: Disk became mounted during confirmation. Aborting.\n" >&2 ;;
    3) printf "CRITICAL: Disk acquired holders during confirmation. Aborting.\n" >&2 ;;
    *) printf "CRITICAL: Pre-install revalidation failed. Aborting.\n" >&2 ;;
  esac
  exit 2
fi

printf "Running nixos-anywhere on %s...\n" "$SSH_TARGET"

if ! nix --extra-experimental-features "nix-command flakes" \
  run .#nixos-anywhere -- \
  --flake ".#${HOST_NAME}" \
  "$SSH_TARGET"; then
  printf "Installation failed; the target disk may be partially modified. Do not reboot the target until the failure is resolved.\n" >&2
  exit 1
fi

printf "\nInstallation complete.\n"
