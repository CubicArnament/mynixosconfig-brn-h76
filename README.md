# NixOS flake for Honor MagicBook X16 Pro

Модульная конфигурация `NixOS` для `Honor MagicBook X16 Pro BRN-H76` на `nixos-unstable`.

## Что внутри

- `flake`-конфиг с `home-manager`, `disko`, `nixos-hardware`, `nix-flatpak`
- `Btrfs` layout через `disko` с отдельным `/.snapshots` subvolume для `Snapper`
- `GNOME` + Home Manager
- `GRUB` UEFI + `btrfsSupport` + холодная Nord/NixOS-стилизация
- `run0` вместо `sudo`
- `Howdy` для face auth через веб-камеру
- отдельные модули под `kernel`, `laptop`, `virtualization`, `fish`, `packages`

## Структура

- `flake.nix` — входная точка flake
- `hosts/honor-magicbook-x16-pro/` — host-specific конфиг
- `modules/nixos/` — системные модули
- `modules/home/` — Home Manager модули
- `commands.md` — готовые команды для установки, обновления и пост-настройки

## Установка

Предполагаемый сценарий — через `nixos-anywhere` с Linux-машины или live-среды, а не с Windows.

Zero-touch сценарий установки теперь завязан на flake app:

```bash
nix run .#install-honor-magicbook -- wkubearnament@<target-host>
```

Эта команда сначала автоматически генерирует локальный файл устройств:

```text
hosts/honor-magicbook-x16-pro/local-device-paths.nix
```

а потом сама запускает `nixos-anywhere`.

В логах скрипт явно печатает `AUTOSELECTED` / `USERSELECTED` и `selectionSource`,
чтобы было видно, диск был выбран автоматически, через интерактивное меню или
через явный override.

Файл нужен, чтобы не хардкодить `diskDevice` и `cameraDevicePath` в tracked-конфиге.
Для install-диска здесь используется **`/dev/disk/by-id`**, а не `UUID`, потому что
`disko` работает с **целым диском до создания файловых систем**.

Самая важная особенность дисков:

- `/.snapshots` монтируется как **отдельный Btrfs subvolume** `@snapshots`
- но остаётся видимым внутри `/` как каталог `.snapshots`
- это сделано специально для корректной работы `snapper`

## Ноутбучные нюансы

- fingerprint `27c6:5f10` намеренно **не используется**, потому что на Linux он сейчас не production-ready
- face auth вынесен в отдельный `Howdy`-модуль
- встроенная веб-камера предполагается как стандартная `UVC` (`uvcvideo`)
- для `Honor/Huawei` hotkeys используется `huawei_wmi` + `hwdb` mappings

## Команды

Смотри: [commands.md](./commands.md)
