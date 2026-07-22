# Commands

## NixOS Anywhere

Запускать **с Linux-машины / live ISO**, не с Windows.

Из корня репозитория:

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
