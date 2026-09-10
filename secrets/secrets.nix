# Hosts whose ssh host key may decrypt the core-level (account-scoped) secrets.
# Adding a host: append its key here, then `agenix -r` from this directory.
let
  praxis = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINBKe9Q3rWE2xfBPp3oc4F+Edk9RqgTIio9OB6assgPw";
  fornax = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGQMQHflbq0edpmCdU0xFfySV8RZj7JMhCsw837sy2h8";
  hosts = [praxis fornax];
in {
  "pia.age".publicKeys = hosts;
  "cloudflare-api-token.age".publicKeys = hosts;
  "steam_key.age".publicKeys = hosts;
  "google-maps.age".publicKeys = hosts;
}
