# modules/home/amd/rocm.nix
#
# Home-Manager: пользовательские настройки ROCm/HSA для Radeon 780M (gfx1103).
#
# Системные настройки (драйвер, OpenCL, /opt/rocm) — в modules/nixos/amd/amdgpu.nix.
# Здесь: переменные сессии для AI/compute задач и диагностические пакеты.

{ pkgs, ... }:
{
  home.sessionVariables = {
    # --- Идентификация GPU для ROCm ---

    # 780M (gfx1103) не в официальном списке ROCm. Маскируем под gfx1100 (RX 7900).
    # Без этого: hipErrorNoBinaryForGpu при запуске PyTorch/llama.cpp ROCm backend.
    HSA_OVERRIDE_GFX_VERSION = "11.0.0";

    # Путь к ROCm runtime — нужен программам с захардкоженными путями
    ROCM_PATH = "/opt/rocm";

    # --- Стабильность на APU Phoenix ---

    # Отключить SDMA (DMA-движок APU).
    # При выходе за пределы выделенного VRAM в GTT SDMA вызывает AMDGPU Reset.
    # С HSA_ENABLE_SDMA=0 тензоры пересылаются через CPU — медленнее, но без крашей.
    HSA_ENABLE_SDMA = "0";

    # XNACK: GPU обрабатывает page fault самостоятельно вместо сброса.
    # В связке с amdgpu.noretry=0 даёт настоящую Unified Memory —
    # GPU обращается к произвольным CPU-страницам по требованию без предварительного копирования.
    # Требует поддержки архитектуры: на Phoenix/RDNA3 iGPU работает.
    HSA_XNACK = "1";

    # --- Динамическое выделение памяти в PyTorch ---

    # Вместо резервирования больших блоков PyTorch запрашивает память мелкими
    # виртуальными фрагментами — предотвращает OOM без постоянного удержания GTT.
    PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";

    # --- Vulkan / llama.cpp ---

    # RADV быстрее AMDVLK для Vulkan-inference (llama.cpp --vulkan)
    AMD_VULKAN_ICD = "RADV";

    # llama.cpp Vulkan backend: явно выбрать GPU 0
    GGML_VK_VISIBLE_DEVICES = "0";
  };

  home.packages = with pkgs; [
    clinfo           # диагностика OpenCL
    vulkan-tools     # vulkaninfo — проверить RADV/Vulkan
    rocmPackages.rocminfo  # показывает HSA агентов и таргет GPU
    rocmPackages.rocm-smi  # мониторинг iGPU: частота, температура, использование памяти
  ];
}
