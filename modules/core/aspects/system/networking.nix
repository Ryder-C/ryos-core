{
  ry.networking.nixos = {
    lib,
    pkgs,
    ...
  }: {
    environment.systemPackages = with pkgs; [inetutils wireguard-tools];

    networking = {
      networkmanager = {
        enable = true;
        dns = "systemd-resolved";
      };
      firewall.enable = true;
    };
    services.resolved.enable = true;

    # Make network-online.target wait for NetworkManager connectivity, and
    # drop the networkd one that would otherwise time out.
    systemd.services = {
      NetworkManager-wait-online.enable = true;
      systemd-networkd-wait-online.enable = lib.mkForce false;
    };
  };
}
