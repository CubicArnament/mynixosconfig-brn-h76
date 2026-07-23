# modules/nixos/power/power.nix
#
# Power management: power-profiles-daemon (PPD) как единственный менеджер профилей.
#
# Почему PPD, а не TLP для этого железа (AMD Phoenix / Ryzen 7840HS):
#   - nixos-hardware common/cpu/amd/pstate.nix выставляет amd_pstate=active (kernel >= 6.3)
#   - В EPP-режиме (amd_pstate=active) ядро управляет частотами через HWP hint.
#     PPD переключает platform_profile + EPP через D-Bus — именно так AMD рекомендует
#     управлять энергопрофилями на Phoenix/Hawk Point/Rembrandt платформах.
#   - TLP при параллельной работе перезаписывает EPP/platform_profile и конфликтует с PPD.
#   - auto-cpufreq также перезаписывает governor и EPP, несовместим с PPD+amd_pstate=active.
#   - GNOME интегрируется с PPD нативно через D-Bus: апплет батареи, GNOME Settings.

{ lib, config, ... }:
let
  # Значения для читаемых assertions — без дефиса в ключе атрибутсета
  tlpEnabled         = config.services.tlp.enable;
  autocpufreqEnabled = config.services."auto-cpufreq".enable;
in
{
  services = {
    power-profiles-daemon.enable = true;

    # Явные запреты конкурирующих демонов.
    # nixos-hardware/common/pc/laptop выставляет tlp.enable = mkDefault (!ppd.enable),
    # но mkDefault можно перебить случайным импортом — явный false надёжнее.
    tlp.enable = false;
    "auto-cpufreq".enable = false;
  };

  # Нужен чтобы NixOS применял CPU rules при resume/suspend.
  powerManagement.enable = lib.mkDefault true;

  # Assertions вычисляются после eval — рекурсии нет.
  # Если кто-то включит TLP или auto-cpufreq рядом с этим модулем,
  # сборка упадёт с понятным сообщением.
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
