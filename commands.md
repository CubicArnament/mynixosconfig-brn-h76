# Commands

## Установка

Запускать **с Linux-машины / live ISO**, не с Windows.

> Раз выставил в live-среде — больше не печатать каждый раз:
> ```bash
> export NIX_CONFIG="experimental-features = nix-command flakes"
> ```
> Все команды ниже написаны в короткой форме `nix run ...`
> (без `--extra-experimental-features`).
> Замени `nixos@<ip>` на реального пользователя и адрес целевой машины.

---

### Сценарий 1 — Локальная установка с live ISO (один шаг)

Загрузился с minimal ISO на ноуте, подключился к wifi (`nmtui`), склонировал репо:

```bash
git clone https://github.com/<you>/mynixosconfig && cd mynixosconfig
nix run .#install-honor-magicbook -- localhost
```

Что происходит: детект дисков локально → выбор диска → `disko-install` (разметка + NixOS за один шаг).

---

### Сценарий 2 — Удалённая установка через SSH (один шаг)

```bash
nix run .#install-honor-magicbook -- nixos@<ip>
```

Что происходит: детект дисков на целевой машине через SSH → выбор диска → `nixos-anywhere`.

---

### Сценарий 3 — Раздельно: сначала фетч, потом установка (localhost)

Если хочешь проверить что запишется в `local-device-paths.nix` перед тем как жать на курок:

```bash
# Шаг 1: только детект — ничего не устанавливает
nix run .#fetch-target-device-paths -- localhost

# Проверь результат
cat hosts/honor-magicbook-x16-pro/local-device-paths.nix

# Шаг 2: установка с уже готовым local-device-paths.nix
nix run .#install-honor-magicbook -- localhost
```

---

### Сценарий 4 — Раздельно: сначала фетч, потом установка (remote)

```bash
# Шаг 1: только детект на удалённой машине
nix run .#fetch-target-device-paths -- nixos@<ip>

# Проверь результат
cat hosts/honor-magicbook-x16-pro/local-device-paths.nix

# Шаг 2: установка
nix run .#install-honor-magicbook -- nixos@<ip>
```

---

### Сценарий 5 — Фетч с явным выбором диска (по индексу)

Когда несколько дисков и не хочешь полагаться на интерактивное меню:

```bash
# Выбрать первый кандидат и записать файл (localhost)
INSTALL_DISK_INDEX=1 nix run .#fetch-target-device-paths -- localhost

# Выбрать второй кандидат
INSTALL_DISK_INDEX=2 nix run .#fetch-target-device-paths -- nixos@<ip>
```

---

### Сценарий 6 — Фетч с фильтром по классу или модели

```bash
# Только NVMe диски
INSTALL_DISK_FILTER=nvme nix run .#fetch-target-device-paths -- nixos@<ip>

# По подстроке модели
INSTALL_DISK_FILTER=Samsung nix run .#fetch-target-device-paths -- nixos@<ip>

# Второй NVMe если их несколько
INSTALL_DISK_FILTER=nvme INSTALL_DISK_INDEX=2 nix run .#fetch-target-device-paths -- nixos@<ip>

# Тот диск, на котором сейчас стоит система (только детект)
INSTALL_DISK_FILTER=system nix run .#fetch-target-device-paths -- nixos@<ip>
```

---

### Сценарий 7 — Фетч с явным override диска и камеры

```bash
nix run .#fetch-target-device-paths -- \
  nixos@<ip> \
  hosts/honor-magicbook-x16-pro/local-device-paths.nix \
  /dev/disk/by-id/nvme-SAMSUNG_... \
  /dev/v4l/by-id/usb-...-video-index0
```

---

### Сценарий 8 — Установка с подробными логами

```bash
nix run .#install-honor-magicbook -- localhost 2>&1 | tee install.log
```

```bash
nix run .#install-honor-magicbook -- nixos@<ip> 2>&1 | tee install.log
```

---

### Сценарий 9 — Установка без логов (тихий режим)

```bash
nix run .#install-honor-magicbook -- localhost > /dev/null
```

---

### Сценарий 10 — Headless / CI (явный выбор и подтверждение)

