{ lib, pkgs, inputs, ... }:
{
  imports = [
    (inputs.nixos-hardware + "/common/pc/laptop")
    (inputs.nixos-hardware + "/common/pc/ssd")
    # CPU/GPU AMD imports живут в modules/nixos/amd/chipset.nix и amdgpu.nix
  ];

  boot = {
    initrd = {
      kernelModules = [
        # Явно прописываем amdgpu в initrd чтобы machine-type.nix мог
        # детектировать gpuVendor == "amd" до первой активации системы.
        # Также нужен для KMS (Plymouth) с самого старта.
        "amdgpu"
      ];
      availableKernelModules = [
        "nvme"
        "xhci_pci"
        "thunderbolt"
        "usb_storage"
        "sd_mod"
        "rtsx_pci_sdmmc"
      ];
    };

    kernelModules = [
      # The vendor does not publish the camera USB ID. uvcvideo is the generic
      # in-kernel driver for UVC webcams; Howdy remains disabled unless the
      # installer finds a stable /dev/v4l/by-id path on the physical laptop.
      "uvcvideo"
    ];

    # Всегда последнее стабильное ядро из nixpkgs-unstable.
    # На AMD Phoenix (Ryzen 7840HS) работа железа — WiFi Qualcomm, Radeon 780M,
    # suspend, аудио — прямо зависит от версии ядра, поэтому держим острие.
    kernelPackages = pkgs.linuxPackages_latest;
  };

  # Enable the full firmware set, including blobs packaged as unfree.
  # Relies on nixpkgs.config.allowUnfree = true in the host configuration.
  hardware.enableAllFirmware = true;

  services.fwupd.enable = true;
  # power-profiles-daemon управляется через modules/nixos/power/power.nix

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  # Honor MagicBook X16 Pro BRN-H76 is an AMD Phoenix laptop
  # (Ryzen 7 7840HS / Radeon 780M, Zen 4).
  # znver4 tuning is intentionally disabled by default because it forces
  # large local rebuilds and still has upstream build failures for some
  # packages on recent nixpkgs / nixos-unstable revisions.
  #
  # nix.settings.system-features = [
  #   "benchmark"
  #   "big-parallel"
  #   "gccarch-znver4"
  #   "kvm"
  #   "nixos-test"
  # ];
  #
  # nixpkgs.hostPlatform = {
  #   system = "x86_64-linux";
  #   gcc.arch = "znver4";
  #   gcc.tune = "znver4";
  # };
}
