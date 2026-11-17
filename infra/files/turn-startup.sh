#!/bin/bash
# Runs on the relay VM at every boot (as its startup script): installs coturn and writes its configuration. The shared secret is read from Secret Manager with the VM's own service account
# (it may read that one secret only), so it is never in the VM's metadata or in this file. Same secret the app uses to make a call's short-lived credentials (CALL_TURN_SECRET).
set -euo pipefail
exec > >(tee -a /var/log/gi-turn-setup.log) 2>&1
export DEBIAN_FRONTEND=noninteractive

md() { curl -fsS -H 'Metadata-Flavor: Google' "http://metadata.google.internal/computeMetadata/v1/$1"; }
PROJECT="$(md project/project-id)"
EXT="$(md instance/network-interfaces/0/access-configs/0/external-ip)"
INT="$(md instance/network-interfaces/0/ip)"
TOKEN="$(md instance/service-accounts/default/token | python3 -c 'import sys,json;print(json.load(sys.stdin)["access_token"])')"
SECRET="$(curl -fsS -H "Authorization: Bearer ${TOKEN}" "https://secretmanager.googleapis.com/v1/projects/${PROJECT}/secrets/gi-call-turn-secret/versions/latest:access" \
  | python3 -c 'import sys,json,base64;print(base64.b64decode(json.load(sys.stdin)["payload"]["data"]).decode())')"

command -v turnserver >/dev/null 2>&1 || { apt-get update -y; apt-get install -y coturn; }

umask 077
cat > /etc/turnserver.conf <<EOF
# written by deploy/turn-startup.sh at boot: do not edit by hand
listening-port=3478
listening-ip=${INT}
relay-ip=${INT}
external-ip=${EXT}/${INT}
# a small block of ports for the relayed sound (the firewall opens exactly these)
min-port=49152
max-port=49252
fingerprint
use-auth-secret
static-auth-secret=${SECRET}
realm=gi-call
server-name=gi-call
# the relay is not a general proxy: limits per user and in all, no TCP relaying, nothing to the machine's own network, no admin console
total-quota=100
user-quota=20
stale-nonce=600
no-tcp-relay
no-multicast-peers
no-cli
no-tls
no-dtls
no-software-attribute
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=100.64.0.0-100.127.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.0.0.0-192.0.0.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=198.18.0.0-198.19.255.255
denied-peer-ip=240.0.0.0-255.255.255.255
syslog
EOF
chown root:turnserver /etc/turnserver.conf 2>/dev/null || true
chmod 640 /etc/turnserver.conf
sed -i 's/^#\?TURNSERVER_ENABLED=.*/TURNSERVER_ENABLED=1/' /etc/default/coturn 2>/dev/null || true
systemctl enable coturn
systemctl restart coturn
echo "gi-turn ready on ${EXT}:3478"
