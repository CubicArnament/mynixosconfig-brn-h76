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
  };

  outputs = inputs@{ nixpkgs, disko, home-manager, ... }: let
    system = "x86_64-linux";
    hostName = "honor-magicbook-x16-pro";
    # Подправь под свой Linux-username, если нужен другой.
    userName = "wkubearnament";
  in {
    nixosConfigurations.${hostName} = nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit inputs hostName userName;
      };

      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        ./hosts/${hostName}/configuration.nix
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs = {
            inherit inputs hostName userName;
          };
          home-manager.users.${userName} = import ./hosts/${hostName}/home.nix;
        }
      ];
    };
  };
}
