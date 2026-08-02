{ lib, pkgs, inputs, ... }:
let
  flclashx = pkgs.callPackage ../../../../dev/maintaining/flclashx.nix { };

  workingPackages = with pkgs; [
    # Editors and browsers
    zed-editor
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    onlyoffice-desktopeditors
    flclashx

    # Development and terminal tooling
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
