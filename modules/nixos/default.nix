
_:
{
  imports = [
    ./meta/machine-type.nix

    ./core/core.nix

    ./amd/chipset.nix
    ./amd/amdgpu.nix
    ./btrfs/btrfs.nix
    ./bootloader/bootloader.nix
    ./kernel/kernel.nix
    ./nix-hlp.nix

    ./network/network.nix

    ./gnome/gnome.nix

    ./auth/auth.nix
    ./howdy/howdy.nix

    ./laptop/laptop.nix
    ./power/power.nix

    ./fish/fish.nix

    ./virtualization/virtualization.nix

    ./packages/flatpak/flatpak.nix
    ./packages/system/system-pkgs.nix

  ];
}
