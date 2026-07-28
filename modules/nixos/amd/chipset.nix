# modules/nixos/amd/chipset.nix
#
# AMD Phoenix / Ryzen 7840HS — CPU, nixos-hardware imports, микрокод, KVM.
# Активируется только если machine.cpuVendor == "amd".
#
# amd-pstate=active выставляется nixos-hardware/common/cpu/amd/pstate.nix.
# Тайминги LPDDR5 из Linux изменить нельзя — только через BIOS.
# Рекомендация по BIOS: UMA Frame Buffer Size = Auto или 512MB/1GB.

{ lib, config, inputs, ... }:
let
  cfg = config.machine;
  isAmdCpu = cfg.cpuVendor == "amd";
in
{
  # imports внутри модуля вычисляются лениво — можно использовать lib.optional
  # без infinite recursion (в отличие от imports в configuration.nix)
  imports = lib.optional isAmdCpu (inputs.nixos-hardware + "/common/cpu/amd")
         ++ lib.optional isAmdCpu (inputs.nixos-hardware + "/common/cpu/amd/pstate.nix");

  boot = lib.mkIf isAmdCpu {
    kernelModules = [
      "kvm-amd"  # AMD-V виртуализация
      "msr"      # мониторинг CPU через turbostat/perf/ryzenadj
    ];

    kernelParams = [
      # HMM: GPU обрабатывает page fault вместо сброса →
      # динамическая подгрузка страниц по требованию (Unified Memory)
      "amdgpu.noretry=0"

      # IOMMU passthrough — снижает латентность DMA на APU
      "iommu=pt"
    ];

    extraModprobeConfig = lib.mkIf (!cfg.isVm) ''
      # Nested KVM для AMD
      options kvm_amd nested=1
    '';
  };

  # Микрокод AMD — обновления безопасности и исправления errata
  hardware.cpu.amd.updateMicrocode = lib.mkIf (isAmdCpu && !cfg.isVm) true;

  # ZRAM: ~8 ГБ сжатого swap в RAM.
  # На 16 ГБ LPDDR5 при ROCm/LLM нагрузках OOM-killer убивает процессы
  # раньше чем успевает освободить память — ZRAM даёт буфер без задержек диска.
  zramSwap.enable = lib.mkIf isAmdCpu true;
}
