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
      # NixOS CUDA team's cache: cache.nixos.org skips CUDA builds, so without
      # this ollama-cuda and friends compile locally.
      nix.settings = {
        substituters = ["https://cache.nixos-cuda.org"];
        trusted-public-keys = ["cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="];
      };

      services.xserver.videoDrivers = ["nvidia"];

      environment.sessionVariables = {
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
        LIBVA_DRIVER_NAME = "nvidia";
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
