{inputs, ...}: {
  # Pinned: newer NUR revisions pull AtaraxiaSjel/nur commits where
  # pkgs/default.nix still passes `pkgs` to pkgs/python3Packages/default.nix
  # after that argument was removed, which breaks nur.repos.ataraxiasjel.*
  # (waydroid-script). Unpin once upstream fixes it.
  flake-file.inputs.nur.url = "github:nix-community/NUR/7b386c5c7fe4fde8cd4322ba2a85df7a5c3afcbf";

  ry.waydroid.nixos = {pkgs, ...}: {
    nixpkgs.overlays = [inputs.nur.overlays.default];

    virtualisation.waydroid = {
      enable = true;
      package = pkgs.waydroid-nftables;
    };

    # User units (waydroid session) need a usable PATH.
    systemd.user.settings.Manager.DefaultEnvironment = "PATH=/run/current-system/sw/bin:/run/wrappers/bin:${pkgs.lib.makeBinPath [pkgs.bash pkgs.shadow]}";

    environment.systemPackages = with pkgs; [
      android-tools
      iptables
      nur.repos.ataraxiasjel.waydroid-script
    ];
  };
}
