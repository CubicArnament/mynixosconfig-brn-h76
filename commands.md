# Commands

Все команды выполняются из корня репозитория.

```bash
cd ~/mynixosconfig-brn-h76
export NIX_CONFIG="experimental-features = nix-command flakes"
```

## Установка

Установка поддерживается только локально с NixOS ISO на целевом Honor
MagicBook. Нужен прямой доступ к экрану и клавиатуре. SSH/headless установка
отключена.

```bash
git clone https://github.com/CubicArnament/mynixosconfig-brn-h76.git
cd mynixosconfig-brn-h76
export NIX_CONFIG="experimental-features = nix-command flakes"
nix run .#install-honor-magicbook -- localhost
```

Installer последовательно:

1. Находит диск и создаёт `local-device-paths.nix`.
2. Дважды запрашивает временный пароль и создаёт yescrypt `env.hpasswd`.
3. Показывает целевой диск и требует ввести его полный `by-id` basename.
4. Запускает `disko-install` через `path:<repo>#honor-magicbook-x16-pro`.

`disko-install` полностью уничтожает данные выбранного диска. Таймаутов у
выбора диска, ввода пароля и destructive confirmation нет.

## Runtime-Файлы

Эти файлы создаются в корне репозитория и исключены через `.gitignore`:

```text
local-device-paths.nix
env.hpasswd
```

Обычный Git-backed flake `.#...` их не видит. Поэтому:

- приложения запускаются через `.#...`;
- host evaluation и system build запускаются через `path:$PWD#...`;
- host output существует только когда присутствуют оба валидных runtime-файла.

Проверка готовности:

```bash
test -s local-device-paths.nix && echo "disk config: OK"
test -s env.hpasswd && echo "password hash: OK"
```

Если Nix сообщает, что `nixosConfigurations.honor-magicbook-x16-pro` не
существует, сначала создай оба файла на целевом ноутбуке:

```bash
nix run .#fetch-target-device-paths -- localhost
nix run .#gen-hpasswd
```

## Ручная Подготовка

Только определить устройства, без установки:

```bash
nix run .#fetch-target-device-paths -- localhost
cat local-device-paths.nix
```

Только создать начальный password hash:

```bash
nix run .#gen-hpasswd
ls -l env.hpasswd
```

Фильтрация дисков:

```bash
# NVMe
INSTALL_DISK_FILTER=nvme nix run .#fetch-target-device-paths -- localhost

# Подстрока модели
INSTALL_DISK_FILTER=Samsung nix run .#fetch-target-device-paths -- localhost

# Второй кандидат после фильтрации
INSTALL_DISK_FILTER=nvme INSTALL_DISK_INDEX=2 \
  nix run .#fetch-target-device-paths -- localhost

# Текущий системный/root диск, только для намеренной переустановки
INSTALL_DISK_FILTER=system nix run .#fetch-target-device-paths -- localhost
```

Явный whole-disk `by-id` и камера:

```bash
nix run .#fetch-target-device-paths -- \
  localhost \
  local-device-paths.nix \
  /dev/disk/by-id/nvme-SAMSUNG_... \
  /dev/v4l/by-id/usb-...-video-index0
```

Для намеренного стирания занятого/root диска полный installer требует:

```bash
INSTALL_DISK_FILTER=system INSTALL_ALLOW_OCCUPIED_DISK=YES \
  nix run .#install-honor-magicbook -- localhost
```

## Evaluation

Требуются оба runtime-файла.

Для Bash/Zsh:

```bash
FLAKE="path:$PWD"
HOST="honor-magicbook-x16-pro"

# Проверить, что host output существует
nix eval "$FLAKE#nixosConfigurations.$HOST.config.networking.hostName"

# Derivation path system closure
nix eval --raw \
  "$FLAKE#nixosConfigurations.$HOST.config.system.build.toplevel.drvPath"

# Выбранный Disko device
nix eval --raw \
  "$FLAKE#nixosConfigurations.$HOST.config.disko.devices.disk.main.device"

# Machine metadata
nix eval --raw \
  "$FLAKE#nixosConfigurations.$HOST.config.machine.cpuVendor"
nix eval --raw \
  "$FLAKE#nixosConfigurations.$HOST.config.machine.gpuVendor"
```

Для Fish переменные задаются через `set`, а не через `NAME=value`:

