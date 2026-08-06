{ lib, pkgs, inputs, ... }:
{
  imports = [
    (inputs.nixos-hardware + "/common/pc/laptop")
    (inputs.nixos-hardware + "/common/pc/ssd")
  ];

  boot = {
    initrd = {
      kernelModules = [
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
      "uvcvideo"
    ];

    kernelPackages = pkgs.linuxPackages_latest;
  };

  hardware.enableAllFirmware = true;

  services.fwupd.enable = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

}
