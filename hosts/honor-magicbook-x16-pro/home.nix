{ userName, ... }:
{
  imports = [
    ../../modules/home/fish/fish.nix
    ../../modules/home/gnome/gnome.nix
    ../../modules/home/virtualization/virtualization.nix
    ../../modules/home/packages/user/user-pkgs.nix
  ];

  home = {
    username = userName;
    homeDirectory = "/home/${userName}";
    stateVersion = "25.05";
    sessionVariables = {
      EDITOR = "vi";
    };
  };

  programs.home-manager.enable = true;

  programs.git.enable = true;
}
