{ inputs, pkgs, hostName, userName, ... }:
let
  nixosHelper = pkgs.callPackage ../../trustedinstaller/scripts/nixos-helper.d/drv.nix {
    commandScripts = ../../trustedinstaller/scripts/nixos-helper.d/commands;
    homeManager = inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default;
    homeProfile = "${userName}@${hostName}";
    inherit hostName;
  };
in
{
  environment.systemPackages = [ nixosHelper ];
}
