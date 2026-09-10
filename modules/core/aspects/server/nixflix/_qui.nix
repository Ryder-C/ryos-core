# qBittorrent web UI with cross-seeding. Host secret: qui.
{
  nixos = {
    lib,
    secretFile,
    ...
  }: {
    services.qui = {
      enable = true;
      secretFile = secretFile "qui";
      settings.host = "0.0.0.0";
    };

    # qui needs to write the cross-seed hardlink tree under /storage/Torrents,
    # which is group-writable only by `media`.
    users.users.qui.extraGroups = ["media"];
    systemd.tmpfiles.rules = [
      "d /storage/Torrents/cross-seed 0775 qui media - -"
    ];

    # qui hardlinks files it doesn't own into the cross-seed tree, which
    # fs.protected_hardlinks=1 forbids without CAP_FOWNER. PrivateUsers must go
    # too: in a user namespace CAP_FOWNER only covers mapped uids.
    systemd.services.qui.serviceConfig = {
      PrivateUsers = lib.mkForce false;
      CapabilityBoundingSet = lib.mkForce ["CAP_FOWNER"];
      AmbientCapabilities = ["CAP_FOWNER"];
    };
  };
}
