{
  # Halloy config lives unmanaged in ~/.config/halloy/config.toml. Forcing
  # settings empty stops HM generating it (catppuccin/nix would otherwise set
  # `theme`); its theme file in halloy/themes/ is still installed.
  ry.irc.homeManager = {lib, ...}: {
    programs.halloy = {
      enable = true;
      settings = lib.mkForce {};
    };
  };
}
