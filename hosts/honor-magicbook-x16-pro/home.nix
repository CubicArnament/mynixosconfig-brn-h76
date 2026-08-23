{ inputs, pkgs, user, ... }:
let
  homeManager = inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  imports = [
    (import ../../dev/development.nix).homeModule
    ../../modules/home/amd/rocm.nix
    ../../modules/home/fish/fish.nix
    ../../modules/home/gnome/gnome.nix
    ../../modules/home/virtualization/virtualization.nix
    ../../modules/home/packages/user/user-pkgs.nix
  ];

  home = {
    username = user.name;
    stateVersion = user.homeStateVersion;
    inherit (user) homeDirectory sessionVariables;
  };

  programs.home-manager.enable = true;

  programs.git.enable = true;

  systemd.user.services.home-manager-expire-generations = {
    Unit.Description = "Expire old Home Manager generations";
    Service = {
      Type = "oneshot";
      ExecStart = "${homeManager}/bin/home-manager expire-generations '-14 days'";
    };
  };

  systemd.user.timers.home-manager-expire-generations = {
    Unit.Description = "Weekly Home Manager generation cleanup";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
