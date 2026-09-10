{
  description = "tabula: test VM";

  inputs.core.url = "github:Ryder-C/ryos-core";

  outputs = inputs:
    inputs.core.lib.mkHost {
      inherit inputs;
      name = "tabula";
      system = "x86_64-linux";
      flakePath = "/home/ryder/tabula";

      aspects = ry: [ry.desktop];

      aspect.nixos = {lib, ...}: {
        imports = [./hardware-configuration.nix];

        # kvm/qemu doesn't boot UEFI by default; use GRUB on the virtio disk.
        boot.loader = {
          systemd-boot.enable = lib.mkForce false;
          efi.canTouchEfiVariables = lib.mkForce false;
          grub = {
            enable = true;
            device = "/dev/vda";
            useOSProber = false;
          };
        };
      };
    };
}
