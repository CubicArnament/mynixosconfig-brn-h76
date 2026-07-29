# modules/nixos/default.nix
#
# Единая точка входа для всех NixOS-модулей.
# Импортируй в configuration.nix хоста одной строкой:
#   inputs.self.nixosModules.default  (через specialArgs)
# или классически:
#   ../../modules/nixos
#
# Модули с условной активацией (amd/, network/) безопасны на любом железе —
# они сами проверяют machine.cpuVendor / machine.gpuVendor внутри.
#
# Хост-специфичные вещи (hardware.nix, disko.nix, hostname, stateVersion)
# НЕ здесь — они остаются в configuration.nix хоста.

_:
{
  imports = [
    # Мета — должна быть первой: объявляет options.machine.*
    ./meta/machine-type.nix

    # Ядро системы
    ./core/core.nix

    # Железо и платформа
    ./amd/chipset.nix
    ./amd/amdgpu.nix
    ./btrfs/btrfs.nix
    ./bootloader/bootloader.nix
    ./kernel/kernel.nix
    ./rebuild-helper.nix

    # Сеть
    ./network/network.nix

    # Рабочий стол
    ./gnome/gnome.nix

    # Аутентификация и безопасность
    ./auth/auth.nix
    ./howdy/howdy.nix
    # ./fprint/fprint.nix  # включи и выставь machine.fprint.enable = true

    # Ноутбук
    ./laptop/laptop.nix
    ./power/power.nix

    # Оболочка
    ./fish/fish.nix

    # Виртуализация
    ./virtualization/virtualization.nix

    # Пакеты
    ./packages/flatpak/flatpak.nix
    ./packages/system/system-pkgs.nix

    # CNCF (опционально)
    # ./cncf/cncf.nix  # k3s + порт 6443; включи если нужен кластер
  ];
}
