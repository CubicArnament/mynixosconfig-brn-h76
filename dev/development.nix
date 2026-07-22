{
  nixosModule = { ... }:
  {
    # Let normal admin users work comfortably with flakes, dev shells and other
    # Nix developer workflows without falling back to root for everyday tasks.
    nix.settings = {
      allowed-users = [ "@wheel" ];
      trusted-users = [ "root" "@wheel" ];
      keep-derivations = true;
      keep-outputs = true;
    };
  };

  homeModule = { ... }:
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
