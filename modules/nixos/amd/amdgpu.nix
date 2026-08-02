# modules/nixos/amd/amdgpu.nix
#
# AMD Radeon 780M (gfx1103, RDNA3 iGPU на Phoenix) — системные настройки драйвера.
# Активируется только если machine.gpuVendor == "amd".
#
# Пользовательские переменные окружения (HSA_*, PYTORCH_*) — в modules/home/amd/rocm.nix.

{ pkgs, inputs, ... }:
{
  imports = [
    (inputs.nixos-hardware + "/common/gpu/amd")
  ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;

      # ROCm runtime and OpenCL ICD only. Development libraries such as
      # rocblas and hipblas are intentionally not installed.
      extraPackages = with pkgs; [
        rocmPackages.clr
        rocmPackages.clr.icd
      ];

      extraPackages32 = with pkgs; [
        driversi686Linux.mesa
      ];
    };

    amdgpu = {
      # KMS с самого старта + Plymouth без артефактов
      initrd.enable = true;

      # OpenCL через ROCm CLR
      opencl.enable = true;

      overdrive.enable = false;
    };
  };

  boot.kernelParams = [
    # Display Core — HDR и VRR на eDP/HDMI
    "amdgpu.dc=1"
  ];

  environment.variables.ROCM_PATH = "/opt/rocm";

  # Some prebuilt ROCm applications still expect this conventional runtime
  # location. Keep it limited to CLR rather than a full ROCm SDK tree.
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
