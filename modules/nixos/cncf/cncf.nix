_:
{
  services.k3s = {
    enable = true;
    role = "server";
  };

  virtualisation.docker.enable = true;

  networking.firewall = {
    allowedTCPPorts = [ 6443 ];
  };
}
