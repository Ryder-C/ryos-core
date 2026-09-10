{
  ry.toys.homeManager = {pkgs, ...}: {
    home.packages = with pkgs; [
      asciiquarium-transparent
      cbonsai
      cmatrix
      nitch
      pipes
      toipe
      vitetris
      nethack
    ];
  };
}
