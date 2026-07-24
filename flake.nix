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

    # Все скрипты детекта дисков упакованы вместе — они вызывают друг друга
    # через SCRIPT_DIR="$(dirname $0)", поэтому должны лежать рядом в store.
    fetchTargetDevicePaths = pkgs.stdenv.mkDerivation {
      name = "fetch-target-device-paths";
      src = ./scripts;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      runtimeInputs = with pkgs; [ bash coreutils findutils gawk gnugrep gnused openssh util-linux ];
      installPhase = ''
        mkdir -p $out/bin $out/libexec

        # Вспомогательные скрипты — в libexec
        install -m 755 fetch-remote.sh  $out/libexec/fetch-remote.sh
        install -m 755 fetch-local.sh   $out/libexec/fetch-local.sh

        # Оркестратор — в bin с правильным PATH
        install -m 755 fetch-target-device-paths.sh $out/bin/fetch-target-device-paths
        wrapProgram $out/bin/fetch-target-device-paths \
          --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [
            bash coreutils findutils gawk gnugrep gnused openssh util-linux
          ])}
      '';
    };

    installHonorMagicbook = pkgs.stdenv.mkDerivation {
      name = "install-honor-magicbook";
      src = ./scripts;
      nativeBuildInputs = [ pkgs.makeWrapper ];
      installPhase = ''
        mkdir -p $out/bin $out/libexec

        # Вспомогательные скрипты — в libexec
        install -m 755 install-local.sh  $out/libexec/install-local.sh
        install -m 755 install-remote.sh $out/libexec/install-remote.sh

        # Подставить store-путь fetchTargetDevicePaths в оркестратор
        substitute install-system.sh $out/bin/install-honor-magicbook \
          --replace "@fetchTargetDevicePaths@" "${fetchTargetDevicePaths}"
        chmod 755 $out/bin/install-honor-magicbook
        wrapProgram $out/bin/install-honor-magicbook \
          --prefix PATH : ${pkgs.lib.makeBinPath (with pkgs; [
            bash git nix openssh
          ])}
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
