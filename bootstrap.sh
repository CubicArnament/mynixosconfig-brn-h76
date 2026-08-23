#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
  printf "Run this script as root, for example: sudo ./bootstrap.sh\n" >&2
  exit 2
fi

if [[ ! -c /dev/tty || ! -r /dev/tty || ! -w /dev/tty ]]; then
  printf "An interactive terminal is required.\n" >&2
  exit 2
fi

export NIX_CONFIG="
experimental-features = nix-command flakes
fallback = false
filetransfer-retry-attempts = 10
connect-timeout = 20
stalled-download-timeout = 120
"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

printf "Install target (localhost or user@IPv4): " > /dev/tty
TARGET=""
IFS= read -r TARGET < /dev/tty || true

validate_ipv4() {
  local ip="$1" octet
  IFS='.' read -r -a OCTETS <<< "$ip"
  [[ ${#OCTETS[@]} -eq 4 ]] || return 1
  for octet in "${OCTETS[@]}"; do
    [[ "$octet" =~ ^[0-9]{1,3}$ ]] || return 1
    (( 10#$octet <= 255 )) || return 1
  done
}

case "$TARGET" in
  localhost)
    ;;
  *@*)
    USER_PART=${TARGET%@*}
    IP_PART=${TARGET#*@}
    if ! [[ "$USER_PART" =~ ^[A-Za-z_][A-Za-z0-9._-]*$ ]] || ! validate_ipv4 "$IP_PART"; then
      printf "Invalid target. Expected localhost or user@IPv4.\n" >&2
      exit 2
    fi
    printf "Checking SSH access to %s...\n" "$TARGET"
    if ! ssh -o ConnectTimeout=10 "$TARGET" true; then
      printf "Cannot access %s over SSH. Installation aborted.\n" "$TARGET" >&2
      exit 2
    fi
    ;;
  *)
    printf "Invalid target. Expected localhost or user@IPv4.\n" >&2
    exit 2
    ;;
esac

exec nix --option fallback false \
  --option filetransfer-retry-attempts 10 \
  --option connect-timeout 20 \
  --option stalled-download-timeout 120 \
  run --no-write-lock-file .#install-honor-magicbook -- "$TARGET"
