{ pkgs, hostName, ... }:
let
  flakePath = "/etc/nixos";
in
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nixos-rebuild-helper";
      runtimeInputs = [ pkgs.systemd ];
      text = ''
        if [ "$#" -eq 0 ]; then
          set -- switch
        fi

        exec run0 nixos-rebuild "$@" --flake ${flakePath}#${hostName}
      '';
    })
    (pkgs.writeShellApplication {
      name = "nixos-update";
      runtimeInputs = [ pkgs.nix pkgs.systemd ];
      text = ''
        exec run0 nix flake update --flake ${flakePath}
      '';
    })
  ];
}
