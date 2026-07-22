{ pkgs, ... }:
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

  # Huawei/Honor hotkeys приходят через huawei_wmi.
  # Яркость/громкость/микрофон GNOME обрабатывает нативно, а эти hwdb
  # mappings страхуют дополнительные Honor-специфичные клавиши до тех пор,
  # пока конкретная ревизия ноутбука не совпадёт с in-tree keymap ядра.
  services.udev.extraHwdb = ''
    evdev:name:Huawei WMI hotkeys:*
      KEYBOARD_KEY_0288=camera
      KEYBOARD_KEY_028b=notification-center
      KEYBOARD_KEY_028e=printscreen
  '';

  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="input", ATTRS{name}=="Huawei WMI hotkeys", ENV{ID_INPUT}="1", ENV{ID_INPUT_KEYBOARD}="1"
  '';
}
