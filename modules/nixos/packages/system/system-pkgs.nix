{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    curl
    git
    openssh
    pciutils
    usbutils
    nano

    # Nix linters
    deadnix  # находит мёртвый код: неиспользуемые binding'и и аргументы
    statix   # находит антипаттерны и предлагает идиоматичные замены
  ];
}
