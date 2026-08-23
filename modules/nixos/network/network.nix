
{ pkgs, lib, isInstaller ? false, ... }:
{
  networking = {
    networkmanager = {
      enable = true;
    };

    useDHCP = false;
  };

  hardware.wirelessRegulatoryDatabase = true;

  hardware = {
    firmware = [ pkgs.linux-firmware ];

    bluetooth = lib.mkIf (!isInstaller) {
      enable = true;
      powerOnBoot = true;
      settings.General.Experimental = true;
    };
  };

  services.blueman.enable = !isInstaller;
}
