{ lib, config, ... }:
#
# Автодетект типа машины на основе данных которые nixos-generate-config
# прописывает в hardware-configuration.nix.
#
# ─── Как работает детект ────────────────────────────────────────────────────
#
#  CPU vendor:
#    nixos-generate-config читает /proc/cpuinfo и прописывает "kvm-amd" или
#    "kvm-intel" в boot.kernelModules.
#
#  GPU vendor:
#    nixos-generate-config прописывает "amdgpu", "i915" и т.д. в
#    boot.initrd.availableKernelModules если видеокарта активна при установке.
#    Если GPU подгружается автоматически через in-tree autoloading без явной
#    записи в initrd — gpuVendor свалится в "other".
#    Решение: явно добавить "amdgpu" в boot.initrd.kernelModules в hardware.nix
#    (что и сделано для Honor MagicBook).
#
#  isLaptop:
#    Детектируется по модулям аккумулятора и AC-адаптера.
#    Edge case: на некоторых ядрах battery/ac собраны как built-in (=y), а не
#    модули (=m) — тогда они не попадают в boot.kernelModules и детект даёт false.
#    Для стокового ядра NixOS это редкость. При проблеме: lib.mkForce true.
#
# ─── Переопределение ────────────────────────────────────────────────────────
#
#  Любое значение можно переопределить в хост-конфиге:
#    machine.isLaptop   = lib.mkForce true;
#    machine.cpuVendor  = lib.mkForce "amd";
#    machine.gpuVendor  = lib.mkForce "amd";
#
let
  # Объединяем все источники модулей — nixos-generate-config может писать в любой
  kernelModules = config.boot.kernelModules
    ++ config.boot.initrd.kernelModules
    ++ config.boot.initrd.availableKernelModules;

  hasModule = name: builtins.elem name kernelModules;

  # CPU: kvm-amd / kvm-intel прописываются nixos-generate-config из /proc/cpuinfo
  detectedCpuVendor =
    if hasModule "kvm-amd" then "amd"
    else if hasModule "kvm-intel" then "intel"
    else "other";

  # VM: QEMU-гость, VirtualBox, VMware или явный флаг из nixos build-vm
  detectedIsVm =
    config.services.qemuGuest.enable
    || hasModule "virtio_pci"
    || hasModule "virtio-pci"
    || hasModule "vmw_vmci"
    || hasModule "vboxguest";

  # Laptop: battery + ac модули.
  # Стандартные имена модулей для большинства ядер:
  #   "battery"    — ACPI Battery Driver (модуль)
  #   "ac"         — ACPI AC Adapter Driver (модуль)
  # Built-in (=y) варианты не попадают в списки модулей — детект даёт false.
  # В таком случае выставь: machine.isLaptop = lib.mkForce true;
  detectedIsLaptop =
    hasModule "battery" || hasModule "ac";

  # GPU: ищем в initrd.availableKernelModules (там пишет nixos-generate-config)
  # и в kernelModules (там пишем мы явно, например "amdgpu" в hardware.nix).
  # Если GPU грузится через in-tree autoloading без явной записи — будет "other".
  # Решение: явно добавить модуль в boot.initrd.kernelModules в hardware.nix.
  detectedGpuVendor =
    if hasModule "amdgpu" then "amd"
    else if hasModule "i915" || hasModule "xe" then "intel"
    else if hasModule "nvidia" then "nvidia"
    else "other";
in
{
  options.machine = {

    isVm = lib.mkOption {
      type = lib.types.bool;
      default = detectedIsVm;
      defaultText = lib.literalExpression "автодетект по boot.kernelModules и services.qemuGuest";
      description = ''
        true если система запускается в виртуальной машине.
        Отключает: AMD/Intel microcode, Huawei WMI, Howdy, s2idle.
        Автодетектируется. Переопредели через lib.mkForce если детект ошибается.
      '';
    };

    isLaptop = lib.mkOption {
      type = lib.types.bool;
      default = detectedIsLaptop;
      defaultText = lib.literalExpression "автодетект по battery/ac в boot.kernelModules";
      description = ''
        true для ноутбуков — включает battery charge thresholds и fn-lock.

        Автодетект может дать false если battery/ac собраны как built-in (=y)
        в ядре, а не как модули — они не попадают в boot.kernelModules.
        Для стокового ядра NixOS это редкость.
        При проблеме: machine.isLaptop = lib.mkForce true;
      '';
    };

    cpuVendor = lib.mkOption {
      type = lib.types.enum [ "amd" "intel" "other" ];
      default = detectedCpuVendor;
      defaultText = lib.literalExpression "автодетект по kvm-amd / kvm-intel в boot.kernelModules";
      description = ''
        CPU vendor.
          amd   → nixos-hardware cpu/amd, amd_pstate, kvm_amd nested, updateMicrocode
          intel → kvm_intel nested, hardware.cpu.intel.updateMicrocode
          other → ничего
        Автодетектируется из hardware-configuration.nix.
        Переопредели через lib.mkForce если нужно.
      '';
    };

    gpuVendor = lib.mkOption {
      type = lib.types.enum [ "amd" "intel" "nvidia" "other" ];
      default = detectedGpuVendor;
      defaultText = lib.literalExpression "автодетект по amdgpu/i915/xe/nvidia в kernelModules";
      description = ''
        GPU vendor.
          amd    → nixos-hardware gpu/amd, amdgpu драйвер, ROCm, OpenCL, LACT
          intel  → (будущее)
          nvidia → (будущее)
          other  → ничего

        Детектируется по наличию модуля в boot.initrd.availableKernelModules
        или boot.kernelModules. Если GPU грузится через in-tree autoloading
        без явной записи — будет "other". Решение: явно добавить модуль в
        boot.initrd.kernelModules в hardware.nix хоста.
        Переопредели через lib.mkForce если нужно.
      '';
    };

    fprint = {
      # Sentinel-опция: объявлена здесь чтобы howdy.nix и auth.nix могли
      # читать config.machine.fprint.enable независимо от того, импортирован
      # ли fprint.nix. Без этого модули падали бы с "option does not exist"
      # если fprint.nix не в imports.
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Включить fingerprint auth через fprintd.
          Для Goodix 27c6:5125 оставь false до появления upstream поддержки в libfprint.

          Sentinel-опция: объявлена в machine-type.nix чтобы howdy.nix и auth.nix
          могли читать config.machine.fprint.enable не завися от импорта fprint.nix.
        '';
      };
    };

  };
}
