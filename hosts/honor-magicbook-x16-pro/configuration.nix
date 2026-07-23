{ lib, pkgs, hostName, user, ... }:
{
  imports = [
    ./hardware.nix
    ../../modules/nixos/meta/machine-type.nix
    ../../modules/nixos/bootloader/bootloader.nix
    ../../modules/nixos/btrfs/btrfs.nix
    ../../modules/nixos/disko/disko.nix
    ../../modules/nixos/auth/auth.nix
    ../../modules/nixos/howdy/howdy.nix
    # ../../modules/nixos/fprint/fprint.nix  # fprintd для Goodix 27c6:5125; включи и выставь machine.fprint.enable = true
    (import ../../dev/development.nix).nixosModule
    ../../modules/nixos/gnome/gnome.nix
    ../../modules/nixos/kernel/kernel.nix
    ../../modules/nixos/laptop/laptop.nix
    ../../modules/nixos/power/power.nix
    ../../modules/nixos/fish/fish.nix
    ../../modules/nixos/virtualization/virtualization.nix
    # ../../modules/nixos/cncf/cncf.nix  # k3s сервер + порт 6443; включи если нужен кластер на ноуте
    ../../modules/nixos/packages/flatpak/flatpak.nix
    ../../modules/nixos/packages/system/system-pkgs.nix
  ];

  # Honor MagicBook X16 Pro — физический AMD ноутбук.
  # machine.isVm / machine.isLaptop / machine.cpuVendor определяются
  # автоматически из hardware-configuration.nix (boot.kernelModules).
  # Если автодетект ошибётся — переопредели через lib.mkForce:
  #   machine.isVm = lib.mkForce false;
  #   machine.cpuVendor = lib.mkForce "amd";

  networking = {
    hostName = hostName;
    networkmanager.enable = true;
  };

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

  services = {
    xserver = {
      xkb = {
        layout = "us,ru";
        options = "grp:alt_shift_toggle";
      };
    };

    openssh = {
      enable = true;
    };

    pipewire = {
      enable = true;
      pulse.enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      wireplumber.enable = true;
    };
  };

  users.users.${user.name} = {
    isNormalUser = true;
    inherit (user) description extraGroups;
    shell = user.shellPackage;
    home = user.homeDirectory;
  };

  security.rtkit.enable = true;

  hardware = {
    bluetooth.enable = true;
  };

  # Wayland screen sharing for OBS/Discord/Electron apps depends on
  # PipeWire + xdg-desktop-portal. GNOME's portal backend should be the
  # primary implementation, with GTK left as a compatibility fallback.
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
