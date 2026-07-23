# modules/nixos/disko/disko.nix
#
# Разметка диска через disko — только для физического железа.
#
# На виртуальной машине disko НЕ применяется: сборка падает с понятным
# сообщением и инструкцией по ручной разметке через cfdisk.
#
# Этот модуль импортируется только honor-хостом. nixos-vm его не видит.
# diskDevice передаётся через specialArgs из local-device-paths.nix
# (генерируется скриптом scripts/fetch-target-device-paths.sh).

{ lib, config, diskDevice, ... }:
let
  cfg = config.machine;

  swapSize = "16G";  # без расчёта на гибернацию, под 16 ГБ RAM
  commonMountOptions = [
    "compress=zstd:3"
    "noatime"
    "ssd"
    "space_cache=v2"
  ];
in
{
  # ─── Защита: запрет disko в VM ────────────────────────────────────────────
  # Если этот модуль каким-то образом попал в VM-конфиг — сборка упадёт
  # здесь с инструкцией, а не с невнятной ошибкой модульной системы.
  assertions = [
    {
      assertion = !cfg.isVm;
      message = ''

        ═══════════════════════════════════════════════════════════════════
        disko.nix подключён в VM-конфиге — это не поддерживается.
        disko предназначен только для физического железа.

        В виртуальной машине используй скрипт установки:

          run0 sh ./scripts/vm-install-mount.sh

        Скрипт сам найдёт подходящий раздел (ext4/btrfs), предложит
        выбор если кандидатов несколько, смонтирует /mnt и /mnt/boot,
        сгенерирует hardware-configuration.nix и запустит nixos-install.

        Если диск ещё не размечен — скрипт покажет инструкцию по cfdisk.

        Убедись что disko.nix НЕ импортируется в hosts/nixos-vm/configuration.nix
        и disko.nixosModules.disko НЕ передан в extraModules для nixos-vm в flake.nix.
        ═══════════════════════════════════════════════════════════════════
      '';
    }
  ];

  # ─── disko layout — только для физического железа ─────────────────────────
  # Для disko raw-disk UUID не подходит: файловой UUID ещё нет до разметки.
  # Правильный вариант — /dev/disk/by-id (передаётся через diskDevice).
  # Скрипт scripts/fetch-target-device-paths.sh генерирует local-device-paths.nix.
  disko.devices = lib.mkIf (!cfg.isVm) {
    disk.main = {
      type = "disk";
      device = diskDevice;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };

          root = {
            size = "100%";
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes = {
                "/@" = {
                  mountpoint = "/";
                  mountOptions = commonMountOptions;
                };

                "/@home" = {
                  mountpoint = "/home";
                  mountOptions = commonMountOptions;
                };

                "/@nix" = {
                  mountpoint = "/nix";
                  mountOptions = commonMountOptions;
                };

                # /.snapshots — отдельный Btrfs subvolume, но виден как
                # подкаталог / — именно так требует snapper.
                "/@snapshots" = {
                  mountpoint = "/.snapshots";
                  mountOptions = commonMountOptions;
                };

                "/@swap" = {
                  mountpoint = "/swap";
                  mountOptions = [ "noatime" "ssd" ];
                  swap.swapfile.size = swapSize;
                };
              };
            };
          };
        };
      };
    };
  };
}
