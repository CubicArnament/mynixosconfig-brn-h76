#!/usr/bin/env bash
# scripts/fetch-target-device-paths.sh
#
# bash — оркестратор детекта дисков.
#   localhost → fetch-local.sh (запускает fetch-remote.sh локально через sh)
#   remote   → fetch-remote.sh через SSH pipe, результат парсит fetch-local.sh
#
# Использование:
#   fetch-target-device-paths <ssh-target|localhost> [output-file] [disk-by-id] [camera-by-id]
#
# Переменные окружения:
#   INSTALL_DISK_FILTER  — фильтр диска (подстрока модели/класса, или "system"/"root")
#   INSTALL_DISK_INDEX   — номер кандидата (1-based) если несколько дисков
set -euo pipefail

HOST="${1:-}"
OUT="${2:-hosts/honor-magicbook-x16-pro/local-device-paths.nix}"
DISK_OVERRIDE="${3:-}"
CAMERA_OVERRIDE="${4:-}"

if [[ -z "$HOST" ]]; then
  printf "usage: %s <ssh-target|localhost> [output-file] [disk-by-id] [camera-by-id]\n" "$0" >&2
  printf "env overrides: INSTALL_DISK_FILTER=<substring-or-class> INSTALL_DISK_INDEX=<n>\n" >&2
  exit 1
fi

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# В store: bin/ и libexec/ — соседи. В dev-режиме (scripts/): всё в одной папке.
if [[ -d "$BIN_DIR/../libexec" ]]; then
  LIBEXEC_DIR="$(cd "$BIN_DIR/../libexec" && pwd)"
else
  LIBEXEC_DIR="$BIN_DIR"
fi

case "$HOST" in
  localhost|127.0.0.1|::1)
    # Локальный режим: fetch-local.sh сам вызывает fetch-remote.sh через sh
    exec bash "$LIBEXEC_DIR/fetch-local.sh" "$OUT" "$DISK_OVERRIDE" "$CAMERA_OVERRIDE"
    ;;
  *)
    # Удалённый режим: передать fetch-remote.sh на целевую машину через SSH pipe,
    # результат пробросить в fetch-local.sh через FETCH_RESULT
    # shellcheck disable=SC2029
    # Intentional: DISK_OVERRIDE/CAMERA_OVERRIDE expand on the client side.
    FETCH_RESULT=$(ssh "$HOST" "sh -s -- '$DISK_OVERRIDE' '$CAMERA_OVERRIDE'" \
                    < "$LIBEXEC_DIR/fetch-remote.sh")
    export FETCH_RESULT
    exec bash "$LIBEXEC_DIR/fetch-local.sh" "$OUT" "$DISK_OVERRIDE" "$CAMERA_OVERRIDE"
    ;;
esac
