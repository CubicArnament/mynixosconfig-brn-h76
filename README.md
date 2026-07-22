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
