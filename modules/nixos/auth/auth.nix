_:
{
  security = {
    sudo.enable = false;
    sudo-rs.enable = false;

    run0 = {
      enable = true;
      sudo-shim.enable = true;
      wheelNeedsPassword = true;
    };

    pam.services.systemd-run0 = { };
  };
}
