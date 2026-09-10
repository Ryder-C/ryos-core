{
  ry.thunar = {
    nixos = {
      programs.thunar.enable = true;
      services.gvfs.enable = true;
      services.tumbler.enable = true;
    };

    homeManager = {
      xdg.mimeApps = {
        enable = true;
        defaultApplications."inode/directory" = ["thunar.desktop"];
      };
      xdg.dataFile."applications/mimeapps.list".force = true;
    };
  };
}
