{ pkgs, hostName, ... }:
let
  flake = "/etc/nixos#${hostName}";
in
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "rebuild-helper";
      runtimeInputs = [ pkgs.nix pkgs.systemd ];
      text = ''
        case "''${1:-switch}" in
          -h|--help)
            cat <<'EOF'
            Usage: rebuild-helper [command] [options]

            Uses the configured host flake at /etc/nixos.

            Commands:
              switch   Build and apply now. This is the default.
              boot     Build now, activate on the next boot.
              test     Build and activate until the next boot.
              build    Build without activating.
              update   Update flake.lock in /etc/nixos.

            All nixos-rebuild options are passed through.
            EOF
            ;;
          update)
            shift
            exec run0 nix flake update --flake /etc/nixos "$@"
            ;;
          *)
            exec run0 nixos-rebuild "$@" --flake ${flake}
            ;;
        esac

        exit 0
      '';
    })
  ];
}
