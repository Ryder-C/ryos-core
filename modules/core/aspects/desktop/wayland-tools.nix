{
  # Session plumbing any Wayland desktop wants: clipboard, notifications,
  # screenshots, brightness, xdg-open.
  ry.wayland-tools = {
    nixos = {pkgs, ...}: {
      environment.systemPackages = [pkgs.networkmanagerapplet];
    };

    homeManager = {pkgs, ...}: {
      home.packages = with pkgs; [
        brightnessctl
        grim
        libnotify
        poweralertd
        slurp
        swappy
        wl-clipboard
        wl-mirror
        xdg-utils
        xwayland-run
        zenity
      ];

      services.cliphist = {
        enable = true;
        allowImages = true;
      };
    };
  };
}
