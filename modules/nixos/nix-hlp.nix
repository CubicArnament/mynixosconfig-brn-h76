{ inputs, lib, pkgs, hostName, userName, isInstaller ? false, ... }:
let
  formatter = (inputs.treefmt-nix.lib.evalModule pkgs ../../dev/treefmt.nix).config.build.wrapper;
  nixHlp = pkgs.callPackage ../../trustedinstaller/scripts/nixos-helper.d/drv.nix {
    commandScripts = ../../trustedinstaller/scripts/nixos-helper.d/commands;
    inherit formatter;
    homeManager = inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default;
    homeProfile = "${userName}@${hostName}";
    inherit hostName;
    templateScripts = ../../trustedinstaller/scripts/nixos-helper.d/templates;
  };
in
{
  environment.systemPackages = lib.optionals (!isInstaller) [ nixHlp ];
}
