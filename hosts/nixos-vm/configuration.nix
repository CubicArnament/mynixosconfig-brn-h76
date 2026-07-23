{ lib, pkgs, hostName, user, ... }:
{
  imports = [
    ../../modules/nixos/meta/machine-type.nix
    ../../modules/nixos/bootloader/bootloader.nix
    ../../modules/nixos/btrfs/btrfs.nix
    # disko.nix НЕ импортируется: в VM разметка делается вручную через cfdisk.
    # disko.nixosModules.disko также не подключён в mkHost для nixos-vm.
    ../../modules/nixos/auth/auth.nix
    # howdy в VM не нужен — нет вебкамеры для face auth
    (import ../../dev/development.nix).nixosModule
    ../../modules/nixos/gnome/gnome.nix
    ../../modules/nixos/kernel/kernel.nix
    ../../modules/nixos/laptop/laptop.nix
    ../../modules/nixos/fish/fish.nix
    # ../../modules/nixos/virtualization/virtualization.nix  # вложенная виртуализация обычно не нужна
    ../../modules/nixos/packages/flatpak/flatpak.nix
    ../../modules/nixos/packages/system/system-pkgs.nix
  ];

  # machine.isVm / machine.isLaptop / machine.cpuVendor определяются
  # автоматически из hardware-configuration.nix (boot.kernelModules) и
  # services.qemuGuest.enable. В VM qemuGuest.enable = true выставляется
  # автоматически при использовании nixos build-vm или QEMU-гостя.

  networking.hostName = hostName;
  networking.networkmanager.enable = true;

  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };

  nixpkgs.config = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = "ru_RU.UTF-8";

  console.useXkbConfig = true;
  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:alt_shift_toggle";
  };

  users.users.${user.name} = {
    isNormalUser = true;
    description = user.description;
    extraGroups = user.extraGroups;
    shell = user.shellPackage;
    home = user.homeDirectory;
  };

  services.openssh.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    wireplumber.enable = true;
  };

  # Bluetooth в VM обычно недоступен
  hardware.bluetooth.enable = false;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = [ "gnome" "gtk" ];
  };

  system.stateVersion = "26.05";
}
