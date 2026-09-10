### vpn-full — toggle full-tunnel routing through PIA wg0 with a kill switch.
###
### off (default): only services explicitly bound to wg0 use the VPN
### on:            ALL traffic exits via wg0; nftables blocks everything else

NFT_TABLE="vpn_killswitch"
STATE_DIR=/run/vpn-full
STATE_FILE="$STATE_DIR/state"
PIA_STATE=/var/lib/pia-vpn/wireguard.json
UNIT=vpn-full.service

die() { echo "vpn-full: $*" >&2; exit 1; }

require_root() {
  if [[ $EUID -ne 0 ]]; then
    exec sudo -E "$0" "$@"
  fi
}

read_pia() {
  [[ -r "$PIA_STATE" ]] || die "PIA wireguard state not found at $PIA_STATE — is pia-vpn running?"
  pia_endpoint_ip=$(jq -r '.server_ip' "$PIA_STATE")
  pia_endpoint_port=$(jq -r '.server_port' "$PIA_STATE")
  [[ -n "$pia_endpoint_ip" && "$pia_endpoint_ip" != "null" ]] || die "could not parse PIA endpoint IP"
  [[ -n "$pia_endpoint_port" && "$pia_endpoint_port" != "null" ]] || die "could not parse PIA endpoint port"
}

detect_underlay() {
  local line
  line=$(ip -4 route show default | awk '$5 != "wg0" {print; exit}')
  [[ -n "$line" ]] || die "no non-wg0 default route found — refusing to run"
  underlay_gw=$(awk '{print $3}' <<<"$line")
  underlay_dev=$(awk '{print $5}' <<<"$line")
  underlay_subnet=$(ip -4 -o addr show dev "$underlay_dev" | awk '/inet /{print $4; exit}')
  [[ -n "$underlay_subnet" ]] || die "could not determine subnet on $underlay_dev"
}

# systemd-resolved often link-scopes the underlay's DNS server. With the kill
# switch armed, those queries leave via the underlay to an off-LAN destination
# and get rejected. Pin DNS to wg0 with a public resolver so queries traverse
# the tunnel (no DNS leak to the underlay).
configure_dns() {
  resolvectl dns wg0 1.1.1.1 1.0.0.1
  resolvectl domain wg0 '~.'
  resolvectl default-route wg0 yes
  resolvectl flush-caches
}

revert_dns() {
  resolvectl revert wg0 2>/dev/null || true
  resolvectl flush-caches 2>/dev/null || true
}

cmd_apply() {
  require_root "$@"
  ip link show wg0 >/dev/null 2>&1 || die "wg0 not present — pia-vpn must be active first"
  read_pia
  detect_underlay

  mkdir -p "$STATE_DIR"
  cat > "$STATE_FILE" <<EOF
underlay_dev=$underlay_dev
underlay_gw=$underlay_gw
underlay_subnet=$underlay_subnet
pia_endpoint_ip=$pia_endpoint_ip
pia_endpoint_port=$pia_endpoint_port
EOF

  # Pin a host route to the PIA endpoint via the underlay BEFORE flipping the
  # default route, otherwise the wg handshake itself would try to traverse wg0.
  ip -4 route replace "$pia_endpoint_ip"/32 via "$underlay_gw" dev "$underlay_dev"

  # All other v4 traffic now exits via wg0.
  ip -4 route replace default dev wg0

  # Re-apply nft table idempotently.
  if nft list table inet "$NFT_TABLE" >/dev/null 2>&1; then
    nft delete table inet "$NFT_TABLE"
  fi

  nft -f - <<NFT
table inet $NFT_TABLE {
  chain output {
    type filter hook output priority -100; policy accept;

    oifname "lo" accept
    oifname "wg0" accept
    ct state established,related accept

    # PIA wireguard handshake survives the kill switch.
    oifname "$underlay_dev" ip daddr $pia_endpoint_ip udp dport $pia_endpoint_port accept

    # LAN reachability (SSH from local subnet, printers, etc.).
    oifname "$underlay_dev" ip daddr $underlay_subnet accept

    # DHCP renewal on the underlay.
    oifname "$underlay_dev" udp sport 68 udp dport 67 accept

    # Block all other v4 egress on the underlay.
    oifname "$underlay_dev" reject with icmpx type admin-prohibited

    # PIA wg0 typically has no v6 — kill v6 egress entirely (loopback already accepted above).
    meta nfproto ipv6 reject with icmpx type admin-prohibited
  }
}
NFT

  configure_dns

  echo "vpn-full: ON — default route via wg0, kill switch armed"
}

cmd_revert() {
  require_root "$@"

  revert_dns

  if nft list table inet "$NFT_TABLE" >/dev/null 2>&1; then
    nft delete table inet "$NFT_TABLE"
  fi

  ip -4 route del default dev wg0 2>/dev/null || true

  if [[ -r "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"
    ip -4 route del "$pia_endpoint_ip"/32 2>/dev/null || true
    # Belt and suspenders: NetworkManager normally restores the underlay default
    # on its own, but be explicit so the host isn't left without a default route.
    ip -4 route replace default via "$underlay_gw" dev "$underlay_dev" 2>/dev/null || true
  fi

  rm -f "$STATE_FILE"
  echo "vpn-full: off — split routing restored"
}

cmd_status() {
  if systemctl is-active --quiet "$UNIT"; then
    echo "mode: ON  (full tunnel, kill switch active)"
  else
    echo "mode: off (split routing — only wg0-bound services use VPN)"
  fi
  echo
  echo "pia-vpn.service: $(systemctl is-active pia-vpn.service 2>/dev/null || echo unknown)"
  if ip link show wg0 >/dev/null 2>&1; then
    echo "wg0: up"
  else
    echo "wg0: ABSENT"
  fi
  echo
  echo "default routes:"
  ip -4 route show default | sed 's/^/  /'
  echo
  if nft list table inet "$NFT_TABLE" >/dev/null 2>&1; then
    echo "nft kill switch: present"
  else
    echo "nft kill switch: absent"
  fi
}

usage() {
  cat <<USAGE
usage: vpn-full {on|off|status}

  on      route ALL traffic through PIA wg0 and arm the kill switch
  off     restore split routing (only services bound to wg0 use the VPN)
  status  show current mode
USAGE
}

case "${1:-status}" in
  on)      systemctl start "$UNIT" ;;
  off)     systemctl stop  "$UNIT" ;;
  status)  cmd_status ;;
  _apply)  cmd_apply  "$@" ;;   # internal: invoked by the systemd unit
  _revert) cmd_revert "$@" ;;   # internal: invoked by the systemd unit
  -h|--help) usage ;;
  *)       usage; exit 2 ;;
esac
