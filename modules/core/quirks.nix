# Quirks are den's decoupled data channels: any aspect may emit entries on
# these keys; the consumer aspect (ry.homepage, ry.caddy) receives the list.
# Without a consumer the data is simply dropped.
{
  den.quirks = {
    homepage.description = ''
      Homepage dashboard entries: { group; name; href ? null; icon; widget ? null; }
    '';
    vhost.description = ''
      Reverse-proxy virtual hosts for ry.caddy: { domain; sub; port; extraConfig ? ""; }
    '';
  };
}
