# NixOS flake for Honor MagicBook X16 Pro

Модульная конфигурация `NixOS` для `Honor MagicBook X16 Pro BRN-H76` на `nixos-unstable`.

## Что внутри

- `flake`-конфиг с `home-manager`, `disko`, `nixos-hardware`, `nix-flatpak`, `FlClashX-nix`
- `Btrfs` layout через `disko` с отдельным `/.snapshots` subvolume для `Snapper`
- `GNOME` + Home Manager
- `PipeWire + WirePlumber + xdg-desktop-portal` для нормального Wayland screen sharing
- `GRUB` UEFI с поддержкой Btrfs + холодная Nord/NixOS-стилизация
- `run0` вместо `sudo`, с обязательной аутентификацией для `wheel`
- `Howdy` для face auth через веб-камеру
- глобально разрешены `unfree` пакеты и firmware blobs
- поддержка `nix develop` через `direnv` / `nix-direnv` и dev-friendly Nix settings
- отдельные модули под `kernel`, `laptop`, `virtualization`, `fish`, `packages`
- `zapret2` через systemd с переключаемыми пресетами YouTube, Discord и general

## Структура

- `flake.nix` — входная точка flake
- `hosts/honor-magicbook-x16-pro/` — host-specific конфиг
- `hosts/honor-magicbook-x16-pro/user.nix` — имя пользователя, shell, home directory и другие user-specific параметры
- `modules/nixos/` — системные модули
- `modules/home/` — Home Manager модули
- `dev/development.nix` — общие system/home dev-настройки (`nix develop`, `direnv`, `nix-direnv`)
- `dev/maintaining/` — шаблоны для пакетов, которым нужна отдельная деривация
- `commands.md` — готовые команды для установки, обновления и пост-настройки

## Установка

Установка выполняется **только локально** с прямым доступом к экрану и клавиатуре.
Запускать установку нужно с NixOS ISO на целевом ноутбуке, а не с Windows и не по SSH.

Установка выполняется через flake app:

```bash
nix --extra-experimental-features "nix-command flakes" run .#install-honor-magicbook -- localhost
```

В live/minimal среде `nix-command` и `flakes` нередко выключены по умолчанию,
поэтому либо используй эту полную форму, либо заранее выстави:

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

Эта команда автоматически:

1. **Определяет диск установки** — генерирует локальный файл устройств:
   ```text
   local-device-paths.nix
   ```
   Скрипт явно печатает `autoSelected`/`userSelected`, `interactiveTTY` и `selectionSource`,
   чтобы было видно, как именно был выбран диск.

2. **Запрашивает начальный пароль** — интерактивно создаёт хешированный пароль:
   ```text
   env.hpasswd
   ```
   Пароль используется **только для первого входа** после установки.
   Его **необходимо немедленно сменить** командой `run0 passwd wkubearnament`.

3. **Запускает установку** через `disko-install`.

Важно: эта установка **разрушительная**. Выбранный install-диск будет размечен
через `disko`, а существующие данные на нём будут уничтожены. Логика выбора диска
в этом репозитории снижает риск ошибки, но не снимает с тебя ответственность за
проверку целевого диска перед запуском установки.

Для install-диска используется **`/dev/disk/by-id`**, а не `UUID`, потому что
`disko` работает с **целым диском до создания файловых систем**.

Файлы `local-device-paths.nix` и `env.hpasswd` не попадают в Git (`.gitignore`).
После их генерации installer передаёт Disko ссылку `path:<repo>#<host>`, поэтому
Nix включает ignored-файлы в source. Обычный `.#...` продолжает использовать
Git-filtered source и не видит эти файлы. Host output появляется только когда
присутствуют оба generated-файла, поэтому неполная конфигурация не собирается.

Самая важная особенность дисков:

- `/.snapshots` монтируется как **отдельный Btrfs subvolume** `@snapshots`
- но остаётся видимым внутри `/` как каталог `.snapshots`
- это сделано специально для корректной работы `snapper`

## Ноутбучные нюансы

- fingerprint `27c6:5f10` намеренно **не используется**, потому что на Linux он сейчас не production-ready
- face auth вынесен в отдельный `Howdy`-модуль
- встроенная веб-камера предполагается как стандартная `UVC` (`uvcvideo`)
- для `Honor/Huawei` hotkeys используется `huawei_wmi` + `hwdb` mappings
- Honor/Huawei-специфичные WMI tweaks теперь не форсятся на нерелевантном железе и не должны мешать VM-тестам

Имя пользователя, shell и домашняя директория теперь вынесены в
`hosts/honor-magicbook-x16-pro/user.nix`, чтобы не править это по нескольким
местам сразу.

## Настройка начального пароля

Полный installer сам дважды запрашивает пароль без echo и создаёт yescrypt hash.
Отдельно эту стадию можно запустить из корня репозитория:

```bash
nix run .#gen-hpasswd
```

Hash записывается с правами `0600` в ignored-файл
`env.hpasswd` в корне репозитория.

## Первый вход после установки

После завершения установки и перезагрузки:

**Console/TTY или графический вход:**
- Логин: `wkubearnament`
- Пароль: тот, который ты ввёл на стадии генерации hash

**После первого входа:**
```bash
# Обязательно смени начальный пароль
passwd

# (Опционально) Настроить Howdy для face auth
run0 howdy add
```

**Важно:** `initialHashedPassword` применяется только при создании пользователя. После смены через `passwd` или `run0 passwd` generated hash больше не влияет на систему и не перезатирает новый пароль.

Hash не является plaintext, но при `path:` evaluation попадает в Nix store,
который обычно доступен локальным пользователям на чтение. Поэтому начальный
пароль должен быть временным и отличаться от постоянных паролей.

## Команды

Смотри: [commands.md](./commands.md)

## Zapret2

Сервис `zapret2` запускает `nfqws2` и правила `nftables` для обхода DPI.
Доступные пресеты можно менять без пересборки: `run0 zapret2ctl switch <preset>`.
Для подбора стратегии под текущего провайдера используется `run0 blockcheck2`.
