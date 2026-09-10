# Routes Seerr requests to the right *arr: anime to sonarr-anime, the rest
# by media type. Host secret: seerr-api.
{
  nixos = {
    config,
    pkgs,
    secretFile,
    ...
  }: let
    configYmlTemplate = pkgs.writeText "redirecterr-config.yaml.template" ''
      overseerr_url: "http://localhost:5055"
      overseerr_api_token: "@SEERR_API_KEY@"
      approve_on_no_match: false

      instances:
        radarr:
          server_id: 0
          root_folder: "/storage/media/library/movies"
        sonarr:
          server_id: 0
          root_folder: "/storage/media/library/tv"
        sonarranime:
          server_id: 1
          root_folder: "/storage/media/library/anime"

      # Japanese, Chinese and Korean animation count as anime (Anilist/MAL
      # include those); Western animation does not.
      filters:
        - media_type: movie
          apply: radarr

        - media_type: tv
          conditions:
            keywords:
              require: ["anime", "donghua", "aeni"]
          apply: sonarranime

        - media_type: tv
          conditions:
            productionCountries:
              include: ["japan", "jp", "china", "cn", "south korea", "kr"]
            originalLanguage:
              include: ["ja", "zh", "ko"]
            genres:
              include: ["animation"]
          apply: sonarranime

        - media_type: tv
          apply: sonarr
    '';
  in {
    systemd.services."${config.virtualisation.oci-containers.backend}-redirecterr" = {
      serviceConfig.RuntimeDirectory = "redirecterr";
      preStart = ''
        ${pkgs.gnused}/bin/sed \
          -e "s|@SEERR_API_KEY@|$(cat ${secretFile "seerr-api"})|" \
          ${configYmlTemplate} > /run/redirecterr/config.yaml
      '';
    };

    virtualisation.oci-containers.containers.redirecterr = {
      image = "varthe/redirecterr:latest";
      ports = ["8481:8481"];
      volumes = ["/run/redirecterr/config.yaml:/config/config.yaml:ro"];
      extraOptions = ["--network=host"];
    };
  };
}
