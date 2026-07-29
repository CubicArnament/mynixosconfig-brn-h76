{ pkgs, inputs, ... }:
let
  workingPackages = with pkgs; [
    # Editors and browsers
    zed-editor
    microsoft-edge
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

    # Development and terminal tooling
    opencode
    nodejs_22
    pnpm
  ];

  gamingPackages = with pkgs; [
    prismlauncher
  ];
in
{
  home.packages = workingPackages ++ gamingPackages;
}
