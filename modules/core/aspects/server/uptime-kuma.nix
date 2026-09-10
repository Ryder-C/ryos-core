{
  ry.uptime-kuma = {
    nixos.services.uptime-kuma = {
      enable = true;
      settings.PORT = "3002";
    };

    vhost = {
      domain = "ryder.rs";
      sub = "status";
      port = 3002;
    };

    homepage = {
      group = "Monitoring";
      name = "Uptime Kuma";
      href = "https://status.ryder.rs";
      icon = "uptime-kuma";
      widget = {
        type = "uptimekuma";
        url = "http://localhost:3002";
        slug = "default";
      };
    };
  };
}
