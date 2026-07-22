{ lib, pkgs, hostName, userName, ... }:
{
  imports = [
    ./hardware.nix
    ../../modules/nixos/bootloader/bootloader.nix
    ../../modules/nixos/btrfs/btrfs.nix
    ../../modules/nixos/disko/disko.nix
    ../../modules/nixos/auth/auth.nix
    ../../modules/nixos/howdy/howdy.nix
    ../../modules/nixos/gnome/gnome.nix
    ../../modules/nixos/kernel/kernel.nix
    ../../modules/nixos/laptop/laptop.nix
    ../../modules/nixos/fish/fish.nix
    ../../modules/nixos/virtualization/virtualization.nix
    ../../modules/nixos/packages/flatpak/flatpak.nix
    ../../modules/nixos/packages/system/system-pkgs.nix
  ];

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

  nixpkgs.config.allowUnfree = true;

  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = "ru_RU.UTF-8";

  console.useXkbConfig = true;
  services.xserver.xkb = {
    layout = "us,ru";
    options = "grp:alt_shift_toggle";
  };

  users.users.${userName} = {
    isNormalUser = true;
    description = "Primary user";
    extraGroups = [ "wheel" "networkmanager" "libvirtd" ];
  };



  services.openssh.enable = true;

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  hardware.bluetooth.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
  };

  system.stateVersion = "25.05";
}
