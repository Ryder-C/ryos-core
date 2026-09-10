{
  description = "fornax: home server";

  inputs.core.url = "github:Ryder-C/ryos-core";

  outputs = inputs:
    inputs.core.lib.mkHost {
      inherit inputs;
      name = "fornax";
      system = "x86_64-linux";
      users = ["ryder" "adin"];
      flakePath = "/home/ryder/fornax";

      facts = {
        # Pascal: no open-module support, and the 580 series is the last driver.
        nvidia = {
          open = false;
          driver = "legacy_580";
        };

        # Instance-local secrets. This repo is private; values land in the
        # nix store of this machine only. Decrypt the old .age files once with
        # `agenix -d <name>.age` and paste them here (or point at files).
        secrets = {
          jellyfin-api = "CHANGEME";
          jellyfin-admin = "CHANGEME";
          seerr-api = "CHANGEME";
          radarr-api = "CHANGEME";
          sonarr-api = "CHANGEME";
          sonarr-anime-api = "CHANGEME";
          prowlarr-api = "CHANGEME";
          arr-password = "CHANGEME";
          bazarr-api = "CHANGEME";
          # Multi-line env files can also be paths: autobrr = ./secrets/autobrr.env;
          autobrr = "CHANGEME";
          autobrr-api = "CHANGEME";
          qui = "CHANGEME";
          vaultwarden = "CHANGEME";
          # cross-seed = "{\"apiKey\": \"...\"}"; # enables the qBittorrent webhook
        };
      };

      aspects = ry: [
        ry.server
        ry.nvidia
        ry.audio
        ry.rgb
        ry.tailscale
        ry.homepage
        ry.caddy
        ry.vaultwarden
        ry.uptime-kuma
        ry.minecraft
        ry.guessr
        ry.nixflix
        ry.nixflix.onepace
        ry.nixflix.bazarr
        ry.nixflix.autobrr
        ry.nixflix.drainarr
        ry.nixflix.qui
        ry.nixflix.redirecterr
        ry.steam
        ry.steam.kiosk
      ];

      aspect.nixos = {pkgs, ...}: {
        imports = [./hardware-configuration.nix];
        boot.supportedFilesystems = ["bcachefs"];
        environment.systemPackages = [pkgs.bcachefs-tools];
      };
    };
}
