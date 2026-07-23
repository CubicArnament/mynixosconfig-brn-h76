{ lib, config, ... }:
# Автодетект CPU vendor и VM-статуса на основе данных которые
# nixos-generate-config прописывает в hardware-configuration.nix.
#
# Как это работает:
#   - nixos-generate-config читает /proc/cpuinfo и добавляет "kvm-amd" или
#     "kvm-intel" в boot.kernelModules
#   - В VM (QEMU/VirtualBox/VMware) тех же модулей нет, зато есть virtio-*,
#     vmw_vmci и другие гостевые модули
#   - services.qemuGuest.enable = true выставляется nixos-rebuild build-vm
#     автоматически
#
# Ты можешь переопределить любое значение в хост-конфиге через lib.mkForce
# если автодетект ошибётся (редкий случай на экзотическом железе).
let
  kernelModules = config.boot.kernelModules
    ++ config.boot.initrd.kernelModules
    ++ config.boot.initrd.availableKernelModules;

  hasModule = name: builtins.elem name kernelModules;

  # CPU vendor: смотрим на kvm-amd / kvm-intel которые nixos-generate-config
  # прописывает автоматически из /proc/cpuinfo
  detectedVendor =
    if hasModule "kvm-amd" then "amd"
    else if hasModule "kvm-intel" then "intel"
    else "other";

  # VM детект: QEMU-гость, либо VirtualBox/VMware гостевые модули,
  # либо явный флаг из nixos build-vm
  detectedIsVm =
    config.services.qemuGuest.enable          # nixos build-vm / nixos-anywhere VM test
    || hasModule "virtio_pci"                  # QEMU/KVM virtio bus
    || hasModule "virtio-pci"
    || hasModule "vmw_vmci"                    # VMware
    || hasModule "vboxguest";                  # VirtualBox

  # isLaptop: battery и ac модули присутствуют на ноутбуках.
  # В VM и десктопах их обычно нет. Fallback — false (безопаснее).
  detectedIsLaptop =
    hasModule "battery"
    || hasModule "ac";
in
{
  options.machine = {
    isVm = lib.mkOption {
      type = lib.types.bool;
      # mkDefault позволяет переопределить из хост-конфига если нужно
      default = detectedIsVm;
      defaultText = lib.literalExpression "автодетект по boot.kernelModules и services.qemuGuest";
      description = ''
        true если система запускается в виртуальной машине.
        Отключает: AMD/Intel microcode, Huawei WMI, Howdy, libvirt gl=1, s2idle.
        Автодетектируется по boot.kernelModules из hardware-configuration.nix.
        Переопредели через lib.mkForce если детект ошибается.
      '';
    };

    isLaptop = lib.mkOption {
      type = lib.types.bool;
      default = detectedIsLaptop;
      defaultText = lib.literalExpression "автодетект по наличию battery/ac модулей";
      description = ''
        true для ноутбуков — включает battery charge thresholds и fn-lock.
        Автодетектируется. Переопредели через lib.mkForce если нужно.
      '';
    };

    cpuVendor = lib.mkOption {
      type = lib.types.enum [ "amd" "intel" "other" ];
      default = detectedVendor;
      defaultText = lib.literalExpression "автодетект по kvm-amd / kvm-intel в boot.kernelModules";
      description = ''
        CPU vendor. Влияет на:
          amd   → amd_pstate, kvm_amd nested=1, hardware.cpu.amd.updateMicrocode
          intel → kvm_intel nested=1, hardware.cpu.intel.updateMicrocode
          other → ничего из вышеперечисленного
        Автодетектируется из hardware-configuration.nix.
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
          Опция здесь чтобы howdy.nix мог на неё ссылаться не завися от импорта fprint.nix.
        '';
      };
    };
  };
}
