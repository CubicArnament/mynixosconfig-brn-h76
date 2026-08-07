#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-}"
OUT="${2:-hosts/honor-magicbook-x16-pro/local-device-paths.nix}"
DISK_OVERRIDE="${3:-}"
CAMERA_OVERRIDE="${4:-}"

if [[ -z "$HOST" ]]; then
  printf "usage: fetch-target-device-paths <localhost|user@host> [output-file] [disk-by-id] [camera-by-id]\n" >&2
  printf "env: INSTALL_DISK_FILTER=<filter>  INSTALL_DISK_INDEX=<n>\n" >&2
  exit 1
fi

case "$HOST" in
  -*|*[!A-Za-z0-9._:@%+-]*)
    printf "Refusing unsafe host target: %s\n" "$HOST" >&2
    exit 2
    ;;
esac

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$BIN_DIR/../libexec" ]]; then
  LIBEXEC_DIR="$(cd "$BIN_DIR/../libexec" && pwd)"
else
  LIBEXEC_DIR="$BIN_DIR"
fi

case "$HOST" in
  localhost|127.0.0.1|::1)
    exec bash "$LIBEXEC_DIR/local/fetch.sh" "$OUT" "$DISK_OVERRIDE" "$CAMERA_OVERRIDE"
    ;;
  *)
    FETCH_RESULT=$(ssh "$HOST" "sh -s" < "$LIBEXEC_DIR/remote/fetch.sh")
    export FETCH_RESULT
    exec bash "$LIBEXEC_DIR/local/fetch.sh" "$OUT" "$DISK_OVERRIDE" "$CAMERA_OVERRIDE"
    ;;
esac
