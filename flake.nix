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

    nix-flatpak = {
      url = "github:gmodena/nix-flatpak/?ref=v0.7.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, disko, home-manager, nix-flatpak, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };
    hostName = "honor-magicbook-x16-pro";
    hostDir = ./hosts/honor-magicbook-x16-pro;
    user = import (hostDir + "/user.nix") { inherit pkgs; };
    localDevicePathsPath = hostDir + "/local-device-paths.nix";
    localDevicePaths = if builtins.pathExists localDevicePathsPath then import localDevicePathsPath else { };
    localDevicePathsRel = "hosts/${hostName}/local-device-paths.nix";
    userName = user.name;

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

        HOST="${1:-}"
        if [ -z "$HOST" ]; then
          echo "usage: install-honor-magicbook <ssh-target>" >&2
          exit 1
        fi

        REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
        cd "$REPO_ROOT"

        ${fetchTargetDevicePaths}/bin/fetch-target-device-paths "$HOST" "${localDevicePathsRel}"

        nix run github:nix-community/nixos-anywhere -- \
          --flake .#${hostName} \
          "$HOST"
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

    nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit inputs hostName user userName;
      } // localDevicePaths;

      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        nix-flatpak.nixosModules.nix-flatpak
        ./hosts/${hostName}/configuration.nix
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit inputs hostName user userName;
          } // localDevicePaths;
          home-manager.users.${user.name} = import ./hosts/${hostName}/home.nix;
        }
      ];
    };
  };
}
