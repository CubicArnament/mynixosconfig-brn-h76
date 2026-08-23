{ lib, pkgs, isInstaller ? false, ... }:
let
  coldNixosGrubTheme = import ./grub_theme.nix { inherit pkgs; };
in
{
  boot.supportedFilesystems = { btrfs = true; vfat = true; };

  boot.loader = {
    efi.canTouchEfiVariables = false;
    timeout = 5;

    # disko-install forcibly maps --disk values to grub.devices, which makes
    # GRUB attempt a legacy i386-pc install. Bootstrap with UEFI systemd-boot;
    # the full post-install configuration replaces it with UEFI-only GRUB.
    systemd-boot.enable = isInstaller;

    grub = lib.mkIf (!isInstaller) {
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
