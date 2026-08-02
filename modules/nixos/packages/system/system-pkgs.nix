{ lib, pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    curl
    git
    openssh
    pciutils
    usbutils
    v4l-utils
    nano

    # Nix linters
    deadnix  # находит мёртвый код: неиспользуемые binding'и и аргументы
    statix   # находит антипаттерны и предлагает идиоматичные замены
  ];

  fonts.packages = [ pkgs.corefonts ];

  programs.steam = {
    enable = true;
    extraCompatPackages =
      lib.optionals (builtins.hasAttr "proton-ge-bin" pkgs) [ pkgs."proton-ge-bin" ]
      ++ lib.optionals (builtins.hasAttr "steamtinkerlaunch" pkgs) [ pkgs.steamtinkerlaunch ];
  };
}
