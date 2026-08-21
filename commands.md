# Commands

## Установка

Запускать **только с NixOS ISO на целевом ноутбуке**, не с Windows и не по SSH.

> Раз выставил в live-среде — больше не печатать каждый раз:
> ```bash
> export NIX_CONFIG="experimental-features = nix-command flakes"
> ```
> Все команды ниже написаны в короткой форме `nix run ...`
> (без `--extra-experimental-features`).

---

### Основной сценарий — Локальная установка с live ISO

Загрузился с minimal ISO на ноуте, подключился к wifi (`nmtui`), склонировал репо:

```bash
git clone https://github.com/CubicArnament/mynixosconfig-brn-h76 && cd mynixosconfig-brn-h76
nix run .#install-honor-magicbook -- localhost
```

Что происходит:
1. Автоматический детект и выбор диска → генерация `local-device-paths.nix`
2. Интерактивный запрос начального пароля → генерация `env.hpasswd`
3. Установка через `disko-install` (разметка + NixOS за один шаг)

**После перезагрузки немедленно смени пароль:**
```bash
run0 passwd wkubearnament
```

---

### Раздельные команды (ручной контроль)

Если хочешь проверить что запишется в файлы перед установкой:

```bash
# Шаг 1: только детект диска — ничего не устанавливает
nix run .#fetch-target-device-paths -- localhost

# Проверь результат
cat local-device-paths.nix

# Шаг 2: только генерация хешированного пароля
nix run .#gen-hpasswd

# Проверь что файл создан (содержимое — yescrypt hash)
ls -la env.hpasswd

# Шаг 3: запустить полный installer
# Для безопасности он повторно выполнит fetch и запрос пароля.
nix run .#install-honor-magicbook -- localhost
```

---

### Фетч с фильтром по классу или модели

```bash
# Только NVMe диски
INSTALL_DISK_FILTER=nvme nix run .#fetch-target-device-paths -- localhost

# По подстроке модели
INSTALL_DISK_FILTER=Samsung nix run .#fetch-target-device-paths -- localhost

# Второй NVMe если их несколько
INSTALL_DISK_FILTER=nvme INSTALL_DISK_INDEX=2 nix run .#fetch-target-device-paths -- localhost

# Тот диск, на котором сейчас стоит система (только детект)
INSTALL_DISK_FILTER=system nix run .#fetch-target-device-paths -- localhost
```

---

### Дополнительные опции — Явный выбор диска

Когда несколько дисков и не хочешь полагаться на автоматический выбор:

```bash
# Выбрать первый кандидат
INSTALL_DISK_INDEX=1 nix run .#fetch-target-device-paths -- localhost

# Или явно указать конкретный диск
nix run .#fetch-target-device-paths -- \
  localhost \
  local-device-paths.nix \
  /dev/disk/by-id/nvme-SAMSUNG_... \
  /dev/v4l/by-id/usb-...-video-index0
```

---

### Установка с подробными логами

```bash
nix run .#install-honor-magicbook -- localhost 2>&1 | tee install.log
```

---

### Что делает фетч (логика выбора диска)

1. Сортирует кандидаты: `NVMe > SATA SSD > прочий SSD > HDD`
2. Игнорирует: `usb`, `loop`, `zram`, `md`, `dm-*`, `sr*`, `ram`, `fd`
3. Предпочитает свободные диски (без mountpoints/holders/current-root)
4. Интерактивное меню при нескольких кандидатах; выбор обязателен и показывает занятость
5. Пишет `local-device-paths.nix` с `diskDevice` (by-id) и `cameraDevicePath`
6. Перед стиранием повторно проверяет тип, размер и занятость выбранного диска

Поля в выводе фетча:

