#!/usr/bin/env bash
# trustedinstaller/install-system.sh
#
# bash — единая точка входа: фетч устройств + установка.
#
# Использование с live ISO:
#   1. Загрузиться с NixOS minimal ISO
#   2. Подключиться к wifi: nmtui  (или nmcli device wifi connect <SSID> password <pass>)
#   3. git clone https://github.com/<you>/mynixosconfig && cd mynixosconfig
#   4. nix run .#install-honor-magicbook -- localhost
#
# Использование для удалённой установки:
#   nix run .#install-honor-magicbook -- nixos@192.168.1.x
#
# Переменные окружения:
#   INSTALL_DISK_FILTER  — фильтр диска (подстрока модели/класса, или "system"/"root")
#   INSTALL_DISK_INDEX   — номер кандидата (1-based) если несколько дисков
set -euo pipefail

HOST="${1:-}"
if [[ -z "$HOST" ]]; then
  printf "usage: install-honor-magicbook <localhost|user@host>\n\n" >&2
  printf "  localhost   — live ISO, local disko-install\n" >&2
  printf "  user@host   — remote nixos-anywhere over SSH\n\n" >&2
  printf "env: INSTALL_DISK_FILTER=<filter>  INSTALL_DISK_INDEX=<n>\n" >&2
  exit 1
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$REPO_ROOT"

BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# В store: bin/ и libexec/ соседи. В репо: trustedinstaller/ — всё рядом.
if [[ -d "$BIN_DIR/../libexec" ]]; then
  LIBEXEC_DIR="$(cd "$BIN_DIR/../libexec" && pwd)"
else
  LIBEXEC_DIR="$BIN_DIR"
fi

HOST_NAME="honor-magicbook-x16-pro"
LOCAL_DEVICE_PATHS_REL="hosts/${HOST_NAME}/local-device-paths.nix"

case "$HOST" in
  localhost|127.0.0.1|::1)
    printf "==> [local] Detecting disks...\n"
    bash "$LIBEXEC_DIR/local/fetch.sh" "$LOCAL_DEVICE_PATHS_REL"

    printf "\n==> [local] Installing...\n"
    exec bash "$LIBEXEC_DIR/local/install.sh" "$HOST_NAME" "$LOCAL_DEVICE_PATHS_REL"
    ;;
  *)
    printf "==> [remote] Detecting disks on %s...\n" "$HOST"
    # Передаём remote/fetch.sh на целевую машину через SSH pipe,
    # результат парсим локально через local/fetch.sh с FETCH_RESULT
    FETCH_RESULT=$(ssh "$HOST" "sh -s -- '' ''" < "$LIBEXEC_DIR/remote/fetch.sh")
    export FETCH_RESULT
    bash "$LIBEXEC_DIR/local/fetch.sh" "$LOCAL_DEVICE_PATHS_REL"

    printf "\n==> [remote] Installing on %s...\n" "$HOST"
    exec sh "$LIBEXEC_DIR/remote/install.sh" "$HOST_NAME" "$HOST" "$LOCAL_DEVICE_PATHS_REL"
    ;;
esac
