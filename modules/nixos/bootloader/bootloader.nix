{ ... }:
{
  boot.supportedFilesystems = [ "btrfs" "vfat" ];

  boot.loader = {
    efi.canTouchEfiVariables = true;

    grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
      btrfsSupport = true;
      useOSProber = true;
      gfxmodeEfi = "auto";
      timeout = 5;
    };
  };
}
