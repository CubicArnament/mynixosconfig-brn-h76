{ lib, config, ... }:
let
  cfg = config.machine;
  batteryChargeStart = 60;
  batteryChargeStop = 80;
  fnLockDefault = 1;
in
{
  # powerManagement.enable позволяет NixOS применять правила CPU при resume/suspend.
  # cpuFreqGovernor намеренно НЕ выставляется: при amd_pstate=active (nixos-hardware/common/cpu/amd/pstate.nix,
  # ядро >= 6.3) драйвер работает в EPP-режиме (HWP hint), а power-profiles-daemon
  # управляет энергопрофилем через platform_profile / EPP напрямую.
  # Принудительный governor schedutil конфликтует с PPD и сбрасывает EPP-настройки.
  powerManagement = lib.mkIf (!cfg.isVm) {
    enable = true;
    # cpuFreqGovernor не задаём: amd_pstate=active + PPD управляют этим сами
  };

  # AMD-специфичные настройки.
  # Примечание: amd_pstate уже выставляется nixos-hardware common/cpu/amd/pstate.nix
  # (active для ядра >= 6.3), поэтому здесь только kvm_amd nested.
  boot.extraModprobeConfig = lib.mkIf (!cfg.isVm) (
    lib.optionalString (cfg.cpuVendor == "amd") ''
      options kvm_amd nested=1
    '' +
    lib.optionalString (cfg.cpuVendor == "intel") ''
      options kvm_intel nested=1
    ''
  );

  hardware.cpu.amd.updateMicrocode = lib.mkIf (!cfg.isVm && cfg.cpuVendor == "amd") true;
  hardware.cpu.intel.updateMicrocode = lib.mkIf (!cfg.isVm && cfg.cpuVendor == "intel") true;

  # Huawei WMI: battery charge thresholds + fn-lock
  # Только на физическом Huawei/Honor железе
  services.udev.extraRules = lib.mkIf (!cfg.isVm && cfg.isLaptop) ''
    ACTION=="add", SUBSYSTEM=="platform", KERNEL=="huawei-wmi", TAG+="systemd", ENV{SYSTEMD_WANTS}+="huawei-wmi-apply.service"
  '';

  systemd.services.huawei-wmi-apply = lib.mkIf (!cfg.isVm && cfg.isLaptop) {
    description = "Apply Honor Huawei WMI battery and Fn-lock settings";
    wants = [ "systemd-udev-settle.service" ];
    after = [ "systemd-udev-settle.service" ];
    # Сервис запустится только если huawei-wmi платформа реально существует
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
