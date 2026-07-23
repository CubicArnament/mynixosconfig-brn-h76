# modules/nixos/disko/disko.nix
#
# Разметка диска через disko — только для физического железа.
#
# Этот модуль подключается ТОЛЬКО для honor-хоста через extraModules в flake.nix.
# nixos-vm его не видит вообще — защита на уровне структуры флейка, а не assert.
#
# Почему здесь нет assertion/mkIf на machine.isVm:
#   machine.isVm читает config.services.qemuGuest.enable и boot.kernelModules,
#   а disko.devices оценивается раньше — возникает infinite recursion.
#   Правильная защита: не импортировать этот модуль в VM-конфиг (уже сделано).
#
# diskDevice передаётся через specialArgs из local-device-paths.nix
# (генерируется скриптом scripts/fetch-target-device-paths.sh).

{ diskDevice, ... }:
let
  swapSize = "16G";  # без расчёта на гибернацию, под 16 ГБ RAM
  commonMountOptions = [
    "compress=zstd:3"
    "noatime"
    "ssd"
    "space_cache=v2"
  ];
in
{
  # Для disko raw-disk UUID не подходит: файловой UUID ещё нет до разметки.
  # Правильный вариант — /dev/disk/by-id (передаётся через diskDevice).
  # Скрипт scripts/fetch-target-device-paths.sh генерирует local-device-paths.nix.
  disko.devices = {
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
