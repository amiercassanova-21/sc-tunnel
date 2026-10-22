#!/bin/bash
# ==============================================================================
# SCRIPT SETUP CORE ENGINE: CASSANOVA TUNELLING V2 (FULL PRODUCTION)
# OS Support: Ubuntu 20.04/22.04/24.04 & Debian 10/11/12 (x86_64)
# Repo: https://github.com/amiercassanova-21/sc-tunnel
# ==============================================================================

export DEBIAN_FRONTEND=noninteractive

# Definisi Warna Terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Validasi Hak Akses Root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR] Script ini wajib dijalankan sebagai user root.${NC}" >&2
    exit 1
fi

# Validasi Sistem Operasi
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        echo -e "${RED}[ERROR] OS $ID tidak didukung. Gunakan Debian atau Ubuntu.${NC}" >&2
        exit 1
    fi
else
    echo -e "${RED}[ERROR] File identitas sistem /etc/os-release tidak ditemukan.${NC}" >&2
    exit 1
fi

# Bersihkan Layar dan Buffer
printf "\033[2J\033[H\033[3J"
echo -e "${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${NC}    ${CYAN}MEMULAI INSTALASI CASSANOVA TUNNELING V2${NC}      ${BLUE}│${NC}"
echo -e "${BLUE}└──────────────────────────────────────────────────┘${NC}"

# 1. Deteksi IP Publik VPS
MY_IP=$(curl -sS --max-time 5 https://ipv4.icanhazip.com || curl -sS --max-time 5 https://api.ipify.org)
echo -e "${YELLOW}[*] IP Publik Server Terdeteksi: ${GREEN}${MY_IP}${NC}"

# 2. Input Domain / Subdomain
read -rp "Masukkan Domain / Subdomain yang sudah di-pointing ke VPS: " USER_DOMAIN
if [[ -z "$USER_DOMAIN" ]]; then
    echo -e "${RED}[ERROR] Domain tidak boleh kosong.${NC}"
    exit 1
fi

# Persiapan Folder dan Database Awal
mkdir -p /etc/xray /etc/ssh /var/log/xray
echo "$USER_DOMAIN" > /etc/xray/domain.txt
touch /etc/xray/vless.db /etc/xray/vmess.db /etc/xray/trojan.db /etc/ssh/.ssh.db

# 3. Instalasi Paket Dependensi Sistem
echo -e "${YELLOW}[1/8] Menginstal dependensi sistem dan modul jaringan...${NC}"
apt-get update -y
apt-get install -y --no-install-recommends \
    curl wget socat jq tar unzip net-tools cron certbot nginx vnstat fail2ban iptables

# Inisialisasi Database vnstat untuk Pemantau Bandwidth
IFACE=$(ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -n1)
IFACE=${IFACE:-eth0}
systemctl stop vnstat 2>/dev/null
vnstat -i "$IFACE" --add 2>/dev/null
systemctl restart vnstat
systemctl enable vnstat

# 4. Optimasi Kernel TCP BBR
echo -e "${YELLOW}[2/8] Mengaktifkan akselerasi TCP BBR...${NC}"
sed -i '/net.core.default_qdisc/d' /etc/sysctl.conf
sed -i '/net.ipv4.tcp_congestion_control/d' /etc/sysctl.conf
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf >/dev/null 2>&1

# 5. Penerbitan Sertifikat SSL Let's Encrypt
echo -e "${YELLOW}[3/8] Menerbitkan sertifikat SSL HTTPS...${NC}"
systemctl stop nginx 2>/dev/null || true
certbot certonly --standalone --agree-tos --register-unsafely-without-email \
    -d "$USER_DOMAIN" --non-interactive

if [[ ! -f "/etc/letsencrypt/live/$USER_DOMAIN/fullchain.pem" ]]; then
    echo -e "${RED}[ERROR] Penerbitan SSL gagal. Pastikan port 80 terbuka dan domain sudah mengarah ke IP VPS ini.${NC}"
    exit 1
fi

# 6. Pemasangan Resmi Xray-core
echo -e "${YELLOW}[4/8] Menginstal Xray-core release resmi...${NC}"
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install

# 7. Membangun Konfigurasi Multi-Inbound Xray
echo -e "${YELLOW}[5/8] Mengonfigurasi engine Xray (VLESS, VMess, Trojan)...${NC}"
cat <<EOF > /usr/local/etc/xray/config.json
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "tag": "vless-in",
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless"
        }
      }
    },
    {
      "tag": "vmess-in",
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vmess"
        }
      }
    },
    {
      "tag": "trojan-in",
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "clients": []
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/trojan"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    },
    {
      "protocol": "blackhole",
      "tag": "blocked"
    }
  ]
}
EOF

