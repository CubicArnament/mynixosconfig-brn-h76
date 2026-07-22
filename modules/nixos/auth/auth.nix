{ ... }:
{
  security = {
    sudo.enable = false;
    sudo-rs.enable = false;

    run0 = {
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
