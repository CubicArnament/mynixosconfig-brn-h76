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
    #
    # disko.nixosModules.disko НЕ включён здесь глобально — он подключается
    # через extraModules только для honor-хоста. nixos-vm не использует disko.
    mkHost = { hostName, extraModules ? [], localDevicePaths ? {} }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs hostName user userName;
        } // localDevicePaths;
        modules = [
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
          echo "usage: install-honor-magicbook <ssh-target>" >&2
          exit 1
        fi

        REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
        cd "$REPO_ROOT"

        ${fetchTargetDevicePaths}/bin/fetch-target-device-paths "$HOST" "${honorLocalDevicePathsRel}"

        nix --extra-experimental-features "nix-command flakes" run github:nix-community/nixos-anywhere -- \
          --flake .#${honorHostName} \
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

    nixosConfigurations = {
      # Основной хост — Honor MagicBook X16 Pro BRN-H76
      ${honorHostName} = mkHost {
        hostName = honorHostName;
        localDevicePaths = honorLocalDevicePaths;
        # disko подключается только здесь: VM его не видит и не падает на diskDevice missing
        extraModules = [ disko.nixosModules.disko ];
      };

      # VM для тестирования установки и конфига без физического железа.
      # Использует те же модули, но с machine.isVm = true —
      # отключает AMD/Huawei-специфику, howdy, gl passthrough, s2idle.
      # Запуск: nixos-rebuild switch --flake .#nixos-vm
      nixos-vm = mkHost {
        hostName = "nixos-vm";
      };
    };
  };
}
