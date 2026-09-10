{
  ry.obs = {
    # Virtual camera for OBS.
    nixos = {config, ...}: {
      boot = {
        extraModulePackages = [config.boot.kernelPackages.v4l2loopback];
        kernelModules = ["v4l2loopback"];
        extraModprobeConfig = ''
          options v4l2loopback devices=1 video_nr=10 card_label="OBS Virtual Camera" exclusive_caps=1
        '';
      };
    };
    homeManager = {pkgs, ...}: {
      home.packages = [pkgs.obs-studio];
    };
  };
}
