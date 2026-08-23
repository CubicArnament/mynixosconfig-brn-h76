{ lib, pkgs, isInstaller ? false, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    nano
  ] ++ lib.optionals (!isInstaller) (with pkgs; [
    curl
    openssh
    pciutils
    usbutils
    v4l-utils
    deadnix
    statix
  ]);

  fonts.packages = lib.optionals (!isInstaller) [ pkgs.corefonts ];

  programs.steam = lib.mkIf (!isInstaller) {
    enable = true;
    extraCompatPackages =
      lib.optionals (builtins.hasAttr "proton-ge-bin" pkgs) [ pkgs."proton-ge-bin" ]
      ++ lib.optionals (builtins.hasAttr "steamtinkerlaunch" pkgs) [ pkgs.steamtinkerlaunch ];
  };
}
