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
#
# Поведение по сценариям:
#   ┌─────────────────┬──────────┬────────────────────────────────────────────────┐
#   │ Сценарий        │ PPD      │ Примечание                                     │
#   ├─────────────────┼──────────┼────────────────────────────────────────────────┤
#   │ Ноутбук (физ.)  │ включён  │ Полная интеграция с GNOME + батарейные профили │
#   │ Десктоп (физ.)  │ включён  │ EPP управление через PPD, батарея не нужна     │
#   │ VM              │ выключен │ Нет реального железа, PPD бесполезен           │
#   └─────────────────┴──────────┴────────────────────────────────────────────────┘
#
# machine.isVm и machine.isLaptop автодетектируются в modules/nixos/meta/machine-type.nix.
# Переопредели через lib.mkForce в хост-конфиге если детект ошибётся.

{ lib, config, ... }:
let
  cfg = config.machine;

  # PPD полезен на любом физическом железе с AMD/Intel pstate:
  # - ноутбук: управляет профилями + интегрируется с GNOME battery widget
  # - десктоп: управляет EPP/platform_profile даже без батареи
  # - VM: реального железа нет, PPD не найдёт ни platform_profile, ни драйверов
  enablePpd = !cfg.isVm;
in
{
  # ─── power-profiles-daemon ────────────────────────────────────────────────
  services.power-profiles-daemon.enable = enablePpd;

  # ─── Явные запреты конкурирующих демонов ─────────────────────────────────
  # Запрет абсолютный — не зависит от isVm/isLaptop.
  # На VM TLP/autocpufreq тоже не нужны (и вредны: мешают тестированию конфига).
  #
  # nixos-hardware/common/pc/laptop выставляет services.tlp.enable = mkDefault (!ppd.enable),
  # но mkDefault можно перебить случайным импортом. Явный false надёжнее.
  services.tlp.enable = false;
  services.auto-cpufreq.enable = false;

  # ─── Безопасный powerManagement для десктопа и VM ────────────────────────
  # powerManagement.enable = true нужен чтобы NixOS применял CPU rules при resume.
  # На VM resume обрабатывается гипервизором — включать не нужно.
  # На десктопе без батареи suspend редок, но harmless — оставляем.
  powerManagement.enable = lib.mkDefault (!cfg.isVm);

  # ─── NixOS assertions: защита от случайных конфликтов ────────────────────
  # Работают на любом хосте — ноутбук, десктоп, VM.
  # Если кто-то включит TLP или autocpufreq рядом с этим модулем, сборка упадёт
  # с понятным сообщением вместо тихой поломки управления питанием.
  assertions = [
    {
      assertion = !config.services.tlp.enable;
      message = ''
        power.nix: services.tlp.enable = true конфликтует с power-profiles-daemon.
        На AMD Phoenix (amd_pstate=active) это вызывает гонку EPP/platform_profile.
        Отключи TLP или удали импорт modules/nixos/power/power.nix.
      '';
    }
    {
      assertion = !config.services.auto-cpufreq.enable;
      message = ''
        power.nix: services.auto-cpufreq.enable = true конфликтует с power-profiles-daemon.
        auto-cpufreq перезаписывает governor и EPP, несовместим с amd_pstate=active + PPD.
        Отключи auto-cpufreq или удали импорт modules/nixos/power/power.nix.
      '';
    }
  ];
}
