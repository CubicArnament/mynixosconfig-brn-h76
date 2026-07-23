{ pkgs, hostName, ... }:
{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting

      # fzf-fish: подключаем fzf к fish для fuzzy-поиска по истории,
      # файлам и переменным (Ctrl+R, Ctrl+Alt+F, Ctrl+V)
      fzf_configure_bindings --history=\cr --directory=\cf --variables=\cv
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
      {
        # fzf-fish: fuzzy autocomplete для файлов, истории, переменных,
        # процессов и git log прямо в fish (Ctrl+R и др.)
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
    ];
  };

  # fzf нужен как runtime зависимость для fzf-fish
  home.packages = [ pkgs.fzf ];
}
