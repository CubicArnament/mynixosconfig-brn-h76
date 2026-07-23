{ ... }:
let
  batteryChargeStart = 60;
  batteryChargeStop = 80;
  fnLockDefault = 1;
in
{
  boot.kernelModules = [
    "amd_pstate"
  ];

  boot.kernelParams = [
    "amd_pstate=guided"
  ];

  boot.extraModprobeConfig = ''
    options kvm_amd nested=1
  '';

  powerManagement = {
    enable = true;
    cpuFreqGovernor = "schedutil";
  };

  hardware.cpu.amd.updateMicrocode = true;

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="platform", KERNEL=="huawei-wmi", TAG+="systemd", ENV{SYSTEMD_WANTS}+="huawei-wmi-apply.service"
  '';

  systemd.services.huawei-wmi-apply = {
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
