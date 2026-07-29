{ pkgs, ... }:
let
  workingPackages = with pkgs; [
    # Editors and browsers
    zed-editor
    microsoft-edge

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
