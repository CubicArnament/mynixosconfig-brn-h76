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

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.7.0";

    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flclashx = {
      url = "github:CubicArnament/FlClashX-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zapret2-nix = {
      url = "github:ZenonEl/zapret2-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, disko, home-manager, nix-flatpak, zapret2-nix, ... }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    user = import ./hosts/honor-magicbook-x16-pro/user.nix { inherit pkgs; };
    userName = user.name;
    honorHostName = "honor-magicbook-x16-pro";
    homeProfile = "${userName}@${honorHostName}";
    homePkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    homeSpecialArgs = {
      inherit inputs user userName;
      hostName = honorHostName;
      cameraDevicePath = "";
    };

    mkHost = { hostName, extraModules ? [], localDevicePaths ? {} }:
      let
        sharedArgs = {
          inherit inputs hostName user userName;
          cameraDevicePath = "";
        } // localDevicePaths;
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

    honorLocalDevicePathsFile = ./local-device-paths.nix;
    honorLocalDevicePaths =
      if builtins.pathExists honorLocalDevicePathsFile
      then import honorLocalDevicePathsFile
      else null;
    honorHpasswdFile = ./env.hpasswd;
    honorHpasswd =
      if builtins.pathExists honorHpasswdFile
      then nixpkgs.lib.removeSuffix "\n" (builtins.readFile honorHpasswdFile)
      else "";
    honorHpasswdValid = builtins.match "\\$(y|6)\\$.*" honorHpasswd != null;
    installationReady =
      honorLocalDevicePaths != null && honorHpasswdValid;

    fetchTargetDevicePaths = pkgs.callPackage ./trustedinstaller/remote/drv.nix { };
    installHonorMagicbook  = pkgs.callPackage ./trustedinstaller/orchestrator-drv.nix { };
    genHpasswd = pkgs.callPackage ./trustedinstaller/gen-hpasswd-drv.nix {
      inherit (pkgs) mkpasswd;
    };
    happ = pkgs.callPackage ./dev/maintaining/happ.nix { };
    nixHlp = pkgs.callPackage ./trustedinstaller/scripts/nixos-helper.d/drv.nix {
      commandScripts = ./trustedinstaller/scripts/nixos-helper.d/commands;
      formatter = treefmtEval.config.build.wrapper;
      homeManager = home-manager.packages.${system}.default;
      hostName = honorHostName;
      inherit homeProfile;
      templateScripts = ./trustedinstaller/scripts/nixos-helper.d/templates;
    };

    treefmtEval = inputs.treefmt-nix.lib.evalModule pkgs ./dev/treefmt.nix;

  in {
    formatter.${system} = treefmtEval.config.build.wrapper;

    packages.${system} = {
      inherit fetchTargetDevicePaths installHonorMagicbook genHpasswd happ nixHlp;
      fetch-target-device-paths = fetchTargetDevicePaths;
      install-honor-magicbook = installHonorMagicbook;
      gen-hpasswd = genHpasswd;
      nix-hlp = nixHlp;
      default = installHonorMagicbook;
    };

    checks.${system} = {
      inherit fetchTargetDevicePaths installHonorMagicbook genHpasswd happ nixHlp;
      home = self.homeConfigurations.${homeProfile}.activationPackage;
    };

    homeConfigurations.${homeProfile} = home-manager.lib.homeManagerConfiguration {
      pkgs = homePkgs;
      extraSpecialArgs = homeSpecialArgs;
      modules = [ ./hosts/${honorHostName}/home.nix ];
    };

    apps.${system} = {
      fetch-target-device-paths = {
        type = "app";
        program = "${fetchTargetDevicePaths}/bin/fetch-target-device-paths";
        meta.description = "Detect target disk and camera paths for installation";
      };
      gen-hpasswd = {
        type = "app";
        program = "${genHpasswd}/bin/gen-hpasswd";
        meta.description = "Generate initial hashed password for installation";
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
      default = self.apps.${system}.install-honor-magicbook // {
        meta.description = "Install NixOS on an Honor MagicBook X16 Pro";
      };
    };

    nixosConfigurations = nixpkgs.lib.optionalAttrs installationReady {
      ${honorHostName} = mkHost {
        hostName = honorHostName;
        localDevicePaths = if honorLocalDevicePaths == null then {} else honorLocalDevicePaths;
        extraModules = [
          disko.nixosModules.disko
          ./modules/nixos/disko/disko.nix
        ];
      };
    };
  };
}
