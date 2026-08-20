{ inputs, lib, hostName, ... }:
{
  imports = [
    ./hardware.nix
    "${inputs.self}/modules/nixos"
    (import "${inputs.self}/dev/development.nix").nixosModule
  ];

  machine = {
    isVm = lib.mkForce false;
    cpuVendor = lib.mkForce "amd";
    gpuVendor = lib.mkForce "amd";
    isLaptop = lib.mkForce true;
  };

  networking.hostName = hostName;
  time.timeZone = lib.mkForce "Europe/Moscow";

  services.zapret2 = {
    enable = true;
    presets = [ "youtube" "discord" "general" ];
    defaultPreset = "youtube";
    # Discord voice normally uses this high UDP range; intercepting all UDP
    # would add unnecessary NFQUEUE overhead to unrelated applications.
    firewall.ports.udp = [ "443" "50000-65535" ];
  };

  # Ollama with ROCm support
  services.ollama = {
    enable = true;
    acceleration = "rocm";
    rocmOverrideGfx = "11.0.0"; # For Radeon 780M

    environmentVariables = {
      # Enable Flash Attention (required for KV cache quantization)
      OLLAMA_FLASH_ATTENTION = "1";

      # KV cache quantization: q8_0 (balanced) or q4_0 (max memory savings)
      OLLAMA_KV_CACHE_TYPE = "q8_0";
    };
  };

  system.stateVersion = "26.05";
}
