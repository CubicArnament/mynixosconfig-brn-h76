
{ diskDevice ? "/dev/disk/by-id/CONFIGURE-ME-run-fetch-target-device-paths", ... }:
let
  swapSize = "16G";
  commonMountOptions = [
    "compress=zstd:3"
    "noatime"
    "ssd"
    "space_cache=v2"
  ];

  isPlaceholder = diskDevice == "/dev/disk/by-id/CONFIGURE-ME-run-fetch-target-device-paths";
in
{
  assertions = [
    {
      assertion = !isPlaceholder;
      message = ''

        ═══════════════════════════════════════════════════════════════════
        disko.nix: diskDevice не настроен.

        Файл hosts/honor-magicbook-x16-pro/local-device-paths.nix не найден
        или не содержит diskDevice.

        Сгенерируй его автоматически:

          nix run .#fetch-target-device-paths -- <user>@<target-host>

        Или запусти полную установку одной командой:

          nix run .#install-honor-magicbook -- <user>@<target-host>

        Или создай файл вручную:

          {
            diskDevice = "/dev/disk/by-id/nvme-YOUR-DISK-ID";
          }

        Узнать by-id на целевой машине:
          ls -la /dev/disk/by-id/ | grep -v part
        ═══════════════════════════════════════════════════════════════════
      '';
    }
  ];
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
