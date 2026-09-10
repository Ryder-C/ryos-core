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
      allowedHosts = "${config.networking.hostName}:8082";

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
