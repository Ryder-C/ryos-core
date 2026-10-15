# Host secrets: autobrr-api (homepage widget).
{host, ...}: let
  rylib = import ../../../_lib.nix;
in {
  nixos = {
    services.autobrr = {
      enable = true;
      openFirewall = true;
      settings = {
        host = "0.0.0.0";
        logLevel = "DEBUG";
      };
    };
  };

  homepage = {config, ...}: {
    group = "Downloads";
    name = "Autobrr";
    href = "http://${config.networking.hostName}:7474";
    icon = "autobrr";
    widget = {
      type = "autobrr";
      url = "http://localhost:7474";
      key = rylib.secretValue host "autobrr-api";
    };
  };
}
