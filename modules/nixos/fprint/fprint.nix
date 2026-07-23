{ lib, config, pkgs, ... }:
# Fingerprint auth через fprintd + mainline libfprint.
#
# Статус Goodix 27c6:5125 (Honor MagicBook X16 Pro BRN-H76):
#   Сенсор НЕ поддерживается в mainline libfprint на 2026-07.
#   TOD драйверы (libfprint-2-tod1-goodix, goodix-550a) предназначены для
#   древних Goodix TLS сенсоров из ноутбуков Dell/Lenovo — не подходят.
#   Внешних open-source драйверов под 27c6:5125 не существует.
#
#   Ждём upstream: когда поддержка появится в libfprint, этот модуль
#   подхватит её автоматически через обновление nixpkgs-unstable.
#   Следить за прогрессом:
#     https://gitlab.freedesktop.org/libfprint/libfprint/-/issues
#     https://gitlab.freedesktop.org/libfprint/wiki/-/wikis/Unsupported-Devices
#
# Как включить когда поддержка появится:
#   1. Раскомментировать импорт в configuration.nix
#   2. Выставить machine.fprint.enable = true в configuration.nix
#   3. После rebuild: fprintd-enroll -f right-index-finger
#
# Опция machine.fprint.enable объявлена в modules/nixos/meta/machine-type.nix,
# чтобы howdy.nix мог на неё ссылаться независимо от импорта этого файла.
let
  cfg = config.machine.fprint;
in
{
  config = lib.mkIf (cfg.enable && !config.machine.isVm) {
    services.fprintd.enable = true;

    # fprintd включает PAM глобально, но на GNOME/GDM это ломает парольный
    # fallback (upstream nixpkgs issue #171136). Отключаем глобальный
    # fprintAuth для login и используем отдельный gdm-fingerprint сервис.
    security.pam.services.login.fprintAuth = false;

    security.pam.services.gdm-fingerprint = {
      text = ''
        auth       required                    pam_shells.so
        auth       requisite                   pam_nologin.so
        auth       requisite                   pam_faillock.so      preauth
        auth       sufficient                  ${pkgs.fprintd}/lib/security/pam_fprintd.so
        auth       optional                    pam_permit.so
        auth       required                    pam_env.so
        auth       [success=ok default=1]      ${pkgs.gdm}/lib/security/pam_gdm.so
        auth       optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so

        account    include                     login

        password   required                    pam_deny.so

        session    include                     login
        session    optional                    ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
      '';
    };
  };
}
