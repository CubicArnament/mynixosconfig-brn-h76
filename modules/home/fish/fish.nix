{ pkgs, ... }:
let
  fzfFish = pkgs.fishPlugins.fzf-fish;
in
{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting

      fzf_configure_bindings --history=\cr --directory=\cf --variables=\cv
    '';
    plugins = [
      {
        name = "tide";
        inherit (pkgs.fishPlugins.tide) src;
      }
      {
        name = fzfFish.pname;
        inherit (fzfFish) src;
      }
    ];
  };

  home.packages = with pkgs; [ fzf ];
}
