{ pkgs, lib, config, ... }:
let
  hasRootBtrfs = config.fileSystems ? "/" && config.fileSystems."/".fsType == "btrfs";
in
{
  environment.systemPackages = with pkgs; [
    btrfs-progs
    snapper
  ];

  services.btrfs.autoScrub = lib.mkIf hasRootBtrfs {
    enable = true;
    interval = "monthly";
  };

  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "1d";

    configs.root = {
      SUBVOLUME = "/";
      FSTYPE = "btrfs";
      TIMELINE_CREATE = true;
      TIMELINE_CLEANUP = true;
      TIMELINE_LIMIT_HOURLY = 8;
      TIMELINE_LIMIT_DAILY = 7;
      TIMELINE_LIMIT_WEEKLY = 4;
      TIMELINE_LIMIT_MONTHLY = 3;
      TIMELINE_LIMIT_QUARTERLY = 0;
    };
  };
}
