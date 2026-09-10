{
  ry.audio = {
    nixos = {pkgs, ...}: {
      security.rtkit.enable = true;
      services.pulseaudio.enable = false;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;

        # Disable automatic HSP/HFP switching (AirPods).
        wireplumber.extraConfig."11-bluetooth-policy" = {
          "wireplumber.settings" = {
            "bluetooth.autoswitch-to-headset-profile" = false;
          };
        };
      };
      environment.systemPackages = [pkgs.pulseaudioFull];
    };

    homeManager = {
      pkgs,
      stablePkgs,
      ...
    }: {
      home.packages = with pkgs; [
        pavucontrol
        playerctl
        stablePkgs.pamixer
      ];
      services.playerctld.enable = true;
      programs.cava.enable = true;
    };
  };
}
