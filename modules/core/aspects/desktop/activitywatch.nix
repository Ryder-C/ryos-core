{inputs, ...}: {
  flake-file.inputs.rypkgs.url = "github:Ryder-C/rypkgs";

  ry.activitywatch.homeManager = {pkgs, ...}: {
    services.activitywatch = {
      enable = true;
      watchers = {
        awatcher.package = pkgs.awatcher;
        aw-watcher-media-player.package = inputs.rypkgs.packages.${pkgs.stdenv.hostPlatform.system}.aw-watcher-media-player;
      };
    };

    systemd.user.services = {
      activitywatch-watcher-awatcher = {
        Unit.After = ["graphical-session.target"];
        Service = {
          Restart = "always";
          RestartSec = "5s";
          StartLimitBurst = 0;
        };
      };
      activitywatch-watcher-aw-watcher-media-player.Service.Restart = "on-failure";
    };
  };
}
