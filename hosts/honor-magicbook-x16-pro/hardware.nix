{ lib, pkgs, inputs, ... }:
{
  imports = [
    (inputs.nixos-hardware + "/common/cpu/amd")
    (inputs.nixos-hardware + "/common/cpu/amd/pstate.nix")
    (inputs.nixos-hardware + "/common/gpu/amd")
    (inputs.nixos-hardware + "/common/pc/laptop")
    (inputs.nixos-hardware + "/common/pc/ssd")
  ];

  boot.initrd.availableKernelModules = [
    "nvme"
    "xhci_pci"
    "thunderbolt"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];

  # Integrated webcam on this Honor platform is expected to work via the
  # standard in-kernel UVC stack rather than an OEM out-of-tree driver.
  # Keeping uvcvideo explicit here makes the intent clear for Howdy/webcam auth.
  boot.kernelModules = [
    "kvm-amd"
    "uvcvideo"
  ];
  # Всегда последнее стабильное ядро из nixpkgs-unstable.
  # На AMD Phoenix (Ryzen 7840HS) работа железа — WiFi Qualcomm, Radeon 780M,
  # suspend, аудио — прямо зависит от версии ядра, поэтому держим острие.
  # Сейчас: linux_latest → 7.1.x. При выходе 7.2 обновится автоматически с flake update.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Enable the full firmware set, including blobs packaged as unfree.
  # This goes beyond only redistributable firmware and relies on
  # nixpkgs.config.allowUnfree = true in the host configuration.
  hardware.enableAllFirmware = true;
  services.fwupd.enable = true;
  # services.power-profiles-daemon управляется через modules/nixos/power/power.nix

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
