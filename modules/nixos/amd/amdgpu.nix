# modules/nixos/amd/amdgpu.nix
#
# AMD Radeon 780M (gfx1103, RDNA3 iGPU на Phoenix) — системные настройки драйвера.
# Активируется только если machine.gpuVendor == "amd".
#
# Пользовательские переменные окружения (HSA_*, PYTORCH_*) — в modules/home/amd/rocm.nix.

{ lib, pkgs, inputs, ... }:
{
  imports = [
    (inputs.nixos-hardware + "/common/gpu/amd")
  ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        # ROCm CLR — OpenCL + HIP runtime для 780M
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

      # Overdrive — разблокирует sysfs-интерфейс частот/напряжений для LACT
      overdrive.enable = true;
    };
  };

  boot.kernelParams = [
    # Display Core — HDR и VRR на eDP/HDMI
    "amdgpu.dc=1"
  ];

  environment.variables = {
    # RADV (Mesa) быстрее AMDVLK для gaming и rendering
    AMD_VULKAN_ICD = "RADV";

    # gfx1103 (780M) официально не поддерживается ROCm.
    # 11.0.0 = gfx1100 (RX 7900) — ближайший поддерживаемый таргет RDNA3.
    HSA_OVERRIDE_GFX_VERSION = "11.0.0";

    # /opt/rocm нужен программам с захардкоженными путями к HIP/ROCm
    ROCM_PATH = "/opt/rocm";
  };

  # /opt/rocm симлинк — нужен PyTorch, llama.cpp ROCm backend и др.
  systemd.tmpfiles.rules = (
    let
      rocmEnv = pkgs.symlinkJoin {
        name = "rocm-combined";
        paths = with pkgs.rocmPackages; [ rocblas hipblas clr ];
      };
    in [
      "L+ /opt/rocm - - - - ${rocmEnv}"
      "L+ /opt/amdgpu/share/libdrm/amdgpu.ids - - - - ${pkgs.libdrm}/share/libdrm/amdgpu.ids"
    ]
  );

  # LACT — GUI управление частотами, напряжением, кривой вентилятора
  services.lact.enable = true;
}
