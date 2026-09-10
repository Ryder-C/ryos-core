{
  ry.nix.nixos = {
    host,
    pkgs,
    ...
  }: {
    # Flakes need git on PATH, for root as well.
    environment.systemPackages = [pkgs.git];

    nix = {
      daemonCPUSchedPolicy = "idle";
      daemonIOSchedClass = "idle";
      settings = {
        eval-cache = true;
        auto-optimise-store = true;
        experimental-features = ["nix-command" "flakes"];
        substituters = [
          "https://cache.nixos.org/"
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };
      gc = {
        automatic = false;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
    };

    nixpkgs.config.allowUnfree = true;

    # nh reads NH_FLAKE, so the shell aliases can stay path-agnostic.
    programs.nh = {
      enable = true;
      flake = host.flakePath;
      clean.enable = true;
      clean.extraArgs = "--keep-since 4d --keep 3";
    };
  };
}
