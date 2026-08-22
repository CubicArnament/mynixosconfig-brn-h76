{ lib, config, ... }:
let
  cfg = config.machine;
in
{

  boot.kernelParams = [
    "8250.nr_uarts=4"
    "8250_core.nr_uarts=4"

  ] ++ lib.optionals (!cfg.isVm) [
    "mem_sleep_default=s2idle"

    "acpi.ec_no_wakeup=1"
  ];

  boot.extraModprobeConfig = lib.mkIf (!cfg.isVm) ''
    options huawei_wmi report_brightness=1
  '';

  systemd.sleep.settings.Sleep = lib.mkIf (!cfg.isVm) {
    AllowSuspend = true;
    AllowHibernation = false;
    AllowSuspendThenHibernate = false;
    AllowHybridSleep = false;
    SuspendState = "mem";
    MemorySleepMode = "s2idle";
  };
}
