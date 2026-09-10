let
  cudaOverlay = _final: prev: {
    btop = prev.btop.override {cudaSupport = true;};
    blender = prev.blender.override {cudaSupport = true;};
  };
in {
  # Reads host facts: nvidia.open (bool) and nvidia.driver (nvidiaPackages attr).
  ry.nvidia = {
    nixos = {
      host,
      config,
      ...
    }: {
      nix.settings = {
        substituters = ["https://cuda-maintainers.cachix.org"];
        trusted-public-keys = ["cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="];
      };

      services.xserver.videoDrivers = ["nvidia"];

      environment.sessionVariables = {
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        LIBVA_DRIVER_NAME = "nvidia";
        WLR_NO_HARDWARE_CURSORS = "1";
        __GL_VRR_ALLOWED = "0";
      };

      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = true;
        powerManagement.finegrained = false;
        nvidiaSettings = true;
        inherit (host.nvidia) open;
        package = config.boot.kernelPackages.nvidiaPackages.${host.nvidia.driver};
      };

      boot.kernelParams = [
        "nvidia-drm.modeset=1"
        "nvidia-drm.fbdev=1"
      ];

      # stablePkgs picks this up too (defaults.nix shares the overlay list).
      nixpkgs.overlays = [cudaOverlay];
    };

    homeManager = {pkgs, ...}: {
      home.packages = [pkgs.nvtopPackages.nvidia];
    };
  };
}
