# modules/nixos/network/network.nix
#
# Сеть: NetworkManager, firmware и Bluetooth.
#
# Проверить после установки:
#   lspci -k | grep -A3 -i network
#   ip link                            # wlan0 или wlp*
#   nmcli device                       # wifi: unmanaged → disconnected → connected

{ pkgs, ... }:
{
  networking = {
    networkmanager = {
      enable = true;
      # wifi.backend = "iwd";  # раскомментируй если хочешь iwd вместо wpa_supplicant
    };

    # Явно не управлять через dhcpcd — NetworkManager берёт это на себя
    useDHCP = false;
  };

  # The kernel autoloads the correct driver once the actual PCI chipset is
  # discovered. The vendor does not publish its controller identity for BRN-H76.
  hardware.wirelessRegulatoryDatabase = true;

  # Full firmware is also enabled in hardware.nix; keep it explicit here.
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
