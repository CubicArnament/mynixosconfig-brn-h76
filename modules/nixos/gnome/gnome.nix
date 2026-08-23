{ pkgs, lib, config, isInstaller ? false, ... }:
let
  cfg = config.machine;
  isHuaweiFamily = builtins.elem cfg.hardwareVendor [ "honor" "huawei" ];
in
lib.mkIf (!isInstaller) {
  services = {
    xserver = {
      enable = true;
    };
    displayManager = {
      gdm.enable = true;
    };
    desktopManager = {
      gnome.enable = true;
    };

    udev = lib.mkIf (!cfg.isVm && isHuaweiFamily) {
      extraHwdb = ''
        evdev:name:Huawei WMI hotkeys:*
          KEYBOARD_KEY_0288=camera
          KEYBOARD_KEY_028b=notification-center
          KEYBOARD_KEY_028e=printscreen
      '';

      extraRules = ''
        ACTION=="add|change", SUBSYSTEM=="input", ATTRS{name}=="Huawei WMI hotkeys", ENV{ID_INPUT}="1", ENV{ID_INPUT_KEYBOARD}="1"
      '';
    };
  };

  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    gnome-tweaks
    gnomeExtensions.appindicator
    gnomeExtensions.blur-my-shell
    gnomeExtensions.caffeine
    gnomeExtensions.clipboard-indicator
    gnomeExtensions.dash-to-dock
    gnomeExtensions.just-perfection
    gnomeExtensions.vitals
  ];
}
