{ diskDevice ? "/dev/nvme0n1", ... }:
let
  # Для disko raw-disk UUID не подходит: файловой UUID ещё нет до разметки.
  # Поэтому правильный переносимый вариант для install-target — /dev/disk/by-id.
  # Скрипт scripts/fetch-target-device-paths.sh может сгенерировать
  # hosts/honor-magicbook-x16-pro/local-device-paths.nix без ручной правки repo.
  # 16G swap без расчёта на гибернацию, под конфигурацию с 16 ГБ RAM.
  swapSize = "16G";
  commonMountOptions = [
    "compress=zstd:3"
    "noatime"
    "ssd"
    "space_cache=v2"
  ];
in {
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

                # Для snapper важно, чтобы /.snapshots был отдельной точкой
                # монтирования Btrfs subvolume, но при этом был виден внутри /
                # как обычный подкаталог .snapshots корневого subvolume.
                # Поэтому subvolume монтируется именно в /.snapshots.
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
