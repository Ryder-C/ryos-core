{
  # Needs the `vaultwarden` secret (environment file with ADMIN_TOKEN etc.).
  ry.vaultwarden = {
    nixos = {secretFile, ...}: {
      services.vaultwarden = {
        enable = true;
        environmentFile = secretFile "vaultwarden";
        config = {
          ROCKET_ADDRESS = "0.0.0.0";
          ROCKET_PORT = 8222;
          DOMAIN = "https://vault.ryder.rs";
          SIGNUPS_ALLOWED = false;
          INVITATIONS_ALLOWED = true;
          SHOW_PASSWORD_HINT = false;
        };
      };
    };

    vhost = {
      domain = "ryder.rs";
      sub = "vault";
      port = 8222;
      # The admin panel is LAN-only.
      extraConfig = ''
        @adminRemote {
          path /admin*
          not remote_ip private_ranges
        }
        respond @adminRemote 403
      '';
    };

    homepage = {
      group = "Security";
      name = "Vaultwarden";
      href = "https://vault.ryder.rs";
      icon = "vaultwarden";
    };
  };
}
