{ry, ...}: {
  # Consumer of the `vhost` quirk: { domain; sub; port; extraConfig ? ""; }
  # becomes <sub>.<domain> with a Cloudflare DNS-01 certificate.
  ry.caddy = {
    includes = [ry.agenix];

    nixos = {
      vhost,
      pkgs,
      lib,
      secretFile,
      ageSecret,
      ...
    }: let
      # Variables in the cloudflare-api-token environment file.
      domainTokens = {
        "ryder.rs" = "CF_API_TOKEN_RYDER";
        "adinack.dev" = "CF_API_TOKEN_ADIN";
      };
    in {
      services.caddy = {
        enable = true;
        package = pkgs.caddy.withPlugins {
          plugins = ["github.com/caddy-dns/cloudflare@v0.2.4"];
          hash = "sha256-dQvk6ezY6TQ1J7PjhCXnThF/SqVgPwBO8/RXzHCY+js=";
        };
        virtualHosts = builtins.listToAttrs (map (v:
          lib.nameValuePair "${v.sub}.${v.domain}" {
            extraConfig = ''
              tls {
                dns cloudflare {env.${domainTokens.${v.domain}}}
              }
              ${v.extraConfig or ""}
              reverse_proxy localhost:${toString v.port}
            '';
          })
        vhost);
      };

      age.secrets = ageSecret "cloudflare-api-token" {
        owner = "caddy";
        mode = "0400";
      };
      systemd.services.caddy.serviceConfig.EnvironmentFile = secretFile "cloudflare-api-token";

      networking.firewall.allowedTCPPorts = [80 443];
    };

    homepage = {
      group = "Security";
      name = "Caddy";
      icon = "caddy";
      widget = {
        type = "caddy";
        url = "http://localhost:2019";
      };
    };
  };
}
