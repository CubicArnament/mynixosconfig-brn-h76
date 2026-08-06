_:
{
  security = {
    sudo.enable = false;
    sudo-rs.enable = false;

    run0 = {
      enable = true;
      enableSudoAlias = true;
      wheelNeedsPassword = true;
    };

    polkit.enable = true;

    pam.services = {
      systemd-run0 = {};
    };
  };
}
