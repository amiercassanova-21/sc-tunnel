#!/bin/bash
# ==========================================
# SETUP ENGINE (XRAY + NGINX + MENU)
# ==========================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

clear
echo -e "${GREEN}>>> Memulai Instalasi Komponen VPS...${NC}"

# 1. Update sistem dan install paket pendukung
apt-get update -y
apt-get install -y curl wget socat jq unzip net-tools nginx certbot

# 2. Input Domain
read -rp "Masukkan Domain/Subdomain Anda: " USER_DOMAIN
mkdir -p /etc/xray
echo "$USER_DOMAIN" > /etc/xray/domain.txt

# 3. Terbitkan Sertifikat SSL Let's Encrypt
systemctl stop nginx
certbot certonly --standalone --agree-tos --register-unsafely-without-email -d "$USER_DOMAIN" --non-interactive

# 4. Install Resmi Xray-core
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 5. Konfigurasi Inbound VLESS di Xray
cat <<EOF > /usr/local/etc/xray/config.json
{
  "log": { "loglevel": "warning" },
  "inbounds": [
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "/vless" }
      }
    }
  ],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

# 6. Konfigurasi Nginx Reverse Proxy
cat <<EOF > /etc/nginx/conf.d/tunnel.conf
server {
    listen 80;
    server_name ${USER_DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name ${USER_DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${USER_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${USER_DOMAIN}/privkey.pem;

    location /vless {
        if (\$http_upgrade != "websocket") {
            return 404;
        }
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
}
EOF

# 7. Aktifkan Service
systemctl restart xray
systemctl restart nginx
systemctl enable xray nginx

# 8. Daftarkan Perintah 'menu' ke Sistem
# Ganti USERNAME_GITHUB dengan username GitHub Anda
REPO_URL="https://raw.githubusercontent.com/USERNAME_GITHUB/sc-tunnel/main"
curl -sS -o /usr/bin/menu "${REPO_URL}/menu.sh"
chmod +x /usr/bin/menu

# Pasang di profil login agar saat login SSH langsung buka menu
echo "menu" >> /root/.bashrc

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   INSTALASI SELESAI! KETIK 'menu' DI VPS   ${NC}"
echo -e "${GREEN}============================================${NC}"
