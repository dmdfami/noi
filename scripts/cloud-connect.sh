#!/usr/bin/env bash
# Kết nối Cursor Cloud agent → tailnet, rồi mở sẵn `ssh mac` / `ssh vps`.
#
# Idempotent: chạy lại bao nhiêu lần cũng được.
# Dùng các secret GLOBAL đã có sẵn trong mọi cloud agent:
#   TS_AUTHKEY           - Tailscale auth key
#   SSH_PRIVATE_KEY_VPS  - private key đã được authorize trên cả Mac lẫn VPS
#
# Sau khi chạy:  ssh mac 'lệnh'   |   ssh vps 'lệnh'
set -euo pipefail

log() { printf '\033[36m[cloud-connect]\033[0m %s\n' "$*"; }

# --- 1. Tailscale CLI ---
if ! command -v tailscale >/dev/null 2>&1; then
  log "cài tailscale…"
  curl -fsSL https://tailscale.com/install.sh | sudo sh >/dev/null 2>&1
fi

# --- 2. tailscaled ở chế độ userspace (bắt buộc trong container, không có /dev/net/tun) ---
if ! pgrep -x tailscaled >/dev/null 2>&1; then
  log "khởi động tailscaled (userspace networking)…"
  sudo mkdir -p /var/lib/tailscale
  sudo nohup tailscaled \
    --tun=userspace-networking \
    --socks5-server=localhost:1055 \
    --outbound-http-proxy-listen=localhost:1055 \
    --state=/var/lib/tailscale/tailscaled.state \
    >/tmp/tailscaled.log 2>&1 &
  sleep 4
fi

# --- 3. Join tailnet ---
if ! tailscale status >/dev/null 2>&1; then
  : "${TS_AUTHKEY:?thiếu secret TS_AUTHKEY}"
  log "join tailnet…"
  sudo tailscale up --authkey="$TS_AUTHKEY" --hostname="cursor-cloud-$(hostname | tr -cd 'a-z0-9-' | cut -c1-20)" --accept-routes >/dev/null
fi
log "tailnet: $(tailscale status --self --peers=false 2>/dev/null | head -1 || echo connected)"

# --- 4. SSH key + alias ---
: "${SSH_PRIVATE_KEY_VPS:?thiếu secret SSH_PRIVATE_KEY_VPS}"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
printf '%s\n' "$SSH_PRIVATE_KEY_VPS" > ~/.ssh/id_noi
chmod 600 ~/.ssh/id_noi

# ProxyCommand `tailscale nc` định tuyến qua tailscaled — cần thiết vì userspace
# networking không cắm route vào kernel, ssh thường sẽ không tới được tailnet.
if ! grep -q '^Host mac$' ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config <<'EOF'

Host mac
  HostName mac-m1max-david-1
  User david
  IdentityFile ~/.ssh/id_noi
  IdentitiesOnly yes
  ProxyCommand tailscale nc %h %p
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  ServerAliveInterval 30

Host vps
  HostName vps-d92
  User root
  IdentityFile ~/.ssh/id_noi
  IdentitiesOnly yes
  ProxyCommand tailscale nc %h %p
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  ServerAliveInterval 30
EOF
  chmod 600 ~/.ssh/config
fi

# --- 5. Kiểm tra ---
for h in mac vps; do
  if timeout 25 ssh -q "$h" 'exit 0' 2>/dev/null; then
    log "ssh $h: OK ($(timeout 25 ssh -q "$h" 'uname -sm' 2>/dev/null))"
  else
    log "ssh $h: chưa tới được (máy có thể đang offline)"
  fi
done
log "xong — dùng: ssh mac '<lệnh>'  hoặc  ssh vps '<lệnh>'"
