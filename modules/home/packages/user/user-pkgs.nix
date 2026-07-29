{ pkgs, ... }:
let
  workingPackages = with pkgs; [
    zed-editor
  ];

  gamingPackages = with pkgs; [
    prismlauncher
  ];
in
{
  home.packages = workingPackages ++ gamingPackages;
}
