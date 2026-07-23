# modules/nixos/disko/disko.nix
#
# Разметка диска через disko — только для физического железа (Honor MagicBook X16 Pro).
#
# Подключается через extraModules только для honor-хоста в flake.nix.
#
# Почему нет assertion/mkIf на machine.isVm:
#   machine.isVm читает config.services.qemuGuest.enable и boot.kernelModules,
#   а disko.devices оценивается раньше — возникает infinite recursion.
#   Защита не нужна: этот модуль просто не импортируется нигде кроме honor-хоста.
#
# diskDevice передаётся через specialArgs из local-device-paths.nix
# (генерируется скриптом scripts/fetch-target-device-paths.sh).

# diskDevice по умолчанию — фиктивный путь, безопасный для нix eval.
# При реальной установке через nixos-anywhere значение берётся из specialArgs
# (генерируется скриптом fetch-target-device-paths.sh → local-device-paths.nix).
# Если local-device-paths.nix не существует — eval проходит, но disko запускать нельзя.
{ diskDevice ? "/dev/disk/by-id/CONFIGURE-ME-run-fetch-target-device-paths", ... }:
let
  swapSize = "16G";  # без расчёта на гибернацию, под 16 ГБ RAM
  commonMountOptions = [
    "compress=zstd:3"
    "noatime"
    "ssd"
    "space_cache=v2"
  ];

  isPlaceholder = diskDevice == "/dev/disk/by-id/CONFIGURE-ME-run-fetch-target-device-paths";
in
{
  # Если diskDevice не был передан через specialArgs (нет local-device-paths.nix),
  # eval проходит нормально, но активация конфига завалится с понятным сообщением.
  # Это безопасно: assertion вычисляется после eval, рекурсии нет.
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

          # hosts/honor-magicbook-x16-pro/local-device-paths.nix
          {
            diskDevice = "/dev/disk/by-id/nvme-YOUR-DISK-ID";
          }

        Узнать by-id на целевой машине:
          ls -la /dev/disk/by-id/ | grep -v part
        ═══════════════════════════════════════════════════════════════════
      '';
    }
  ];
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
