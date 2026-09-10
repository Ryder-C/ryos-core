{
  ry.swap.nixos = {
    zramSwap.enable = true;
    swapDevices = [
      {
        device = "/var/lib/swapfile";
        size = 8 * 1024;
      }
    ];
  };
}
