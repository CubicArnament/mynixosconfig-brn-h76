{ pkgs, hostName, ... }:
{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting
    '';
    shellAliases = {
      rebuild = "run0 nixos-rebuild switch --flake ~/.config/nixos#${hostName}";
      update = "run0 nix flake update --flake ~/.config/nixos";
    };
    plugins = [
      {
        name = "tide";
        src = pkgs.fishPlugins.tide.src;
      }
    ];
  };
}
