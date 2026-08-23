{ lib, config, ... }:
let
  kernelModules = config.boot.kernelModules
    ++ config.boot.initrd.kernelModules
    ++ config.boot.initrd.availableKernelModules;

  hasModule = name: builtins.elem name kernelModules;

  detectedCpuVendor =
    if hasModule "kvm-amd" then "amd"
    else if hasModule "kvm-intel" then "intel"
    else "other";

  detectedIsVm =
    config.services.qemuGuest.enable
    || hasModule "virtio_pci"
    || hasModule "virtio-pci"
    || hasModule "vmw_vmci"
    || hasModule "vboxguest";

  detectedIsLaptop =
    hasModule "battery" || hasModule "ac";

  detectedGpuVendor =
    if hasModule "amdgpu" then "amd"
    else if hasModule "i915" || hasModule "xe" then "intel"
    else if hasModule "nvidia" then "nvidia"
    else "other";
in
{
  options.machine = {

    hardwareVendor = lib.mkOption {
      type = lib.types.enum [ "honor" "huawei" "other" ];
      default = "other";
      description = ''
        System manufacturer used for vendor-specific kernel modules, hwdb and
        platform services. Set this explicitly in the host configuration;
        Nix evaluation must not depend on the build machine's runtime DMI.
      '';
    };

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
