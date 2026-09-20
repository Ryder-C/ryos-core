let
  rylib = import ../../_lib.nix;
in {
  # Sunshine, the host half of Moonlight game streaming
  # (github:LizardByte/Sunshine). Pair clients and add apps from the web UI on
  # https://localhost:47990; the stream itself follows the graphical session,
  # so the seat has to be logged in.
  ry.sunshine = {
    # The virtual gamepad/keyboard/mouse Sunshine creates for the client go
    # through /dev/uinput.
    includes = [(rylib.groups ["input" "uinput"])];

    nixos.services.sunshine = {
      enable = true;
      openFirewall = true;

      # niri implements neither wlr-export-dmabuf (what Sunshine's wayland
      # backend wants, niri-wm/niri#2298) nor NvFBC, so DRM/KMS is the only
      # capture path left and it needs CAP_SYS_ADMIN.
      capSysAdmin = true;

      # `settings` and `applications` are deliberately left unset: the nixpkgs
      # module only passes a config file once one of them is set, and from then
      # on the web UI can no longer save anything -- every app and every
      # resolution tweak would have to come back through here.
    };
  };
}
