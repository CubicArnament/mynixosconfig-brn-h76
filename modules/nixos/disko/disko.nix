
{ diskDevice, ... }:
let
  swapSize = "16G";
  commonMountOptions = [
    "compress=zstd:3"
    "noatime"
    "ssd"
    "space_cache=v2"
  ];

in
{
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
