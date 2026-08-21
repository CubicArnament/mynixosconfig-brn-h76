
{ inputs, ... }:
{
  imports = [
    (inputs.nixos-hardware + "/common/cpu/amd")
    (inputs.nixos-hardware + "/common/cpu/amd/pstate.nix")
  ];

  boot = {
    kernelModules = [
      "kvm-amd"
      "msr"
    ];

    kernelParams = [
      "amdgpu.noretry=0"

      "iommu=pt"
    ];

    extraModprobeConfig = ''
      options kvm_amd nested=1
    '';
  };

  hardware.cpu.amd.updateMicrocode = true;
}
