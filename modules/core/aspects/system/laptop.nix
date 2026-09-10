{
  ry.laptop.nixos = {
    config,
    pkgs,
    ...
  }: {
    services = {
      logind.settings.Login = {
        HandleLidSwitch = "suspend";
        HandleLidSwitchExternalPower = "suspend";
      };
      power-profiles-daemon.enable = true;
      upower = {
        enable = true;
        percentageLow = 20;
        percentageCritical = 5;
        percentageAction = 3;
        criticalPowerAction = "PowerOff";
      };
    };

    boot.extraModulePackages = [config.boot.kernelPackages.cpupower];

    environment.systemPackages = with pkgs; [
      acpi
      brightnessctl
      cpupower-gui
      powertop
    ];
  };
}
