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

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-anywhere = {
      url = "github:nix-community/nixos-anywhere";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zapret2-nix = {
      url = "github:ZenonEl/zapret2-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, disko, home-manager, nix-flatpak, nixos-anywhere, zapret2-nix, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    # Общий user для всех хостов — имя/shell/home живут в user.nix
    user = import ./hosts/honor-magicbook-x16-pro/user.nix { inherit pkgs; };
    userName = user.name;

    # Хелпер для сборки nixosConfiguration.
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
          zapret2-nix.nixosModules.default
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
    honorLocalDevicePathsFile = ./hosts/${honorHostName}/local-device-paths.nix;
    honorLocalDevicePaths =
      if builtins.pathExists honorLocalDevicePathsFile
      then import honorLocalDevicePathsFile
      else {
        diskDevice = "/dev/disk/by-id/CONFIGURE-ME-run-fetch-target-device-paths";
        cameraDevicePath = "";
      };

    # Деривации вынесены в trustedinstaller/*.nix
    fetchTargetDevicePaths = pkgs.callPackage ./trustedinstaller/remote/drv.nix { };
    installHonorMagicbook  = pkgs.callPackage ./trustedinstaller/orchestrator-drv.nix { };

  in {
    packages.${system} = {
      inherit fetchTargetDevicePaths installHonorMagicbook;
      default = installHonorMagicbook;
    };

    apps.${system} = {
      fetch-target-device-paths = {
        type = "app";
        program = "${fetchTargetDevicePaths}/bin/fetch-target-device-paths";
        meta.description = "Detect target disk and camera paths for installation";
      };
      install-honor-magicbook = {
        type = "app";
        program = "${installHonorMagicbook}/bin/install-honor-magicbook";
        meta.description = "Install NixOS on an Honor MagicBook X16 Pro";
      };
      disko-install = {
        type = "app";
        program = "${disko.packages.${system}.default}/bin/disko-install";
        meta.description = "Install NixOS with the pinned disko input";
      };
      nixos-anywhere = {
        type = "app";
        program = "${nixos-anywhere.packages.${system}.default}/bin/nixos-anywhere";
        meta.description = "Install NixOS remotely with the pinned nixos-anywhere input";
      };
      default = self.apps.${system}.install-honor-magicbook // {
        meta.description = "Install NixOS on an Honor MagicBook X16 Pro";
      };
    };

    nixosConfigurations = {
      # Honor MagicBook X16 Pro BRN-H76
      ${honorHostName} = mkHost {
        hostName = honorHostName;
        localDevicePaths = honorLocalDevicePaths;
        extraModules = [
          disko.nixosModules.disko
          ./modules/nixos/disko/disko.nix
        ];
      };
    };
  };
}
