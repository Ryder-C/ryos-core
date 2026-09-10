# OnePacerr automates One Pace (the fan re-edit of One Piece): polls its feed,
# grabs missing arcs via qBittorrent, files them into the Jellyfin library.
#
# It adopts the existing hand-built library instead of re-downloading: that
# library already uses OnePacerr's default layout and filenames, and the path
# Jellyfin reports is bind-mounted 1:1 into the container, so no MOUNT_*
# translation is needed. Present episodes are seen as satisfied.
{
  nixos = {
    config,
    secretFile,
    ...
  }: {
    virtualisation.oci-containers.containers.onepacerr = {
      image = "ghcr.io/eltharynd/onepacerr:latest";
      # Host networking so it can reach Jellyfin (localhost:8096) and
      # qBittorrent (localhost:8080). Its status API is served on :3007.
      extraOptions = ["--network=host"];
      volumes = [
        "/storage/media/library/one-pace:/storage/media/library/one-pace"
        "/storage/Torrents:/storage/Torrents"
      ];
      # JELLYFIN_PASSWORD=<jellyfin-admin secret>, written by the preStart below.
      environmentFiles = ["/run/onepacerr/env"];
      environment = {
        TZ = "America/Los_Angeles";
        LOG_LEVEL = "info";
        # ryder:media -- owner/group of the existing library (files are mode
        # 0664, media-group writable). (ryder=uid 1000, media=gid 169 on fornax.)
        PUID = "1000";
        PGID = "169";

        # Default 3000 is taken on this host (and --network=host binds directly).
        PORT = "3007";

        LIBRARY_MEDIA_SERVER = "jellyfin";
        LIBRARY_SERIES_NAME = "One Pace";
        LIBRARY_SERIES_FOLDER_NAME = "One Pace";
        LIBRARY_FILENAME_FORMAT = "{SERIES_NAME} - S{ARC}E{EPISODE} - {TITLE}.mkv";
        JELLYFIN_URL = "http://localhost:8096";
        # OnePacerr's Jellyfin client only does username+password auth.
        JELLYFIN_USERNAME = "ryder";
        JELLYFIN_LIBRARY_NAME = "One Pace";
        METADATA_POSTER_SET = "piratezekk";

        # WebUI\LocalHostAuth is disabled (ry.torrents), so requests from
        # localhost skip auth; these credentials are placeholders.
        TORRENT_CLIENT = "qbittorrent";
        TORRENT_URL = "http://localhost:8080";
        TORRENT_USER = "admin";
        TORRENT_PASSWORD = "adminadmin";
        TORRENT_CATEGORY = "onepacerr";

        # The library is adopted and organized, so skip the present-file
        # passes: they re-hash everything and rewrite .nfo/posters every cycle.
        # Flip back to "false" to re-run adoption after manual library edits.
        PIPELINE_SKIP_VERIFY_PRESENT_FILES = "true";
        PIPELINE_SKIP_ORGANIZE_PRESENT_FILES = "true";
        PIPELINE_SKIP_UPDATE_METADATA_PRESENT_FILES = "true";
        PIPELINE_SKIP_POSTERS = "true";
        PIPELINE_SKIP_DOWNLOADS = "false";
        PIPELINE_SKIP_DOWNLOADS_IMPORTS = "false";
        PIPELINE_FORCE_REDOWNLOAD = "false";
        # Prefer extended cuts; swaps a standard cut for the extended one.
        PIPELINE_PREFER_EXTENDED = "true";
        PIPELINE_PREFER_ALTERNATE = "false";
      };
    };

    # OnePacerr needs /storage mounted and the services it drives up first.
    # qBittorrent is started by the pia-vpn port-forward script, so depend on that.
    systemd.services."${config.virtualisation.oci-containers.backend}-onepacerr" = {
      unitConfig.RequiresMountsFor = "/storage";
      after = ["jellyfin.service" "pia-vpn.service"];
      wants = ["jellyfin.service"];
      serviceConfig.RuntimeDirectory = "onepacerr";
      # Render the env-file from the raw-password secret before the container
      # starts (/run/onepacerr is the RuntimeDirectory, root-only).
      preStart = ''
        umask 0077
        printf 'JELLYFIN_PASSWORD=%s\n' "$(cat ${secretFile "jellyfin-admin"})" > /run/onepacerr/env
      '';
    };
  };
}
