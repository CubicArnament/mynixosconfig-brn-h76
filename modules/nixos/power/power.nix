
{ lib, config, ... }:
let
  tlpEnabled         = config.services.tlp.enable;
  autocpufreqEnabled = config.services."auto-cpufreq".enable;
in
{
  services = {
    power-profiles-daemon.enable = true;

    tlp.enable = false;
    "auto-cpufreq".enable = false;
  };

  powerManagement.enable = lib.mkDefault true;

  assertions = [
    {
      assertion = !tlpEnabled;
      message =
        "power.nix: TLP включён параллельно с power-profiles-daemon. "
        + "На AMD Phoenix (amd_pstate=active) это вызывает гонку EPP/platform_profile. "
        + "Выставь tlp.enable = false или удали импорт modules/nixos/power/power.nix.";
    }
    {
      assertion = !autocpufreqEnabled;
      message =
        "power.nix: auto-cpufreq включён параллельно с power-profiles-daemon. "
        + "auto-cpufreq перезаписывает governor и EPP, несовместим с amd_pstate=active + PPD. "
        + "Выставь auto-cpufreq.enable = false или удали импорт modules/nixos/power/power.nix.";
    }
  ];
}
