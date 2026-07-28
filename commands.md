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
# Показать кандидатов без записи файла (localhost)
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

# Тот диск на котором сейчас стоит система (перезапись)
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

### Сценарий 10 — Headless / CI (неинтерактивный, без подтверждений)

Если stdin не TTY — скрипт автоматически пропускает все промпты и берёт первый кандидат:

```bash
echo "" | nix run .#install-honor-magicbook -- nixos@<ip>
```

Или через pipe в CI:

```bash
nix run .#install-honor-magicbook -- nixos@<ip> < /dev/null
```

---

### Сценарий 11 — Low-level fallback (голый nixos-anywhere)

Если `install-honor-magicbook` недоступен и `local-device-paths.nix` уже заполнен вручную:

```bash
nix run github:nix-community/nixos-anywhere -- \
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
4. Интерактивное меню при нескольких кандидатах; 20 сек таймаут → первый кандидат
5. Пишет `local-device-paths.nix` с `diskDevice` (by-id) и `cameraDevicePath`

Поля в выводе фетча:

| Поле | Что значит |
|---|---|
| `selectionSource` | `explicit-override` / `env-disk-index` / `interactive-menu` / `single-candidate` / `auto-timeout-or-default` / `auto-noninteractive` |
| `AUTOSELECTED` / `USERSELECTED` | был ли выбор автоматическим |
| `diskOccupied` | диск занят (mountpoints / holders / current-root) |
| `occupancyFilterApplied` | были ли отфильтрованы занятые диски |
| `interactiveTTY` | запущен ли скрипт в интерактивном TTY |

---

### Важные ограничения

- `nixos-anywhere` требует SSH доступ — `sshd` должен быть запущен на целевой машине
- `localhost` режим не использует SSH — запускать прямо на целевом железе с live ISO
- `disko` и `disko-install` **полностью уничтожают данные** на выбранном диске
- не используй raw UUID для `diskDevice` — только whole-disk `by-id`
- ты сам отвечаешь за выбор диска; скрипты снижают риск, но не дают гарантий

---

## Сборка и проверка (WSL / другой NixOS)

Все команды запускать из корня репо. Дерево грязное — закоммить или выставить `--impure`.

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

`nix build` на dirty git tree берёт файлы из последнего коммита, а не с диска.
`local-device-paths.nix` трекается в git с заглушкой — поэтому сборка проходит.
Изменения в других файлах нужно закоммитить перед сборкой:

```bash
git add -u && git commit -m "wip: test build"
nix build .#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel
```

Или использовать `--impure` (читает файлы с диска, игнорирует dirty):

```bash
nix build .#nixosConfigurations.honor-magicbook-x16-pro.config.system.build.toplevel \
  --impure
```

---

## Rebuild

На установленной системе, если flake лежит в `~/.config/nixos`:

```bash
run0 nixos-rebuild switch --flake ~/.config/nixos#honor-magicbook-x16-pro
```

> Имя пользователя и домашний путь централизованно задаются в
> `hosts/honor-magicbook-x16-pro/user.nix`.

## Update flake inputs

```bash
run0 nix flake update --flake ~/.config/nixos
```

`run0` требует аутентификации для группы `wheel`: пароль или Howdy (face auth).

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
