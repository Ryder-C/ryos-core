{
  # Consumer of the `homepage` quirk: every aspect that runs a service emits
  # { group; name; href ? ...; icon; widget ? ...; } and shows up here.
  ry.homepage.nixos = {
    homepage,
    config,
    lib,
    ...
  }: {
    services.homepage-dashboard = {
      enable = true;
      openFirewall = true;
      allowedHosts = lib.concatStringsSep "," (map (h: "${h}:8082") [
        config.networking.hostName
        "${config.networking.hostName}.local"
        "localhost"
      ]);

      services =
        lib.mapAttrsToList
        (group: entries: {
          ${group} = map (e: {${e.name} = builtins.removeAttrs e ["group" "name"];}) entries;
        })
        (lib.groupBy (e: e.group) homepage);

      widgets = [
        {
          resources = {
            cpu = true;
            memory = true;
            disk = "/storage";
            expanded = true;
          };
        }
        {
          datetime = {
            text_size = "xl";
            format = {
              dateStyle = "long";
              timeStyle = "short";
              hourCycle = "h23";
            };
          };
        }
      ];
    };
  };
}
