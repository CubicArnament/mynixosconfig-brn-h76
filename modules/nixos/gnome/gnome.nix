{ pkgs, lib, config, ... }:
let
  cfg = config.machine;
in
{
  services.xserver.enable = true;
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

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
    gnomeExtensions.user-themes
    gnomeExtensions.touchpad-gesture-customization
  ];

  # Huawei/Honor hotkeys — только на физическом Honor/Huawei железе.
  # В VM huawei_wmi не загрузится, но лишний hwdb/udev мусор ни к чему.
  services.udev.extraHwdb = lib.mkIf (!cfg.isVm) ''
    evdev:name:Huawei WMI hotkeys:*
      KEYBOARD_KEY_0288=camera
      KEYBOARD_KEY_028b=notification-center
      KEYBOARD_KEY_028e=printscreen
  '';

  services.udev.extraRules = lib.mkIf (!cfg.isVm) ''
    ACTION=="add|change", SUBSYSTEM=="input", ATTRS{name}=="Huawei WMI hotkeys", ENV{ID_INPUT}="1", ENV{ID_INPUT_KEYBOARD}="1"
  '';
}
