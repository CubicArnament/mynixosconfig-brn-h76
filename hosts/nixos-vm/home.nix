{ user, ... }:
{
  imports = [
    (import ../../dev/development.nix).homeModule
    ../../modules/home/fish/fish.nix
    ../../modules/home/gnome/gnome.nix
    # виртуализация внутри VM обычно не нужна
    ../../modules/home/packages/user/user-pkgs.nix
  ];

  home = {
    username = user.name;
    homeDirectory = user.homeDirectory;
    stateVersion = user.homeStateVersion;
    sessionVariables = user.sessionVariables;
  };

  programs.home-manager.enable = true;
  programs.git.enable = true;
}
