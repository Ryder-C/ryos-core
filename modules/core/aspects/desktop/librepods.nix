{inputs, ...}: {
  flake-file.inputs.librepods = {
    url = "github:kavishdevar/librepods/linux/rust";
    inputs.nixpkgs.follows = "nixpkgs";
  };

  ry.librepods.homeManager = {pkgs, ...}: let
    librepods = inputs.librepods.packages.${pkgs.stdenv.hostPlatform.system}.default;
  in {
    home.packages = [librepods];

    systemd.user.services.librepods = {
      Unit = {
        Description = "LibrePods";
        After = ["graphical-session.target" "tray.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
        ExecStart = "${librepods}/bin/librepods --start-minimized";
        Restart = "on-failure";
        RestartSec = 3;
      };
      Install.WantedBy = ["graphical-session.target"];
    };
  };
}
