{
  # Desktop defaults: the power button powers off, closing a lid does nothing.
  # ry.laptop overrides the lid behaviour.
  ry.power.nixos = {lib, ...}: {
    services.logind.settings.Login = {
      HandlePowerKey = "poweroff";
      HandleLidSwitch = lib.mkDefault "ignore";
      HandleLidSwitchDocked = lib.mkDefault "ignore";
      HandleLidSwitchExternalPower = lib.mkDefault "ignore";
      IdleAction = "ignore";
    };
  };
}
