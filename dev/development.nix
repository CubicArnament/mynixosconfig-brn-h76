{
  nixosModule = _:
  {
    nix.settings = {
      allowed-users = [ "@wheel" ];
      trusted-users = [ "root" "@wheel" ];
      keep-derivations = true;
      keep-outputs = true;
    };
  };

  homeModule = _:
  {
    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      silent = false;
    };

    programs.fish.shellAbbrs = {
      nd = "nix develop";
      nf = "nix flake check";
      nu = "nix flake update";
    };
  };
}
