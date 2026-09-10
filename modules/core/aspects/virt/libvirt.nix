let
  rylib = import ../../_lib.nix;
in {
  ry.libvirt = {
    includes = [(rylib.groups ["libvirtd"])];
    nixos = {pkgs, ...}: {
      environment.systemPackages = with pkgs; [
        virt-manager
        virt-viewer
        spice
        spice-gtk
        spice-protocol
        virtio-win
        win-spice
      ];

      programs.virt-manager.enable = true;
      users.users.qemu-libvirtd.extraGroups = ["video" "render" "kvm"];

      virtualisation = {
        libvirtd = {
          enable = true;
          qemu.swtpm.enable = true;
        };
        spiceUSBRedirection.enable = true;
      };
      services.spice-vdagentd.enable = true;
    };
  };
}
