#!/usr/bin/env bash
# scripts/install-system.sh
#
# bash — оркестратор установки NixOS.
# localhost → install-local.sh (disko + nixos-install)
# remote   → install-remote.sh (nixos-anywhere по SSH)
#
# Использование:
#   install-honor-magicbook <ssh-target|localhost>
#
# Переменные окружения:
#   INSTALL_DISK_FILTER  — фильтр диска (подстрока модели/класса, или "system"/"root")
#   INSTALL_DISK_INDEX   — номер кандидата (1-based) если несколько дисков
set -euo pipefail

HOST="${1:-}"
if [[ -z "$HOST" ]]; then
  printf "usage: install-honor-magicbook <ssh-target|localhost>\n" >&2
  printf "  localhost  — local install via disko + nixos-install (run from NixOS live ISO)\n" >&2
  printf "  user@host  — remote install via nixos-anywhere over SSH\n" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -d "$BIN_DIR/../libexec" ]]; then
  LIBEXEC_DIR="$(cd "$BIN_DIR/../libexec" && pwd)"
else
  LIBEXEC_DIR="$BIN_DIR"
fi

HOST_NAME="honor-magicbook-x16-pro"
LOCAL_DEVICE_PATHS_REL="hosts/${HOST_NAME}/local-device-paths.nix"

# Шаг 1: детектировать диски и записать local-device-paths.nix
@fetchTargetDevicePaths@/bin/fetch-target-device-paths "$HOST" "$LOCAL_DEVICE_PATHS_REL"

# Шаг 2: установка
case "$HOST" in
  localhost|127.0.0.1|::1)
    exec bash "$LIBEXEC_DIR/install-local.sh" "$HOST_NAME" "$LOCAL_DEVICE_PATHS_REL"
    ;;
  *)
    exec bash "$LIBEXEC_DIR/install-remote.sh" "$HOST_NAME" "$HOST" "$LOCAL_DEVICE_PATHS_REL"
    ;;
esac
