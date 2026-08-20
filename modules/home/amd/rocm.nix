{ pkgs, config, ... }:
{
  home.sessionVariables = {
    HSA_OVERRIDE_GFX_VERSION = "11.0.0";

    ROCM_PATH = "/opt/rocm";

    HSA_ENABLE_SDMA = "0";

    HSA_XNACK = "1";

    PYTORCH_CUDA_ALLOC_CONF = "expandable_segments:True";

    AMD_VULKAN_ICD = "RADV";

    GGML_VK_VISIBLE_DEVICES = "0";

    # Ollama optimizations
    OLLAMA_FLASH_ATTENTION = "1";
    OLLAMA_KV_CACHE_TYPE = "q8_0";
  };

  home.packages = with pkgs; [
    clinfo
    vulkan-tools
    rocmPackages.rocminfo
    rocmPackages.rocm-smi
    ollama
  ];
}
