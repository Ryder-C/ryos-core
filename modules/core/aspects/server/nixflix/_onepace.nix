# OnePacerr automates One Pace (the fan re-edit of One Piece): polls its feed,
# grabs missing arcs via qBittorrent, files them into the Jellyfin library.
#
# It adopts the existing hand-built library instead of re-downloading: that
# library already uses OnePacerr's default layout and filenames, and the path
# Jellyfin reports is bind-mounted 1:1 into the container, so no MOUNT_*
# translation is needed. Present episodes are seen as satisfied.
{
  nixos = {
    lib,
    config,
    secretFile,
    ...
  }: {
    virtualisation.oci-containers.containers.onepacerr = {
      # Pinned: upstream only ever moves the `latest` tag, and podman's default
      # --pull=missing means a cached `latest` is never refreshed -- the
      # container sat on 1.7.9 for months. Version tags are published as
      # vX.Y.Z, so pin one and bump it deliberately. (v1.7.20 is what added
      # LIBRARY_USE_HARDLINKS.)
      #
      # The metadata API is live, not pinned: since v1.8.0 it maps unreleased
      # episodes to fan "supplement" batches (Onigashima Paced for Wano,
      # Shaved Egghead + Kuma Cut for Egghead), flagged partOfBundle. Clients
      # older than v1.8.4 import every file of such a batch onto a single
      # episode, leave the rest "missing", and re-add the torrent on every
      # metadata update -- so don't pin below v1.8.4.
      image = "ghcr.io/eltharynd/onepacerr:v1.8.11";
      # Host networking so it can reach Jellyfin (localhost:8096) and
      # qBittorrent (localhost:8080). Its status API is served on :3007.
      extraOptions = ["--network=host"];
      volumes = [
        # Same paths the host/Jellyfin/qBittorrent use, so no path remapping.
        #
        # All of /storage as ONE bind mount, not separate binds for the library
        # and the torrent dir: link(2) returns EXDEV across different mounts
        # even when they're the same filesystem, which would silently downgrade
        # LIBRARY_USE_HARDLINKS to copying. /storage is a single bcachefs
        # filesystem with nothing else mounted underneath, so one bind keeps
        # /storage/Torrents and /storage/media/library on the same mount and
        # hardlinks work.
        "/storage:/storage"
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
        # Import by hardlink instead of copy (and rename in place instead of
        # copy+delete), so an imported episode costs no extra space and the
        # torrent keeps seeding from the same inode. Requires the download dir
        # and the library to be on one mount -- see the single /storage bind
        # above. OnePacerr falls back to copying (with a warning in the log)
        # on EXDEV.
        LIBRARY_USE_HARDLINKS = "true";
        JELLYFIN_URL = "http://localhost:8096";
        # OnePacerr's Jellyfin client only does username+password auth.
        JELLYFIN_USERNAME = "ryder";
        # NOTE: OnePacerr resolves this name against /Users/<id>/Views -- the
        # *views* of the account above, not the admin library list. A library
        # that is checked under Jellyfin's Settings -> Home -> "Automatically
        # group content from the following folders into views such as Movies,
        # Music and TV" is merged into the combined TV view and stops existing
        # as a view of its own, and OnePacerr then dies at startup with
        # "Jellyfin library 'One Pace' not found ... Available libraries: ...".
        # So "One Pace" must stay UNCHECKED in that list for the ryder account.
        # ("Latest media" exclusion is unrelated and safe to keep on.)
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
        # Fill One Pace's unfinished arcs from the supplement batches (see the
        # image pin above). This is the upstream default; stated explicitly
        # because it replaced the old onepace-fill timer.
        PIPELINE_SKIP_SUPPLEMENTS = "false";
      };
    };

    # OnePacerr needs /storage mounted and the services it drives up first.
    # qBittorrent is started by the pia-vpn port-forward script, so depend on that.
    systemd.services."${config.virtualisation.oci-containers.backend}-onepacerr" = {
      unitConfig.RequiresMountsFor = "/storage";
      after = ["jellyfin.service" "pia-vpn.service"];
      wants = ["jellyfin.service"];
      serviceConfig = {
        RuntimeDirectory = "onepacerr";
        # OnePacerr catches its own startup errors, logs "APPLICATION CRASHED
        # UNEXPECTEDLY", then shuts down *gracefully* -- i.e. exit 0. The
        # module's default Restart=on-failure therefore never fires, so a
        # transient Jellyfin/qBittorrent outage leaves the container dead until
        # the next rebuild. Restart unconditionally, backing off enough to keep
        # a genuine misconfiguration from spinning.
        Restart = lib.mkForce "always";
        RestartSec = 60;
      };
      # Render the env-file from the raw-password secret before the container
      # starts (/run/onepacerr is the RuntimeDirectory, root-only).
      preStart = ''
        umask 0077
        printf 'JELLYFIN_PASSWORD=%s\n' "$(cat ${secretFile "jellyfin-admin"})" > /run/onepacerr/env
      '';
    };
  };
}
