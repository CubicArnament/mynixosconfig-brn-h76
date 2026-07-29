{ pkgs, hostName, ... }:
let
  flakePath = "/etc/nixos";
in
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "rebuild-helper";
      runtimeInputs = [ pkgs.systemd ];
      text = ''
        if [ "''${1:-}" = "-h" ] || [ "''${1:-}" = "--help" ]; then
          cat <<'EOF'
          Usage: rebuild-helper [nixos-rebuild subcommand] [options]

          Rebuilds the configured host from /etc/nixos.

          Commands:
            rebuild-helper          Apply the configuration now (switch).
            rebuild-helper switch   Build and apply the configuration now.
            rebuild-helper boot     Build and activate on the next boot.
            rebuild-helper test     Build and activate until the next boot.
            rebuild-helper build    Build without activating.

          Any additional nixos-rebuild options are passed through.
          EOF
          exit 0
        fi

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
