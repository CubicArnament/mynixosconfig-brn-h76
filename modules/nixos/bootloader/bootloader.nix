{ pkgs, ... }:
let
  coldNixosGrubTheme = import ./grub_theme.nix { inherit pkgs; };
in
{
  boot.supportedFilesystems = { btrfs = true; vfat = true; };

  boot.loader = {
    # Install GRUB at the UEFI fallback path (/EFI/BOOT/BOOTX64.EFI) instead
    # of relying on a firmware NVRAM entry created by the live environment.
    efi.canTouchEfiVariables = false;
    timeout = 5;

    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      efiInstallAsRemovable = true;
      gfxmodeEfi = "1920x1080,auto";
      gfxpayloadEfi = "keep";
      theme = coldNixosGrubTheme;
      backgroundColor = "#2E3440";
    };
  };
}
