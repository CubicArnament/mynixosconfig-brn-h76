
{ pkgs, ... }:
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

    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.Experimental = true;
    };
  };

  services.blueman.enable = true;
}
