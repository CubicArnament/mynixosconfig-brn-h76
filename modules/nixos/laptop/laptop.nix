{ lib, config, ... }:
let
  cfg = config.machine;
  batteryChargeStart = 60;
  batteryChargeStop = 80;
  fnLockDefault = 1;
in
{
  # powerManagement живёт в modules/nixos/power/power.nix.
  # AMD/Intel CPU-специфика (kvm_amd nested, updateMicrocode) — в modules/nixos/amd/chipset.nix.
  # cpuFreqGovernor намеренно не выставляется: при amd_pstate=active PPD управляет
  # EPP/platform_profile напрямую — governor не нужен и конфликтует с ним.

  # Intel nested KVM — AMD вариант живёт в chipset.nix
  boot.extraModprobeConfig = lib.mkIf (!cfg.isVm && cfg.cpuVendor == "intel") ''
    options kvm_intel nested=1
  '';

  hardware.cpu.intel.updateMicrocode = lib.mkIf (!cfg.isVm && cfg.cpuVendor == "intel") true;

  # Huawei WMI: battery charge thresholds + fn-lock
  services.udev.extraRules = lib.mkIf (!cfg.isVm && cfg.isLaptop) ''
    ACTION=="add", SUBSYSTEM=="platform", KERNEL=="huawei-wmi", TAG+="systemd", ENV{SYSTEMD_WANTS}+="huawei-wmi-apply.service"
  '';

  systemd.services.huawei-wmi-apply = lib.mkIf (!cfg.isVm && cfg.isLaptop) {
    description = "Apply Honor Huawei WMI battery and Fn-lock settings";
    wants = [ "systemd-udev-settle.service" ];
    after = [ "systemd-udev-settle.service" ];
    unitConfig.ConditionPathExists = "/sys/devices/platform/huawei-wmi";
    serviceConfig.Type = "oneshot";
    script = ''
      set -eu

      hwmidir=/sys/devices/platform/huawei-wmi
      batdir=/sys/class/power_supply/BAT0

      for _ in $(seq 1 20); do
        if [ -e "$hwmidir/charge_control_thresholds" ] || [ -e "$batdir/charge_control_start_threshold" ]; then
          break
        fi
        sleep 1
      done

      if [ -w "$hwmidir/charge_control_thresholds" ]; then
        printf '%s %s\n' ${toString batteryChargeStart} ${toString batteryChargeStop} > "$hwmidir/charge_control_thresholds"
      elif [ -w "$batdir/charge_control_start_threshold" ] && [ -w "$batdir/charge_control_end_threshold" ]; then
        printf '%s\n' ${toString batteryChargeStart} > "$batdir/charge_control_start_threshold"
        printf '%s\n' ${toString batteryChargeStop} > "$batdir/charge_control_end_threshold"
      fi

      if [ -w "$hwmidir/fn_lock_state" ]; then
        printf '%s\n' ${toString fnLockDefault} > "$hwmidir/fn_lock_state"
      fi
    '';
  };
}
