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

      NUMBER_CLEANUP = true;
      NUMBER_MIN_AGE = 1800;
      NUMBER_LIMIT = 10;
      NUMBER_LIMIT_IMPORTANT = 5;

      EMPTY_PRE_POST_CLEANUP = true;
      EMPTY_PRE_POST_MIN_AGE = 1800;
    };
  };
}
