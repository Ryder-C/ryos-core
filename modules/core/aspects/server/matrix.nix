{
  # Matrix homeserver (continuwuity) at matrix.ryder.rs, media on /storage.
  # Host secret: matrix-registration (the registration token).
  ry.matrix = {
    nixos = {secretFile, ...}: {
      services.matrix-continuwuity = {
        enable = true;
        settings.global = {
          server_name = "matrix.ryder.rs";
          port = [6167];

          media = {
            retention = [{space = "50G";}];
            backend = "filesystem";
            path = "/storage/matrix";
          };
          max_request_size = 1000000000;

          enable_lightning_bolt = false;

          allow_registration = true;
          registration_token_file = secretFile "matrix-registration";

          address = ["127.0.0.1"];
        };
      };

      # ReadWritePaths is resolved while systemd builds the unit's mount
      # namespace, so /storage must already be mounted or the service dies with
      # 226/NAMESPACE before it ever runs -- and hits the start limit after five
      # tries, which needs a manual `systemctl reset-failed` to clear. Without
      # RequiresMountsFor it raced the mount on every boot.
      systemd.services.continuwuity = {
        unitConfig.RequiresMountsFor = "/storage";
        serviceConfig.ReadWritePaths = ["/storage/matrix"];
      };
    };

    vhost = {
      domain = "ryder.rs";
      sub = "matrix";
      port = 6167;
    };
  };
}
