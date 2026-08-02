{ pkgs, ... }:
let
  fzfFish = pkgs.fishPlugins.fzf-fish;
in
{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting

      # fzf-fish: подключаем fzf к fish для fuzzy-поиска по истории,
      # файлам и переменным (Ctrl+R, Ctrl+Alt+F, Ctrl+V)
      fzf_configure_bindings --history=\cr --directory=\cf --variables=\cv
    '';
    plugins = [
      {
        name = "tide";
        inherit (pkgs.fishPlugins.tide) src;
      }
      {
        # fzf-fish: fuzzy autocomplete для файлов, истории, переменных,
        # процессов и git log прямо в fish (Ctrl+R и др.)
        name = fzfFish.pname;
        inherit (fzfFish) src;
      }
    ];
  };

  # fzf нужен как runtime зависимость для fzf-fish
  home.packages = with pkgs; [ fzf ];
}
