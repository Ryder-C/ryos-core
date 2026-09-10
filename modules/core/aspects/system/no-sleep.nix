{
  # Never suspend or hibernate; masking the targets beats every desktop's
  # idle setting and the greeter's.
  ry.no-sleep.nixos.systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
}
