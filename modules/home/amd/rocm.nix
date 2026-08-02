# modules/home/amd/rocm.nix
#
# Home-Manager: пользовательские настройки ROCm/HSA для Radeon 780M (gfx1103).
#
# Системные настройки драйвера и OpenCL runtime — в modules/nixos/amd/amdgpu.nix.
# Здесь compatibility variables для запуска готовых ROCm workloads.

{ pkgs, ... }:
{
  home.sessionVariables = {
    # --- Идентификация GPU для ROCm ---

    # 780M (gfx1103) не в официальном списке ROCm. Маскируем под gfx1100 (RX 7900).
    # Без этого: hipErrorNoBinaryForGpu при запуске PyTorch/llama.cpp ROCm backend.
    HSA_OVERRIDE_GFX_VERSION = "11.0.0";

    ROCM_PATH = "/opt/rocm";

    # --- Стабильность на APU Phoenix ---

    # Отключить SDMA (DMA-движок APU).
    # При выходе за пределы выделенного VRAM в GTT SDMA вызывает AMDGPU Reset.
    # С HSA_ENABLE_SDMA=0 тензоры пересылаются через CPU — медленнее, но без крашей.
    HSA_ENABLE_SDMA = "0";

    # Allow the Phoenix iGPU to resolve memory faults through XNACK.
    HSA_XNACK = "1";

    # Avoid monolithic allocation reservations in prebuilt PyTorch ROCm wheels.
    PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";

    # RADV is the Mesa Vulkan implementation for the Radeon 780M.
    AMD_VULKAN_ICD = "RADV";

    GGML_VK_VISIBLE_DEVICES = "0";
  };

  home.packages = with pkgs; [
    clinfo           # диагностика OpenCL
    vulkan-tools     # vulkaninfo — проверить RADV/Vulkan
    rocmPackages.rocminfo  # показывает HSA агентов и таргет GPU
    rocmPackages.rocm-smi  # мониторинг iGPU: частота, температура, использование памяти
  ];
}
