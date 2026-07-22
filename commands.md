# Commands

## NixOS Anywhere

Запускать **с Linux-машины / live ISO**, не с Windows.

Важно:

- для `nixos-anywhere` нужен доступ по `SSH`
- поэтому не рассчитывай на обычный `NixOS` live ISO, если в нём у тебя не поднят `sshd`
- на практике проще использовать **minimal ISO**, где сценарий с `sshd` подходит лучше
- для `disko` не используй raw-disk `UUID`: на этапе разметки правильнее whole-disk `by-id`

### One-shot install

Основной сценарий теперь такой — **одна команда из корня репозитория**:

```bash
nix run .#install-honor-magicbook -- wkubearnament@<target-host>
```

Что делает app:

1. заходит по `SSH` на целевой host
2. консервативно сортирует install-диски по приоритету `NVMe > SATA SSD > прочий SSD > HDD`
3. жёстко фильтрует только подходящие whole-disk кандидаты и игнорирует `usb`, `loop`, `zram`, `md`, `dm-*`, `sr*`
4. если найдено несколько кандидатов — в обычном TTY предлагает **текстовый выбор без графики**
5. если пользователь не ответил за 20 секунд или сессия неинтерактивная/headless — автоматически берёт **первый кандидат**
6. первый кандидат — это самый быстрый класс диска, а внутри класса самый ранний device order
7. пытается найти стабильный `cameraDevicePath` через `/dev/v4l/by-id`, затем `by-path`
8. если камера не найдена — **не падает**, а просто не пишет `cameraDevicePath`
9. пишет в лог, как именно был выбран диск: `AUTOSELECTED=1` / `USERSELECTED=1`
10. пишет локальный файл
   `hosts/honor-magicbook-x16-pro/local-device-paths.nix`
11. запускает `nixos-anywhere` уже с корректным flake-конфигом

Если у тебя многодисковая машина и ты не хочешь полагаться на автоселект,
передай нужный `by-id` явно через override.

`selectionSource` в выводе покажет, был ли это `explicit-override`,
`env-disk-index`, `interactive-menu`, `single-candidate`,
`auto-timeout-or-default` или `auto-noninteractive`.

Скрипт также печатает `interactiveTTY`, `originalCandidateCount` и
`filteredCandidateCount`, чтобы в логах было видно, почему был выбран именно
этот диск.

### Auto-detect only

Если хочешь только сгенерировать пути устройств без установки:

```bash
nix run .#fetch-target-device-paths -- wkubearnament@<target-host>
```

Если нужно явно переопределить диск или камеру:

```bash
nix run .#fetch-target-device-paths -- \
  wkubearnament@<target-host> \
  hosts/honor-magicbook-x16-pro/local-device-paths.nix \
  /dev/disk/by-id/nvme-... \
  /dev/v4l/by-id/...-video-index0
```

Если нужен неинтерактивный, но управляемый выбор в сложной многодисковой машине,
используй env-переменные:

```bash
INSTALL_DISK_FILTER=nvme nix run .#fetch-target-device-paths -- wkubearnament@<target-host>
INSTALL_DISK_FILTER=Samsung INSTALL_DISK_INDEX=2 nix run .#fetch-target-device-paths -- wkubearnament@<target-host>
```

`INSTALL_DISK_FILTER` матчит класс диска (`nvme`, `sata-ssd`, `solid-state`, `hdd`)
или подстроку в `by-id` / модели.
`INSTALL_DISK_INDEX` — это номер кандидата, начиная с `1`, уже после фильтрации.

### Low-level fallback

Голая команда `nixos-anywhere` оставлена как fallback, но сама по себе она **не умеет**
до локальной оценки flake заранее узнать remote `disk by-id`.

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#honor-magicbook-x16-pro \
  wkubearnament@<target-host>
```

Если хочешь сначала вручную убедиться в разметке/доступности диска на целевой машине:

```bash
lsblk
```

В этой конфигурации ожидается системный диск:

```bash
/dev/nvme0n1
```

## Rebuild

На установленной системе:

```bash
run0 nixos-rebuild switch --flake /etc/nixos#honor-magicbook-x16-pro
```

## Update flake inputs

```bash
run0 nix flake update --flake /etc/nixos
```

## Face auth / Howdy

Проверить видеоустройства:

```bash
ls -l /dev/video* /dev/v4l/by-path
```

Добавить лицо в Howdy:

```bash
run0 howdy add
```

Если Howdy смотрит не в ту камеру, поправь `device_path` в:

```text
modules/nixos/howdy/howdy.nix
```

## Snapper

Проверить конфиг root:

```bash
snapper -c root list
```

## Virtualization

Проверить libvirt:

```bash
systemctl status libvirtd
```

## k3s

Проверить k3s:

```bash
systemctl status k3s
kubectl get nodes
```

## Webcam / UVC

Проверить, что камера поднялась через `uvcvideo`:

```bash
dmesg | grep -i uvc
```

Если `Howdy` не видит камеру, но `/dev/video*` есть, сначала проверь правильный node,
а не пытайся сразу искать vendor-specific драйвер.
