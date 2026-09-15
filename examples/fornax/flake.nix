{
  description = "fornax: home server";

  inputs.core.url = "github:Ryder-C/ryos-core";

  outputs = inputs:
    inputs.core.lib.mkHost {
      inherit inputs;
      name = "fornax";
      system = "x86_64-linux";
      users = ["ryder" "adin"];
      flakePath = "/etc/nixos";

      facts = {
        # Pascal: no open-module support, and the 580 series is the last driver.
        nvidia = {
          open = false;
          driver = "legacy_580";
        };

        # Instance-local secrets, one plain file each under ./secrets. This
        # repo is private; values land in the nix store of this machine only.
        # `secrets/import-agenix.sh` fills the directory from the old repo's
        # .age files. Multi-line env files (autobrr, vaultwarden) work the same
        # way, as do string values in place of a path.
        secrets = {
          jellyfin-api = ./secrets/jellyfin-api;
          jellyfin-admin = ./secrets/jellyfin-admin;
          seerr-api = ./secrets/seerr-api;
          radarr-api = ./secrets/radarr-api;
          sonarr-api = ./secrets/sonarr-api;
          sonarr-anime-api = ./secrets/sonarr-anime-api;
          prowlarr-api = ./secrets/prowlarr-api;
          arr-password = ./secrets/arr-password;
          bazarr-api = ./secrets/bazarr-api;
          autobrr = ./secrets/autobrr;
          autobrr-api = ./secrets/autobrr-api;
          qui = ./secrets/qui;
          vaultwarden = ./secrets/vaultwarden;
          # {"apiKey": "..."}; its presence enables the qBittorrent webhook.
          cross-seed = ./secrets/cross-seed;
          anilist = ./secrets/anilist;
          matrix-registration = ./secrets/matrix-registration;
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
        ry.matrix
        ry.nixflix
        ry.nixflix.onepace
        ry.nixflix.onepace-fill
        ry.nixflix.bazarr
        ry.nixflix.autobrr
        ry.nixflix.drainarr
        ry.nixflix.qui
        ry.nixflix.redirecterr
        ry.nixflix.seadexerr
        ry.nixflix.arr-mcp
        ry.steam
        ry.steam.kiosk
        # claude-code and the shared MCP client that ry.nixflix.arr-mcp
        # registers with.
        ry.ai
      ];

      aspect.nixos = {pkgs, ...}: {
        imports = [./hardware-configuration.nix];
        boot.supportedFilesystems = ["bcachefs"];
        environment.systemPackages = [pkgs.bcachefs-tools];
      };
    };
}
