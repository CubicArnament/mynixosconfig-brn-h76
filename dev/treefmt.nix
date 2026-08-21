{
  projectRootFile = "flake.nix";

  programs = {
    nixfmt.enable = true;
    shfmt = {
      enable = true;
      arguments = [ "-i" "2" "-ci" "-sr" ];
    };
  };
}
