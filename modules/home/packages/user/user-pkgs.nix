{ lib, pkgs, inputs, ... }:
let
  happ = pkgs.callPackage ../../../../dev/maintaining/happ.nix { };

  workingPackages = with pkgs; [
    zed-editor
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    onlyoffice-desktopeditors
    inputs.flclashx.packages.${pkgs.stdenv.hostPlatform.system}.flclashx
    happ

    nodejs_22
    pnpm
  ]
  ++ lib.optionals (builtins.hasAttr "microsoft-edge" pkgs) [ pkgs."microsoft-edge" ]
  ++ lib.optionals (builtins.hasAttr "opencode" pkgs) [ pkgs.opencode ];

  gamingPackages = with pkgs; [
    prismlauncher
  ];
in
{
  home.packages = workingPackages ++ gamingPackages;
}
