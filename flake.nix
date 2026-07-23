{
  description = "NixOS flake for Honor MagicBook X16 Pro BRN-H76";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nix-flatpak v0.7.0 has no declared inputs of its own, so there is
    # nothing here to override with `follows`.
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";
  };

  outputs = inputs@{ self, nixpkgs, disko, home-manager, nix-flatpak, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    # Общий user для всех хостов — имя/shell/home живут в user.nix
    user = import ./hosts/honor-magicbook-x16-pro/user.nix { inherit pkgs; };
    userName = user.name;

    # Хелпер для сборки nixosConfiguration.
    # localDevicePaths — опциональный атрибутсет из local-device-paths.nix
    # (diskDevice, cameraDevicePath). Передаётся через specialArgs, чтобы
    # disko.nix и howdy.nix могли получить значения без хардкода в repo.
    mkHost = { hostName, extraModules ? [], localDevicePaths ? {} }:
      let
        sharedArgs = { inherit inputs hostName user userName; } // localDevicePaths;
      in
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = sharedArgs;
        modules = [
          home-manager.nixosModules.home-manager
          nix-flatpak.nixosModules.nix-flatpak
          ./hosts/${hostName}/configuration.nix
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = sharedArgs;
              users.${user.name} = import ./hosts/${hostName}/home.nix;
            };
          }
        ] ++ extraModules;
      };

    # Honor MagicBook — основной хост
    honorHostName = "honor-magicbook-x16-pro";
    honorHostDir = ./hosts/${honorHostName};
    honorLocalDevicePathsFile = honorHostDir + "/local-device-paths.nix";
    honorLocalDevicePaths =
      if builtins.pathExists honorLocalDevicePathsFile
      then import honorLocalDevicePathsFile
      else { };
    honorLocalDevicePathsRel = "hosts/${honorHostName}/local-device-paths.nix";

    fetchTargetDevicePaths = pkgs.writeShellApplication {
      name = "fetch-target-device-paths";
      runtimeInputs = with pkgs; [ coreutils findutils gawk gnugrep gnused openssh util-linux ];
      text = builtins.readFile ./scripts/fetch-target-device-paths.sh;
    };

    installHonorMagicbook = pkgs.writeShellApplication {
      name = "install-honor-magicbook";
      runtimeInputs = with pkgs; [ git nix openssh ];
      text = ''
        set -eu

        HOST="''${1:-}"
        if [ -z "$HOST" ]; then
          echo "usage: install-honor-magicbook <ssh-target|localhost>" >&2
          echo "  localhost  — local install via disko + nixos-install (run from NixOS live ISO)" >&2
          echo "  user@host  — remote install via nixos-anywhere over SSH" >&2
          exit 1
        fi

        REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
        cd "$REPO_ROOT"

        ${fetchTargetDevicePaths}/bin/fetch-target-device-paths "$HOST" "${honorLocalDevicePathsRel}"

        case "$HOST" in
          localhost|127.0.0.1|::1)
            echo "Local install mode: running disko then nixos-install"

            DISK_DEVICE=$(nix eval --raw .#nixosConfigurations.${honorHostName}.config.disko.devices.disk.main.device)

            # Partition and format the disk via disko
            nix --extra-experimental-features "nix-command flakes" run github:nix-community/disko -- \
              --mode destroy,format,mount \
              --flake .#${honorHostName}

            # Install NixOS onto the freshly mounted filesystems
            nixos-install \
              --no-root-passwd \
              --flake .#${honorHostName}
            ;;
          *)
            nix --extra-experimental-features "nix-command flakes" run github:nix-community/nixos-anywhere -- \
              --flake .#${honorHostName} \
              "$HOST"
            ;;
        esac
      '';
    };
  in {
    packages.${system} = {
      inherit fetchTargetDevicePaths installHonorMagicbook;
      default = installHonorMagicbook;
    };

    apps.${system} = {
      fetch-target-device-paths = {
        type = "app";
        program = "${fetchTargetDevicePaths}/bin/fetch-target-device-paths";
      };
      install-honor-magicbook = {
        type = "app";
        program = "${installHonorMagicbook}/bin/install-honor-magicbook";
      };
      default = self.apps.${system}.install-honor-magicbook;
    };

    nixosConfigurations = {
      # Honor MagicBook X16 Pro BRN-H76
      ${honorHostName} = mkHost {
        hostName = honorHostName;
        localDevicePaths = honorLocalDevicePaths;
        extraModules = [ disko.nixosModules.disko ];
      };
    };
  };
}
