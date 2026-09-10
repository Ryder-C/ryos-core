{
  # x86_64-only, needs an NVIDIA GPU, ~3.5GB unfree build with no binary cache.
  ry.davinci-resolve.homeManager = {pkgs, ...}: {
    home.packages = [pkgs.davinci-resolve];
  };
}