```fish
set FLAKE "path:$PWD"
set HOST "honor-magicbook-x16-pro"

nix eval "$FLAKE#nixosConfigurations.$HOST.config.networking.hostName"
nix eval --raw \
  "$FLAKE#nixosConfigurations.$HOST.config.system.build.toplevel.drvPath"
nix eval --raw \
  "$FLAKE#nixosConfigurations.$HOST.config.disko.devices.disk.main.device"
```

## Проверки Репозитория

Эти проверки не требуют host output или runtime-файлов:

```bash
git status --short
git diff --check

nix flake check --no-build --show-trace
nix run nixpkgs#statix -- check .
nix run nixpkgs#deadnix -- --fail .
nix run nixpkgs#shellcheck -- \
  trustedinstaller/*.sh \
  trustedinstaller/local/*.sh \
  trustedinstaller/remote/fetch.sh \
  trustedinstaller/scripts/nixos-helper.d/*.sh
```

Собрать flake checks:

```bash
nix flake check --show-trace --print-build-logs --keep-going
```

## System Build

Требуются `local-device-paths.nix` и `env.hpasswd` в корне репозитория.

Для Bash/Zsh:

```bash
FLAKE="path:$PWD"
HOST="honor-magicbook-x16-pro"
LOG="/tmp/nixos-toplevel-$(date +%Y%m%d-%H%M%S).log"

set -o pipefail
nix build \
  "$FLAKE#nixosConfigurations.$HOST.config.system.build.toplevel" \
  --no-link \
  --show-trace \
  --print-build-logs 2>&1 | tee "$LOG"
```

Для Fish:

```fish
set FLAKE "path:$PWD"
set HOST "honor-magicbook-x16-pro"
set LOG "/tmp/nixos-toplevel-"(date +%Y%m%d-%H%M%S)".log"

nix build \
  "$FLAKE#nixosConfigurations.$HOST.config.system.build.toplevel" \
  --no-link \
  --show-trace \
  --print-build-logs 2>&1 | tee "$LOG"
```

В Fish нет `set -o pipefail`: статусы всех элементов pipeline находятся в
`$pipestatus`, а `$status` содержит status последней команды.

Не используй `--rebuild` для первого или невалидного output. Этот флаг повторно
собирает уже валидный output и сравнивает результаты.

## Первый Вход

После установки войди локально:

```text
login: wkubearnament
password: пароль, введённый на стадии gen-hpasswd
```

Сразу замени временный пароль:

```bash
passwd
```

`initialHashedPassword` действует только при создании пользователя. После
`passwd` или `run0 passwd wkubearnament` rebuild не возвращает начальный пароль.

Hash не является plaintext, но при `path:` evaluation попадает в Nix store.
Поэтому начальный пароль должен быть временным и не использоваться где-либо ещё.

## Nixos Helper

Привязать userspace-репозиторий к `/etc/nixos`:

```bash
cd ~/mynixosconfig-brn-h76
nixos-helper config-setup
```

Helper использует `path:/etc/nixos#honor-magicbook-x16-pro`, поэтому видит
ignored runtime-файлы.

```bash
# Build/apply
nixos-helper switch
nixos-helper boot
nixos-helper test
nixos-helper build

# Управление конфигурацией и поколениями
nixos-helper update
nixos-helper status
nixos-helper generations
nixos-helper rollback
nixos-helper diff
nixos-helper clean
nixos-helper clean 14

# Пароль и package maintenance
nixos-helper set-password
nixos-helper prefetch https://example.com/source.tar.gz
```

Root-команды автоматически используют доступный `run0`, `sudo` или `doas`.

## Zapret2

```bash
zapret2ctl status
zapret2ctl list
systemctl status zapret2
journalctl -u zapret2 -b

run0 zapret2ctl switch youtube
run0 zapret2ctl switch discord
run0 zapret2ctl switch general
```

Подбор стратегии:

```bash
run0 systemctl stop zapret2
run0 blockcheck2
run0 systemctl start zapret2
```

## Howdy

```bash
ls -l /dev/video* /dev/v4l/by-path
run0 howdy add
```

## Snapper

```bash
snapper -c root list
```

## Virtualization И K3s

```bash
systemctl status libvirtd
systemctl status k3s
kubectl get nodes
```

## Wayland И Webcam

```bash
systemctl --user status pipewire pipewire-pulse wireplumber
systemctl --user status xdg-desktop-portal
journalctl --user -u wireplumber -b
v4l2-ctl --list-devices
dmesg | grep -i uvc
```
