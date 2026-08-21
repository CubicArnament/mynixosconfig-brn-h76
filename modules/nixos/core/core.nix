
{ lib, pkgs, user, ... }:
{
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

  security.rtkit.enable = true;

  xdg.portal = {
    enable = true;
    xdgOpenUsePortal = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = [ "gnome" "gtk" ];
  };

  users.users.${user.name} = {
    isNormalUser = true;
    inherit (user) description extraGroups;
    shell = user.shellPackage;
    home = user.homeDirectory;
    # Initial hashed password for console/TTY fallback authentication
    # Defined in hosts/*/user.nix, sourced from the repository-root env.hpasswd.
    # This is ONLY used on user creation - passwd changes are NOT overridden
    inherit (user) initialHashedPassword;
  };
}
