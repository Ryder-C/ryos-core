{
  ry.irc.homeManager.programs.halloy = {
    enable = true;
    settings.servers = let
      server = host: port: {
        nickname = "ThePDB";
        server = host;
        inherit port;
      };
    in {
      scratch-network = server "irc.scratch-network.net" 6697;
      digitalcore = server "irc.digitalcore.club" 7000;
      darkpeers = server "irc.darkpeers.org" 6697;
    };
  };
}
