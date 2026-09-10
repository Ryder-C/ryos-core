let
  rylib = import ../../_lib.nix;
in {
  ry.hardware.nixos = {
    pkgs,
    lib,
    ...
  }: {
    hardware = {
      enableAllFirmware = true;
      enableRedistributableFirmware = true;
      uinput.enable = true;
      graphics = {
        enable = true;
        extraPackages = with pkgs; [
          vulkan-loader
          vulkan-tools
        ];
      };
      keyboard.qmk.enable = true;
    };
    # via is x86_64-only.
    services.udev.packages = rylib.availableOn pkgs lib [pkgs.via];
  };
}
