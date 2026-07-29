# modules/nixos/core/core.nix
#
# Универсальная рутина для десктопных NixOS машин.
# Сюда вынесено всё что одинаково для 95% хостов и не зависит от железа.
#
# Хост-специфичные вещи (hostname, stateVersion, пользователь) остаются
# в configuration.nix хоста.

{ lib, pkgs, user, ... }:
{
  # ── Nix ─────────────────────────────────────────────────────────────────────
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

  # ── Локаль и время ──────────────────────────────────────────────────────────
  # timeZone намеренно mkDefault — хост может переопределить
  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = "ru_RU.UTF-8";
  console.useXkbConfig = true;

  # ── Сервисы ─────────────────────────────────────────────────────────────────
  services = {
    openssh.enable = true;

    xserver.xkb = {
      layout = "us,ru";
      options = "grp:alt_shift_toggle";
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

  # ── Аудио: PipeWire ─────────────────────────────────────────────────────────
  security.rtkit.enable = true;  # нужен для real-time приоритета PipeWire

  # ── Wayland portal (screen sharing, file picker) ────────────────────────────
  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = [ "gnome" "gtk" ];
  };

  # ── Пользователь ────────────────────────────────────────────────────────────
  users.users.${user.name} = {
    isNormalUser = true;
    inherit (user) description extraGroups;
    shell = user.shellPackage;
    home = user.homeDirectory;
  };
}
