{ lib, config, ... }:
let
  cfg = config.machine;
in
{
  # iommu=pt, amdgpu.* параметры живут в modules/nixos/amd/chipset.nix.
  # kvm_amd nested и updateMicrocode — там же.

  boot.kernelParams = [
    # Убирает зависание на инициализации несуществующих legacy COM-портов
    "8250.nr_uarts=0"

  ] ++ lib.optionals (!cfg.isVm) [
    # s2idle актуален только на физическом железе
    "mem_sleep_default=s2idle"

    # Уменьшает ложные wake events от EC во время s2idle
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