При нескольких дисках обязательно выбери индекс. Destructive-установка без TTY
требует отдельного явного opt-in:

```bash
INSTALL_DISK_INDEX=1 INSTALL_NONINTERACTIVE=YES \
  nix run .#install-honor-magicbook -- nixos@<ip> < /dev/null
```

Если выбран занятый или текущий системный диск, для намеренной переустановки
дополнительно требуется `INSTALL_ALLOW_OCCUPIED_DISK=YES`. Перед разметкой
установщик ещё раз проверит mountpoints, holders и backing disk корня.

---

### Сценарий 11 — Low-level fallback (голый nixos-anywhere)

Если `install-honor-magicbook` недоступен и `local-device-paths.nix` уже заполнен вручную:

```bash
nix run .#nixos-anywhere -- \
  --flake .#honor-magicbook-x16-pro \
  nixos@<ip>
```

---

### Сценарий 12 — Проверка дисков вручную перед установкой

```bash
# На целевой машине
lsblk -dnpo NAME,TYPE,SIZE,MODEL,TRAN
ls -la /dev/disk/by-id/ | grep -v part

# На удалённой через SSH
ssh nixos@<ip> "lsblk -dnpo NAME,TYPE,SIZE,MODEL,TRAN"
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

- `nixos-anywhere` требует SSH доступ — `sshd` должен быть запущен на целевой машине
- `localhost` режим не использует SSH — запускать прямо на целевом железе с live ISO
- `disko` и `disko-install` **полностью уничтожают данные** на выбранном диске
- не используй raw UUID для `diskDevice` — только whole-disk `by-id`
- ты сам отвечаешь за выбор диска; скрипты снижают риск, но не дают гарантий

---

## Первый вход после установки

После завершения установки и перезагрузки системы:

**SSH вход (основной метод):**
```bash
ssh wkubearnament@<ip-адрес>
```

SSH-ключ уже настроен в `hosts/honor-magicbook-x16-pro/env.ssh` и установлен в систему.

**Console/TTY вход (fallback):**
- Логин: `wkubearnament`
- Пароль: `changeme123`

**Первое что нужно сделать после входа:**
```bash
# Обязательно сменить временный пароль
passwd

# (Опционально) Настроить Howdy для face auth
run0 howdy add
```

Временный пароль `changeme123` установлен только для возможности консольного входа в случае проблем с SSH. После первого входа обязательно смени его через `passwd`.

---

## Сборка и проверка (WSL / другой NixOS)

Все команды запускать из корня репо. Изменения отслеживаемых файлов Git входят в source flake; новые файлы сначала добавь через `git add`.

### Полная сборка системы

Собирает всё дерево деривации, создаёт `./result`:

```bash
nix build .#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel
```

С логами прогресса:

```bash
nix build .#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel \
  --log-format bar-with-logs
```

### Быстрая проверка eval (без сборки пакетов)

Только вычисляет конфиг — в разы быстрее полной сборки, ловит ошибки типов и assertions:

```bash
nix eval .#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel
```

### Проверка flake без сборки

Синтаксис, структура outputs, отсутствие `--impure` зависимостей:

```bash
nix flake check
```

### Проверка конкретного атрибута

```bash
# Посмотреть какой diskDevice попал в конфиг
nix eval .#nixosConfigurations.honor-magicbook-x16-pro.config.disko.devices.disk.main.device

# Посмотреть итоговый список пакетов
nix eval .#nixosConfigurations.honor-magicbook-x16-pro.config.environment.systemPackages \
  --apply 'map (p: p.name)' --json | jq .

# Проверить что machine.gpuVendor определился правильно
nix eval .#nixosConfigurations.honor-magicbook-x16-pro.config.machine.gpuVendor

# Проверить machine.cpuVendor
nix eval .#nixosConfigurations.honor-magicbook-x16-pro.config.machine.cpuVendor
```

### Полная трассировка при ошибке

```bash
nix build .#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel \
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

### Если дерево грязное (dirty tree)

Git flake учитывает изменения уже отслеживаемых файлов рабочего дерева. Новые
неотслеживаемые файлы не входят в source flake, пока их не добавить в индекс:

```bash
git add path/to/new-file
nix build .#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel
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
