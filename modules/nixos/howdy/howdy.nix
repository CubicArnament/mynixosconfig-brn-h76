{ cameraDevicePath ? "/dev/video0", ... }:
{
  security.pam = {
    # Keep password fallback everywhere and allow face auth as an alternative.
    howdy = {
      enable = true;
      control = "sufficient";
    };

    services = {
      # Face auth for run0. Password remains available as fallback.
      systemd-run0 = {
        howdy.enable = true;
        howdy.control = "sufficient";
      };

      # Face auth for GDM/login. Password remains available as fallback.
      login = {
        howdy.enable = true;
        howdy.control = "sufficient";
      };

      # Face auth for GUI privilege elevation dialogs.
      polkit-1 = {
        howdy.enable = true;
        howdy.control = "sufficient";
      };

      # Fingerprint auth intentionally disabled for this laptop.
      # The Goodix 27c6:5f10 reader in the Honor MagicBook X16 Pro is not
      # currently reliable on Linux, so we switch to webcam-based auth.
      #
      # Historical fingerprint-related lines, intentionally not enabled:
      # systemd-run0.fprintAuth = true;
      # login.fprintAuth = false;
      # polkit-1.fprintAuth = true;
      # gdm-fingerprint = { ... };
    };
  };

  services = {
    howdy = {
      enable = true;
      control = "sufficient";
      settings = {
        core = {
          abort_if_lid_closed = true;
          abort_if_ssh = true;
          detection_notice = false;
          disabled = false;
          no_confirmation = false;
          suppress_unknown = false;
          timeout_notice = true;
          use_cnn = false;
          workaround = "off";
        };

        video = {
          # Prefer a stable v4l symlink over /dev/videoN renumbering.
          # scripts/fetch-target-device-paths.sh can auto-generate
          # hosts/honor-magicbook-x16-pro/local-device-paths.nix with a
          # cameraDevicePath from /dev/v4l/by-id or /dev/v4l/by-path.
          device_path = cameraDevicePath;
          device_format = "v4l2";
          recording_plugin = "opencv";
          timeout = 4;
          certainty = 4.0;
          dark_threshold = 50;
          max_height = 320;
          frame_width = -1;
          frame_height = -1;
          device_fps = -1;
          exposure = -1;
          force_mjpeg = false;
          rotate = 0;
          warn_no_device = true;
        };

        snapshots = {
          save_failed = false;
          save_successful = false;
        };
      };
    };

    gnome.gnome-keyring.enable = true;

    # Fingerprint daemon intentionally disabled.
    # fprintd.enable = true;
  };

  # Historical fingerprint notes kept on purpose:
  #
  # - scanner USB ID on this machine: 27c6:5f10
  # - Linux support is not production-ready in mainline libfprint/fprintd
  # - because of that we do not enable any Goodix TOD driver here
  #
  # Previous fingerprint-oriented candidates, intentionally not enabled:
  # services.fprintd.tod.enable = true;
  # services.fprintd.tod.driver = pkgs.libfprint-2-tod1-goodix;
  #
  # Important caveat for face auth:
  # GNOME keyring may still ask for the password after a cold login because
  # biometric/face auth does not provide the login password to unlock it.
  # If that UX is annoying, disable `security.pam.services.login.howdy.enable`
  # and keep Howdy only for `run0` and `polkit-1`.
}
