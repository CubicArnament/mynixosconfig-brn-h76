{ ... }:
{
  security = {
    sudo.enable = false;
    sudo-rs.enable = false;

    run0 = {
      enable = true;
      # Keep classic admin gating semantics: only wheel users can elevate,
      # and elevation still requires auth. PAM/Howdy may satisfy that auth,
      # but the password prompt remains available as fallback.
      enableSudoAlias = true;
      wheelNeedsPassword = true;
    };

    polkit.enable = true;

    pam.services = {
      # Keep this service explicitly defined: on unstable it also acts as the
      # current workaround for run0 PAM/session issues.
      systemd-run0 = {};
    };
  };
}
