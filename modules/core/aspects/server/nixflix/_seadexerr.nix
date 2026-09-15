# Seadexerr upgrades anime in Sonarr/Radarr to the SeaDex-recommended release.
# Host secrets: sonarr-anime-api, radarr-api, anilist (AniList access token).
{
  nixos = {
    config,
    pkgs,
    secretFile,
    ...
  }: let
    # Mounted read-only at /data/scoring.toml
    scoringToml = pkgs.writeText "seadexerr-scoring.toml" ''
      best = 100
      dual_audio = 5

      size_weight = -200

      exclude_tags = ["Deband Required"]
    '';
  in {
    systemd.tmpfiles.rules = [
      "d /var/lib/seadexerr 0750 root root - -"
    ];

    systemd.services."${config.virtualisation.oci-containers.backend}-seadexerr" = {
      after = ["sonarr-anime.service" "radarr.service"];
      serviceConfig.RuntimeDirectory = "seadexerr";
      preStart = ''
        umask 0077
        {
          printf 'SONARR_API_KEY=%s\n' "$(cat ${secretFile "sonarr-anime-api"})"
          printf 'RADARR_API_KEY=%s\n' "$(cat ${secretFile "radarr-api"})"
          printf 'ANILIST_ACCESS_TOKEN=%s\n' "$(cat ${secretFile "anilist"})"
        } > /run/seadexerr/env
      '';
    };

    virtualisation.oci-containers.containers.seadexerr = {
      # Pinned rather than `latest`: podman's --pull=missing (what
      # oci-containers generates) never refreshes a cached tag, so `latest`
      # stayed on v2.x through rebuilds. v3.0.0 moved the default port
      # 6767 -> 2071 and added ANILIST_ACCESS_TOKEN, so the port is left unset
      # and taken from the image.
      image = "ghcr.io/ryder-c/seadexerr:v3.0.0";
      environment = {
        SONARR_BASE_URL = "http://localhost:8990/";
        RADARR_BASE_URL = "http://localhost:7878/";
        TZ = "America/Los_Angeles";
      };
      environmentFiles = ["/run/seadexerr/env"];
      volumes = [
        "/var/lib/seadexerr:/data"
        "${scoringToml}:/data/scoring.toml:ro"
      ];
      extraOptions = ["--network=host"];
    };
  };
}
