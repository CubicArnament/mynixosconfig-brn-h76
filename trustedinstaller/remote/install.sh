#!/usr/bin/env sh
set -eu

HOST_NAME="${1:-}"
SSH_TARGET="${2:-}"
LOCAL_DEVICE_PATHS_REL="${3:-}"

if [ -z "$HOST_NAME" ] || [ -z "$SSH_TARGET" ] || [ -z "$LOCAL_DEVICE_PATHS_REL" ]; then
  printf "usage: %s <host-name> <ssh-target> <local-device-paths-file>\n" "$0" >&2
  exit 1
fi

if VIRTUALIZATION=$(ssh "$SSH_TARGET" "systemd-detect-virt 2>/dev/null" 2>/dev/null); then
  printf "Refusing installation on virtualized target %s: %s\n" "$SSH_TARGET" "$VIRTUALIZATION" >&2
  printf "Disk discovery and nix builds are allowed in VMs/WSL; installation requires the physical Honor laptop.\n" >&2
  exit 2
fi

if ! ssh "$SSH_TARGET" "test -d /sys/firmware/efi"; then
  printf "Refusing installation: target %s is not booted in UEFI mode.\n" "$SSH_TARGET" >&2
  exit 2
fi

if ! ssh "$SSH_TARGET" "test \"\$(cat /sys/class/dmi/id/sys_vendor)\" = HONOR && test \"\$(cat /sys/class/dmi/id/product_name)\" = BRN-H76"; then
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

if ! ssh "$SSH_TARGET" sh -s -- "$DISK_DEVICE" <<'EOF'
disk=$1
real=$(readlink -f "$disk" 2>/dev/null || true)
[ -L "$disk" ] && [ -n "$real" ] && [ -b "$real" ] && [ "$(lsblk -ndo TYPE "$real" 2>/dev/null)" = "disk" ]
EOF
then
  printf "Refusing diskDevice that is not a whole block disk on %s: %s\n" "$SSH_TARGET" "$DISK_DEVICE" >&2
  exit 2
fi

printf "\n"
printf "WARNING: ALL DATA ON THE FOLLOWING DISK WILL BE PERMANENTLY DESTROYED:\n"
printf "  diskDevice = %s\n" "$DISK_DEVICE"
printf "  target     = %s\n" "$SSH_TARGET"
printf "  mode       = remote (nixos-anywhere)\n"
printf "\n"

if [ -t 0 ]; then
  printf "Type YES to confirm, anything else aborts: "
  CONFIRM=""
  IFS= read -r CONFIRM || true
  CONFIRM_UC=$(printf "%s" "$CONFIRM" | tr '[:lower:]' '[:upper:]')
  if [ "$CONFIRM_UC" != "YES" ]; then
    printf "Aborted.\n" >&2; exit 3
  fi
else
  printf "Non-interactive installation explicitly approved.\n"
fi

printf "Running nixos-anywhere on %s...\n" "$SSH_TARGET"

nix --extra-experimental-features "nix-command flakes" \
  run .#nixos-anywhere -- \
  --flake ".#${HOST_NAME}" \
  "$SSH_TARGET"

printf "\nInstallation complete.\n"
