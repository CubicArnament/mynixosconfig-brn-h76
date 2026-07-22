# NixOS flake for Honor MagicBook X16 Pro

Модульная конфигурация `NixOS` для `Honor MagicBook X16 Pro BRN-H76` на `nixos-unstable`.

## Что внутри

- `flake`-конфиг с `home-manager`, `disko`, `nixos-hardware`, `nix-flatpak`
- `Btrfs` layout через `disko` с отдельным `/.snapshots` subvolume для `Snapper`
- `GNOME` + Home Manager
- `PipeWire + WirePlumber + xdg-desktop-portal` для нормального Wayland screen sharing
- `GRUB` UEFI + `btrfsSupport` + холодная Nord/NixOS-стилизация
- `run0` вместо `sudo`, с обязательной аутентификацией для `wheel`
- `Howdy` для face auth через веб-камеру
- отдельные модули под `kernel`, `laptop`, `virtualization`, `fish`, `packages`

## Структура

- `flake.nix` — входная точка flake
- `hosts/honor-magicbook-x16-pro/` — host-specific конфиг
- `hosts/honor-magicbook-x16-pro/user.nix` — имя пользователя, shell, home directory и другие user-specific параметры
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

В логах скрипт явно печатает `AUTOSELECTED` / `USERSELECTED`, `interactiveTTY`
и `selectionSource`, чтобы было видно, диск был выбран автоматически,
через интерактивное меню, через env-based выбор или через явный override.

Для headless и серверных сценариев скрипт не должен зависать в ожидании ввода:
если TTY нет или таймаут вышел, он автоматически выбирает лучший кандидат по
приоритету `NVMe > SATA SSD > прочий SSD > HDD`. Для сложных многодисковых
конфигураций можно дополнительно задать `INSTALL_DISK_FILTER` и
`INSTALL_DISK_INDEX`.

Скрипт также пытается не трогать уже занятые диски, если находит более безопасные
свободные кандидаты: он учитывает `mountpoints`, `holders` и признак текущего
`root`-диска. Специальные фильтры `INSTALL_DISK_FILTER=system` и
`INSTALL_DISK_FILTER=root` позволяют, наоборот, прицельно выбрать текущий
системный диск для переустановки.

Важно: эта установка **разрушительная**. Выбранный install-диск будет размечен
через `disko`, а существующие данные на нём будут уничтожены. Логика выбора диска
в этом репозитории снижает риск ошибки, но не снимает с тебя ответственность за
проверку целевого диска перед запуском установки.

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

Имя пользователя, shell и домашняя директория теперь вынесены в
`hosts/honor-magicbook-x16-pro/user.nix`, чтобы не править это по нескольким
местам сразу.

## Команды

Смотри: [commands.md](./commands.md)
