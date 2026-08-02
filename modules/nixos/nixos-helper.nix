{ pkgs, hostName, ... }:
let
  flake = "/etc/nixos#${hostName}";
in
{
  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "nixos-helper";
      runtimeInputs = [ pkgs.nix pkgs.systemd ];
      text = ''
        case "''${1:-switch}" in
          -h|--help)
            cat <<'EOF'
            Usage: nixos-helper [command] [options]

            Uses the configured host flake at /etc/nixos. System rebuilds also
            activate the configured Home Manager user environment.

            Commands:
              switch   Build and apply now. This is the default.
              boot     Build now, activate on the next boot.
              test     Build and activate until the next boot.
              build    Build without activating.
              update   Update flake.lock in /etc/nixos.
              set-password
                       Set the local password for wkubearnament.

            All nixos-rebuild options are passed through.
            EOF
            ;;
          update)
            shift
            exec run0 nix flake update --flake /etc/nixos "$@"
            ;;
          set-password)
            if [ "$#" -ne 1 ]; then
              printf '%s\n' "Usage: nixos-helper set-password" >&2
              exit 2
            fi
            cat <<'EOF'
            This sets the local password for wkubearnament.
            Until a password exists, access is bootstrapped through the SSH key
            configured in /etc/nixos/hosts/honor-magicbook-x16-pro/env.ssh.
            EOF
            exec passwd
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
