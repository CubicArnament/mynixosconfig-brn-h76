# modules/nixos/power/power.nix
#
# Power management: power-profiles-daemon (PPD) как единственный менеджер профилей.
#
# Почему PPD, а не TLP для этого железа (AMD Phoenix / Ryzen 7840HS):
#   - nixos-hardware common/cpu/amd/pstate.nix выставляет amd_pstate=active (kernel >= 6.3)
#   - В EPP-режиме (amd_pstate=active) ядро управляет частотами через HWP hint.
#     PPD переключает platform_profile + EPP через D-Bus — именно так AMD рекомендует
#     управлять энергопрофилями на Phoenix/Hawk Point/Rembrandt платформах.
#   - TLP при параллельной работе перезаписывает EPP/platform_profile и конфликтует с PPD:
#     "something is going to stomp on the other and you'll get unexpected results"
#     (Mario Limonciello, AMD, https://community.frame.work/t/tracking-ppd-v-tlp-for-amd-ryzen-7040/39423/9)
#   - auto-cpufreq также перезаписывает governor и EPP, несовместим с PPD+amd_pstate=active.
#   - GNOME интегрируется с PPD нативно через D-Bus: апплет батареи, GNOME Settings.
#
# nixos-hardware common/pc/laptop выставляет services.tlp.enable = mkDefault (!ppd.enable),
# т.е. при ppd.enable=true TLP выключается автоматически. Здесь мы дополнительно
# явно отключаем оба конкурента для защиты от будущих изменений.

{ lib, config, ... }:
let
  cfg = config.machine;
in
{
  # ─── power-profiles-daemon ────────────────────────────────────────────────
  # Единственный менеджер профилей на этом хосте.
  # На VM PPD бесполезен (нет реального железа), оставляем только для физического хоста.
  services.power-profiles-daemon.enable = lib.mkIf (!cfg.isVm) true;

  # ─── Явные запреты конкурирующих демонов ─────────────────────────────────
  # TLP
  # nixos-hardware/common/pc/laptop уже выставляет mkDefault false при ppd.enable=true,
  # но явный false здесь гарантирует корректность независимо от порядка импортов.
  services.tlp.enable = false;

  # auto-cpufreq опасен для батареи Honor MagicBook в связке с amd_pstate=active:
  # он форсирует governor и EPP, ломая управление профилями через PPD.
  # Не включаем ни при каких условиях.
  services.auto-cpufreq.enable = false;

  # ─── NixOS assertion: гарантия отсутствия конфликта ──────────────────────
  # Если кто-то случайно включит TLP или autocpufreq — сборка упадёт с понятным сообщением.
  assertions = [
    {
      assertion = !config.services.tlp.enable;
      message = ''
        power.nix: services.tlp.enable = true конфликтует с power-profiles-daemon.
        На AMD Phoenix (amd_pstate=active) это вызывает гонку EPP/platform_profile.
        Отключи TLP или удали импорт power.nix.
      '';
    }
    {
      assertion = !config.services.auto-cpufreq.enable;
      message = ''
        power.nix: services.auto-cpufreq.enable = true конфликтует с power-profiles-daemon.
        auto-cpufreq перезаписывает governor и EPP, несовместим с amd_pstate=active + PPD.
        Отключи auto-cpufreq или удали импорт power.nix.
      '';
    }
  ];
}
