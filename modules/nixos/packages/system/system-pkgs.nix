{ pkgs, ... }:
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

  programs.steam = {
    enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
      steamtinkerlaunch
    ];
  };
}
