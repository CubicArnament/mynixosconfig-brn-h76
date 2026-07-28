{ user, ... }:
{
  imports = [
    (import ../../dev/development.nix).homeModule
    ../../modules/home/amd/rocm.nix
    ../../modules/home/fish/fish.nix
    ../../modules/home/gnome/gnome.nix
    ../../modules/home/virtualization/virtualization.nix
    # ../../modules/home/cncf/cncf.nix  # helm + kubectl; включи если нужен cncf-тулинг
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