| Поле | Что значит |
|---|---|
| `selectionSource` | `explicit-override` / `env-disk-index` / `interactive-menu` / `single-candidate` |
| `autoSelected` / `userSelected` | был ли выбор автоматическим |
| `diskOccupied` | диск занят (mountpoints / holders / current-root) |
| `occupancyFiltered` | были ли отфильтрованы занятые диски |
| `interactiveTTY` | запущен ли скрипт в интерактивном TTY |

---

### Важные ограничения

- установка требует локальный интерактивный TTY и запускается на целевом железе с live ISO
- `disko` и `disko-install` **полностью уничтожают данные** на выбранном диске
- не используй raw UUID для `diskDevice` — только whole-disk `by-id`
- ты сам отвечаешь за выбор диска; скрипты снижают риск, но не дают гарантий

---

## Первый вход после установки

После завершения установки и перезагрузки системы:

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

**Важно:** `initialHashedPassword` применяется только при создании пользователя. После того, как ты сменишь пароль через `passwd` или `run0 passwd`, начальный хеш больше не влияет на систему и не перезатирает новый пароль.

---

## Сборка и проверка (WSL / другой NixOS)

Все команды запускать из корня репозитория. Обычный Git-backed `.#...` намеренно
не видит ignored `local-device-paths.nix` и `env.hpasswd`. Поэтому system
evaluation/build после их генерации выполняется через `path:$PWD#...`.

### Полная сборка системы

Собирает всё дерево деривации, создаёт `./result`:

```bash
nix build "path:$PWD#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel"
```

С логами прогресса:

```bash
nix build "path:$PWD#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel" \
  --log-format bar-with-logs
```

### Быстрая проверка eval (без сборки пакетов)

Только вычисляет конфиг — в разы быстрее полной сборки, ловит ошибки типов и assertions:

```bash
nix eval "path:$PWD#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel"
```

### Проверка flake без сборки

Синтаксис, структура outputs, отсутствие `--impure` зависимостей:

```bash
nix flake check
```

### Проверка конкретного атрибута

```bash
# Посмотреть какой diskDevice попал в конфиг
nix eval "path:$PWD#nixosConfigurations.honor-magicbook-x16-pro.config.disko.devices.disk.main.device"

# Посмотреть итоговый список пакетов
nix eval "path:$PWD#nixosConfigurations.honor-magicbook-x16-pro.config.environment.systemPackages" \
  --apply 'map (p: p.name)' --json | jq .

# Проверить что machine.gpuVendor определился правильно
nix eval "path:$PWD#nixosConfigurations.honor-magicbook-x16-pro.config.machine.gpuVendor"

# Проверить machine.cpuVendor
nix eval "path:$PWD#nixosConfigurations.honor-magicbook-x16-pro.config.machine.cpuVendor"
```

### Полная трассировка при ошибке

```bash
nix build "path:$PWD#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel" \
  --show-trace
```

### Сборка установщиков

```bash
# Проверить что fetch-target-device-paths собирается
nix build .#fetch-target-device-paths

# Проверить что install-honor-magicbook собирается
nix build .#install-honor-magicbook

# Оба сразу
nix build .#fetch-target-device-paths .#install-honor-magicbook
```

### Generated файлы и source filtering

Не добавляй `local-device-paths.nix` и `env.hpasswd` в Git. Для system build
используй `path:` reference, который намеренно включает ignored-файлы:

```bash
nix build "path:$PWD#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel"
```

---

## Rebuild

На установленной системе, если репозиторий привязан к `/etc/nixos`:

```bash
nixos-helper
```

Другие режимы: `nixos-helper boot`, `nixos-helper test`,
`nixos-helper build`. Справка: `nixos-helper --help`.

### Полезные команды nixos-helper

