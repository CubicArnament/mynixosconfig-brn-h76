{ pkgs, hostName, ... }:
{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting
    '';
    shellAliases = {
      rebuild = "sudo nixos-rebuild switch --flake /etc/nixos#${hostName}";
      update = "sudo nix flake update --flake /etc/nixos";
    };
    plugins = [
      {
        name = "tide";
        src = pkgs.fishPlugins.tide.src;
      }
    ];
  };
}
