{ pkgs, ... }:
let
  coldNixosGrubTheme = import ./grub_theme.nix { inherit pkgs; };
in
{
  boot.supportedFilesystems = { btrfs = true; vfat = true; };

  boot.loader = {
    efi.canTouchEfiVariables = true;
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