# 8. Membangun Konfigurasi Nginx Reverse Proxy
echo -e "${YELLOW}[6/8] Menyiapkan reverse proxy Nginx di port 443...${NC}"
cat <<EOF > /etc/nginx/conf.d/tunnel.conf
server {
    listen 80;
    listen [::]:80;
    server_name ${USER_DOMAIN};
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${USER_DOMAIN};

    ssl_certificate /etc/letsencrypt/live/${USER_DOMAIN}/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/${USER_DOMAIN}/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / {
        default_type text/html;
        return 200 "<h1>CASSANOVA TUNNELING ENGINE RUNNING</h1>";
    }

    location /vless {
        if (\$http_upgrade != "websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /vmess {
        if (\$http_upgrade != "websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }

    location /trojan {
        if (\$http_upgrade != "websocket") {
            return 404;
        }
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

# 9. Mengunduh Seluruh Modul CLI & Eksekutor dari GitHub (Bypass Cache CDN)
echo -e "${YELLOW}[7/8] Mengunduh modul antarmuka CASSANOVA V2...${NC}"
REPO="https://raw.githubusercontent.com/amiercassanova-21/sc-tunnel/main"
CACHE_BUSTER="?v=$(date +%s)"

# Download Menu Utama
curl -sS "${REPO}/menu.sh${CACHE_BUSTER}" -o /usr/bin/menu
chmod +x /usr/bin/menu

# Download Modul Navigasi (Folder modules/)
MODULES=("m-ssh" "m-vmess" "m-vless" "m-trojan" "m-bot" "m-feature")
for mod in "${MODULES[@]}"; do
    curl -sS "${REPO}/modules/${mod}.sh${CACHE_BUSTER}" -o /usr/bin/${mod}
    chmod +x /usr/bin/${mod}
done

# Download Eksekutor Core (Folder xrays/)
XRAYS=("add-vless" "del-vless" "renew-vless" "cek-vless")
for xry in "${XRAYS[@]}"; do
    curl -sS "${REPO}/xrays/${xry}.sh${CACHE_BUSTER}" -o /usr/bin/${xry}
    chmod +x /usr/bin/${xry}
done

# 10. Membuat Alat Fast Updater di Sistem (/usr/bin/update-sc)
cat << 'EOF' > /usr/bin/update-sc
#!/bin/bash
REPO="https://raw.githubusercontent.com/amiercassanova-21/sc-tunnel/main"
CACHE="?v=$(date +%s)"
echo -e "\033[1;33m[*] Mengambil update terbaru langsung dari GitHub...\033[0m"
curl -sS "${REPO}/menu.sh${CACHE}" -o /usr/bin/menu && chmod +x /usr/bin/menu
for mod in m-ssh m-vmess m-vless m-trojan m-bot m-feature; do
    curl -sS "${REPO}/modules/${mod}.sh${CACHE}" -o /usr/bin/${mod} 2>/dev/null && chmod +x /usr/bin/${mod}
done
for xry in add-vless del-vless renew-vless cek-vless; do
    curl -sS "${REPO}/xrays/${xry}.sh${CACHE}" -o /usr/bin/${xry} 2>/dev/null && chmod +x /usr/bin/${xry}
done
echo -e "\033[1;32m[OK] Semua berkas berhasil diperbarui!\033[0m"
sleep 1
menu
EOF
chmod +x /usr/bin/update-sc

# Daftarkan Shortcut agar Menu Langsung Tampil Saat Login SSH
if ! grep -q "menu" /root/.bashrc; then
    echo "menu" >> /root/.bashrc
fi

# 11. Restart & Enable Seluruh Service
echo -e "${YELLOW}[8/8] Memulai ulang seluruh layanan service...${NC}"
systemctl daemon-reload
systemctl restart xray nginx fail2ban
systemctl enable xray nginx fail2ban

clear
echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}    INSTALASI CASSANOVA TUNELLING V2 TELAH SELESAI   ${NC}"
echo -e "${GREEN}====================================================${NC}"
echo -e "Domain Server   : ${USER_DOMAIN}"
echo -e "IP Publik VPS   : ${MY_IP}"
echo -e "Port TLS        : 443"
echo -e "Port Nginx Web  : 80"
echo -e "VLESS Path      : /vless"
echo -e "VMess Path      : /vmess"
echo -e "Trojan Path     : /trojan"
echo -e "----------------------------------------------------"
echo -e "Ketik '${CYAN}menu${NC}' untuk membuka dashboard sistem kapan saja."
echo -e "Ketik '${CYAN}update-sc${NC}' jika selesai melakukan commit di GitHub."
echo -e "${GREEN}====================================================${NC}\n"

sleep 2
menu