```bash
# Обновить flake.lock
nixos-helper update

# Показать текущую и загруженную генерации
nixos-helper status

# Список последних генераций
nixos-helper generations

# Откатиться на предыдущую генерацию
nixos-helper rollback

# Удалить старые генерации (по умолчанию >7 дней)
nixos-helper clean
nixos-helper clean 14  # оставить только последние 14 дней

# Показать разницу между текущей системой и новой конфигурацией
nixos-helper diff

# Настроить userspace разработку: создаёт symlink /etc/nixos → текущая директория
# Позволяет редактировать конфиг без sudo, rebuild остаётся с повышением прав
cd ~/mynixosconfig
nixos-helper config-setup

# Сгенерировать SRI hash для fetchurl в dev/maintaining пакетах
nixos-helper prefetch https://example.com/file.tar.gz

# Установить пароль для wkubearnament
nixos-helper set-password
```

Команды, требующие root-прав, автоматически используют `run0` (systemd), `sudo` или `doas` в зависимости от доступности. Если ничего не найдено, nixos-helper попросит запустить его от имени root.

## Zapret2

`zapret2` работает как системная служба, перехватывает подходящий трафик через
`nftables`/NFQUEUE и применяет активную DPI-стратегию. В конфигурации доступны
пресеты `youtube`, `discord` и `general`; активен только один из них.
UDP ограничен портом `443` и диапазоном `50000-65535`, используемым Discord
Voice: полный перехват `1-65535` создавал бы лишнюю нагрузку на NFQUEUE.

```bash
# Статус службы и активный пресет
zapret2ctl status
systemctl status zapret2

# Список доступных пресетов; звёздочка отмечает активный
zapret2ctl list

# Сменить стратегию без nixos-rebuild. Команда перезапустит zapret2.
run0 zapret2ctl switch youtube
run0 zapret2ctl switch discord
run0 zapret2ctl switch general

# Логи службы текущей загрузки
journalctl -u zapret2 -b
```

### Подбор стратегии: blockcheck2

`blockcheck2` не является сервисом обхода. Это интерактивный диагностический
инструмент из пакета `zapret2`: он проверяет доступ к указанным ресурсам без
обхода, затем перебирает DPI-стратегии на реальном подключении и выводит
варианты, которые сработали у текущего провайдера. Его запускают при первой
настройке или когда прежний пресет перестал работать.

Перед тестом подготовь домены, которые действительно заблокированы или
замедлены в твоей сети. Для чистого результата отключи активный сервис:

```bash
run0 systemctl stop zapret2
run0 blockcheck2
```

После подбора снова включи сервис и проверь нужный пресет:

```bash
run0 systemctl start zapret2
run0 zapret2ctl switch youtube
```

`blockcheck2` выводит параметры стратегии `nfqws2`, а не готовое имя пресета.
Если встроенные `youtube`, `discord` и `general` не подходят, результат нужно
перенести в `services.zapret2.extraPresets` и добавить имя нового пресета в
`services.zapret2.presets`. Не оставляй `blockcheck2` запущенным постоянно.

## Face auth / Howdy

```bash
# Проверить видеоустройства
ls -l /dev/video* /dev/v4l/by-path

# Добавить лицо
run0 howdy add
```

Если Howdy смотрит не в ту камеру — поправь `device_path` в `modules/nixos/howdy/howdy.nix`.

## Snapper

```bash
snapper -c root list
```

## Virtualization

```bash
systemctl status libvirtd
```

## k3s

```bash
systemctl status k3s
kubectl get nodes
```

## Nix development

Включено: `nix-command`, `flakes`, `direnv`, `nix-direnv`, `trusted-users = ["root" "@wheel"]`.

```bash
cd <project>
direnv allow
nix develop
```

Fish abbreviations: `nd` → `nix develop`, `nf` → `nix flake check`, `nu` → `nix flake update`.

## Wayland screen sharing

```bash
systemctl --user status pipewire pipewire-pulse wireplumber
systemctl status xdg-desktop-portal
journalctl --user -u wireplumber -b
```

## Webcam / UVC

```bash
dmesg | grep -i uvc
```

Если Howdy не видит камеру но `/dev/video*` есть — проверь правильный node через `v4l2-ctl --list-devices`.
