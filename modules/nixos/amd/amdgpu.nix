
{ pkgs, inputs, ... }:
{
  imports = [
    (inputs.nixos-hardware + "/common/gpu/amd")
  ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        rocmPackages.clr
        rocmPackages.clr.icd
      ];

      extraPackages32 = with pkgs; [
        driversi686Linux.mesa
      ];
    };

    amdgpu = {
      initrd.enable = true;

      opencl.enable = true;

      overdrive.enable = false;
    };
  };

  boot.kernelParams = [
    "amdgpu.dc=1"
  ];

  environment.variables.ROCM_PATH = "/opt/rocm";

  systemd.tmpfiles.rules =
    let
      rocmRuntime = pkgs.symlinkJoin {
        name = "rocm-runtime";
        paths = [ pkgs.rocmPackages.clr ];
      };
    in [
      "L+ /opt/rocm - - - - ${rocmRuntime}"
      "L+ /opt/amdgpu/share/libdrm/amdgpu.ids - - - - ${pkgs.libdrm}/share/libdrm/amdgpu.ids"
    ];

}
