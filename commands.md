# Commands

Все команды выполняются из корня репозитория.

```bash
cd ~/mynixosconfig-brn-h76
export NIX_CONFIG="experimental-features = nix-command flakes"
```

## Установка

Installer поддерживает локальную установку с ISO и удалённую установку на ISO
через SSH. Скрипт запускается от root и всегда требует локальный интерактивный
терминал для подтверждений.

```bash
git clone https://github.com/CubicArnament/mynixosconfig-brn-h76.git
cd mynixosconfig-brn-h76
export NIX_CONFIG="experimental-features = nix-command flakes"
sudo ./full-install.sh
```

Введи `localhost` для установки на текущем ноутбуке или `user@IPv4` для
удалённой цели. Wrapper отклоняет другие форматы и предварительно проверяет SSH.

Installer последовательно:

1. Находит диск и создаёт `local-device-paths.nix`.
2. Дважды запрашивает временный пароль и создаёт yescrypt `env.hpasswd`.
3. Показывает целевой диск и требует ввести его полный `by-id` basename.
4. Запускает `disko-install` через `path:<repo>#honor-magicbook-x16-pro`.

Installer также показывает `sys_vendor`, `product_name`, `product_version`,
`product_family`, `board_vendor` и `board_name`. Варианты HONOR/HUAWEI с
`BRN-H76` или `MagicBook X16 Pro` принимаются автоматически. Для другого DMI
нужно вручную ввести `YES`.

`disko-install` полностью уничтожает данные выбранного диска. Таймаутов у
выбора диска, ввода пароля и destructive confirmation нет.

Если появляется `No space left on device`, заполнен writable store live ISO, а
не целевой SSD. Форматирование SSD это место не освобождает:

```bash
df -h /nix/store /tmp .
nix store gc
```

После очистки повтори installer. Не запускай полный system build в том же live
сеансе перед установкой: он может заполнить RAM/overlay ISO.

Отдельная короткая команда очистки после неудачной попытки:

```bash
sudo ./store-gc.sh
```

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

Для намеренного стирания занятого/root диска выбери его фильтром. Installer
покажет причины занятости и отдельно потребует ввести `YES`:

```bash
INSTALL_DISK_FILTER=system sudo --preserve-env=INSTALL_DISK_FILTER \
  nix --extra-experimental-features "nix-command flakes" \
  run .#install-honor-magicbook -- localhost
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
  trustedinstaller/scripts/nixos-helper.d/*.sh \
  trustedinstaller/scripts/nixos-helper.d/commands/*.sh \
  trustedinstaller/scripts/nixos-helper.d/templates/*.sh
```

Собрать flake checks:

```bash
nix flake check --show-trace --print-build-logs --keep-going
```

## System Build

Требуются `local-device-paths.nix` и `env.hpasswd` в корне репозитория.
Команда ниже выполняет тестовую полную сборку system toplevel и печатает
подробные логи только в терминал. Файл лога и symlink `result` не создаются.

Для Bash/Zsh:

```bash
FLAKE="path:$PWD"
HOST="honor-magicbook-x16-pro"

nix build \
  "$FLAKE#nixosConfigurations.$HOST.config.system.build.toplevel" \
  --no-link \
  --show-trace \
  --print-build-logs \
  --log-format bar-with-logs
```

Для Fish:

```fish
set FLAKE "path:$PWD"
set HOST "honor-magicbook-x16-pro"

nix build \
  "$FLAKE#nixosConfigurations.$HOST.config.system.build.toplevel" \
  --no-link \
  --show-trace \
  --print-build-logs \
  --log-format bar-with-logs
```

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

## Nix Hlp

Имя `nh` занято upstream-проектом `nix-community/nh`, поэтому локальный helper
устанавливается как `nix-hlp`.

Привязать userspace-репозиторий к `/etc/nixos`:

```bash
cd ~/mynixosconfig-brn-h76
nix-hlp config-setup
```

Helper использует `path:/etc/nixos#honor-magicbook-x16-pro`, поэтому видит
ignored runtime-файлы.

```bash
# Build/apply
nix-hlp switch
nix-hlp boot
nix-hlp test
nix-hlp build

# Применить только Home Manager без root и без system rebuild
nix-hlp home

# Управление конфигурацией и поколениями
nix-hlp update
nix-hlp status
nix-hlp generations
nix-hlp rollback
nix-hlp diff
nix-hlp clean
nix-hlp clean 14

# Пароль и package maintenance
nix-hlp set-password
nix-hlp prefetch https://example.com/source.tar.gz
```

Root-команды автоматически используют доступный `run0`, `sudo` или `doas`.

### Форматирование

`nix fmt` форматирует текущую NixOS-конфигурацию formatter-ом из её `flake.nix`.
Согласно CLI Nix, обычные аргументы передаются formatter-у, поэтому точка
форматирует текущую директорию. `--` нужен для formatter flags:

```bash
# Всё дерево текущей конфигурации
nix fmt

# Текущая или конкретная директория
nix fmt .
nix fmt ./modules

# Formatter flag
nix fmt -- --fail-on-change
```

Для любого другого проекта используй formatter, установленный вместе с helper:

```bash
# Текущий проект
nix-hlp fmt

# Произвольный проект или поддиректория
nix-hlp fmt ~/projects/example
nix-hlp fmt ~/projects/example --fail-on-change
```

### Config Setup

`nix-hlp config-setup [directory]` принимает:

- flake-конфигурацию с `nixosConfigurations`/`nixosSystem` и `configuration.nix`;
- legacy-конфигурацию с корневым `configuration.nix` и узнаваемыми NixOS options.

Обычный project flake с Nix-файлами отклоняется и не может стать `/etc/nixos`.

### Project Templates

```bash
nix-hlp gen project_flake [directory] [--lang language]
nix-hlp gen nix_shell [directory] [--lang language]
nix-hlp gen app_run [directory] [--lang language]
nix-hlp gen app_build [directory] [--lang language]
nix-hlp gen btp [directory] [--lang language]
```

Detector учитывает manifests, lock-файлы, wrappers, package manager, framework
и entrypoint. Поддерживаются Rust/Cargo, Python с uv/Poetry/Pipenv/pip, Node с
bun/pnpm/Yarn/npm, Go, Java с Maven/Gradle и generic Make/CMake/Meson.

Если каталог пуст, generator создаёт минимальную рабочую структуру в стиле
package-manager init: manifest, `src`, entrypoint и тестовый каталог там, где он
принят экосистемой. Для неоднозначного пустого проекта укажи язык явно:

```bash
nix-hlp gen project_flake ./service --lang rust
nix-hlp gen btp ./backend --lang python
```

В существующем проекте исходники и manifests не перезаписываются: добавляется
только выбранная Nix integration. `app_run` и `app_build` являются
взаимоисключающими стартовыми templates, потому что оба создают `flake.nix`.
`btp` создаёт `flake.nix`, `nix/default.nix`, `nix/modules/project.nix` сразу с
apps `run` и `build`.

Templates никогда не перезаписывают существующий `flake.nix`, `shell.nix` или
каталог `nix/`.

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
