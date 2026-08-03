{ pkgs, hostName, ... }:
let
  nixosHelper = pkgs.callPackage ../../trustedinstaller/scripts/nixos-helper.d/drv.nix {
    inherit hostName;
  };
in
{
  environment.systemPackages = [ nixosHelper ];
}
