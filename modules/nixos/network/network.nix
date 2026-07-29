# modules/nixos/network/network.nix
#
# Сеть: NetworkManager + Qualcomm WCN685x (ath11k) WiFi + Bluetooth.
#
# WCN685x (Honor MagicBook X16 Pro BRN-H76) использует драйвер ath11k.
# Требует firmware из linux-firmware (включён через hardware.enableAllFirmware
# в hardware.nix) и wireless-regdb для regulatory domain.
#
# Проверить после установки:
#   lspci -k | grep -A3 -i network    # должен показать ath11k_pci
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

  # Загружать ath11k в initrd чтобы wifi был доступен сразу после boot
  # (нужно если root на NFS или encrypted с remote unlock)
  # boot.initrd.kernelModules = [ "ath11k" "ath11k_pci" ];

  # ath11k и ath11k_pci загружаются автоматически через udev при обнаружении PCI-устройства.
  # Явная загрузка нужна только если udev не справляется (редко).
  boot.kernelModules = [ "ath11k_pci" ];

  # Regulatory database — без неё ath11k не поднимает wifi интерфейс
  # (dmesg: "Direct firmware load for regulatory.db failed")
  hardware.wirelessRegulatoryDatabase = true;

  # linux-firmware содержит бинарные блобы для WCN685x:
  #   /lib/firmware/ath11k/WCN6855/hw2.0/
  # Уже включён через hardware.enableAllFirmware в hardware.nix,
  # но дублируем явно как документацию зависимости.
  hardware = {
    firmware = [ pkgs.linux-firmware ];

    # Bluetooth через btusb / hci — Honor MagicBook X16 Pro использует
    # встроенный BT от того же WCN685x чипа (combo WiFi+BT)
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.Experimental = true;
    };
  };

  services.blueman.enable = true;
}
