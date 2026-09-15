# onepace-fill -- keeps Wano watchable while One Pace is still working on it.
#
# One Pace's Wano arc is `wip`: S35E01-E61 adapt manga chapters 909-1012, but
# Wano runs to 1057. The Onigashima Paced project (a separate recut, chapters
# 977-1057) covers that tail, so its later episodes are hardlinked into the
# same Season 35 folder at E101+ and act as a stand-in.
#
# The timer is the interesting half: on each run the script asks One Pace's
# metadata API how far its released episodes now reach, and deletes every
# fill-in whose chapters have been overtaken. As One Pace ships E62, E63, ...
# the borrowed episodes retire themselves from the front and the season
# converges on pure One Pace with no manual pruning.
#
# See ./_onepace-fill.py for why E101+ (rather than E62+) and why OnePacerr
# leaves these files alone. Host secret: jellyfin-api.
{
  nixos = {
    pkgs,
    secretFile,
    ...
  }: {
    systemd.services.onepace-fill = {
      description = "Fill the One Pace Wano gap with Onigashima Paced episodes";
      after = ["network-online.target" "jellyfin.service" "pia-vpn.service"];
      wants = ["network-online.target"];
      unitConfig.RequiresMountsFor = "/storage";

      environment = {
        SOURCE_DIR = "/storage/Torrents/one-pace-fill/Onigashima Paced";
        SEASON_DIR = "/storage/media/library/one-pace/One Pace/Season 35";
        METADATA_URL = "https://onepacerr.com/api/v1";
        QBIT_URL = "http://localhost:8080";
        TORRENT_HASH = "4d04775faae4513ad07eb10774e1335c64a6d810";
        JELLYFIN_URL = "http://localhost:8096";
        # World-readable (store path or 0444 age file), so the unprivileged
        # service user can read it.
        JELLYFIN_API_KEY_FILE = secretFile "jellyfin-api";
        STATE_FILE = "/var/lib/onepace-fill/state.json";
        # The batch's one anime-only episode ("[1056 Filler] End of Wano 03.5").
        # Left out to match OnePacerr's PIPELINE_PREFER_ALTERNATE=false stance
        # on filler; set to "1" to include it.
        INCLUDE_FILLER = "0";
      };

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.python3}/bin/python3 ${./_onepace-fill.py}";
        # Match the library's existing ownership (ryder:media, mode 0664) so
        # imported episodes look identical to OnePacerr's own -- it runs the
        # container with PUID=1000/PGID=169, i.e. the same pair.
        User = "ryder";
        Group = "media";
        UMask = "0002";
        StateDirectory = "onepace-fill";
        ReadWritePaths = ["/storage"];
      };
    };

    systemd.timers.onepace-fill = {
      description = "Reconcile Onigashima Paced fill-ins against One Pace releases";
      wantedBy = ["timers.target"];
      timerConfig = {
        # One Pace ships a Wano episode every few weeks, so daily is ample; the
        # short OnBootSec exists to pick up a batch that finished downloading
        # while the machine was off.
        OnBootSec = "10min";
        OnUnitActiveSec = "1d";
        Persistent = true;
      };
    };
  };
}
