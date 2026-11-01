#!/bin/bash
# ==============================================================================
# CASSANOVA TUNNELING V2 - MASTER INSTALLER (BACKEND ONLY)
# Installer ini akan mengunduh tampilan UI & Modul murni dari GitHub Anda.
# ==============================================================================

if [[ $EUID -ne 0 ]]; then
   echo -e "\e[1;31m[ERROR] Script wajib dijalankan sebagai root!\e[0m"
   exit 1
fi

# Dukungan OS: Ubuntu 22.04+ dan Debian 12+ (termasuk rilis mayor berikutnya).
if [[ ! -r /etc/os-release ]]; then
    echo "[ERROR] Tidak dapat membaca /etc/os-release. OS tidak dikenali."
    exit 1
fi
. /etc/os-release
OS_ID="${ID,,}"
OS_VERSION="${VERSION_ID:-0}"
OS_MAJOR="${OS_VERSION%%.*}"
case "$OS_ID" in
    ubuntu)
        OS_MINOR="${OS_VERSION#*.}"
        OS_MINOR="${OS_MINOR%%.*}"
        if [[ ! "$OS_MAJOR" =~ ^[0-9]+$ || ! "$OS_MINOR" =~ ^[0-9]+$ ]] || (( OS_MAJOR < 22 )) || { (( OS_MAJOR == 22 )) && (( 10#$OS_MINOR < 4 )); }; then
            echo "[ERROR] Ubuntu 22.04 atau lebih baru diperlukan. Terdeteksi: $PRETTY_NAME"
            exit 1
        fi
        ;;
    debian)
        if [[ ! "$OS_MAJOR" =~ ^[0-9]+$ ]] || (( OS_MAJOR < 12 )); then
            echo "[ERROR] Debian 12 atau lebih baru diperlukan. Terdeteksi: $PRETTY_NAME"
            exit 1
        fi
        ;;
    *)
        echo "[ERROR] OS tidak didukung: ${PRETTY_NAME:-$OS_ID}. Hanya Ubuntu 22.04+ dan Debian 12+ yang didukung."
        exit 1
        ;;
esac

if ! command -v apt-get >/dev/null 2>&1; then
    echo "[ERROR] apt-get tidak ditemukan. Installer ini khusus Ubuntu/Debian."
    exit 1
fi

NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'
clear
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "        ${GREEN}INSTALASI CASSANOVA TUNNELING V2 (MULTI-PORT)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
read -rp " Masukkan Domain VPS Anda (Kosongkan = Pakai IP): " INPUT_DOM
if [[ -n "$INPUT_DOM" && ! "$INPUT_DOM" =~ ^[A-Za-z0-9.-]+$ ]]; then
    echo "[ERROR] Format domain tidak valid. Gunakan nama domain tanpa skema/port."
    exit 1
fi

# Simpan snapshot konfigurasi yang mungkin disentuh sebelum instalasi.
BACKUP_DIR="/var/backups/cassanova/pre-install-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p -m 0700 "$BACKUP_DIR"
BACKUP_PATHS=()
for path in etc/nginx/nginx.conf etc/nginx/conf.d/xray.conf etc/nginx/conf.d/cassanova-xray.conf \
            etc/xray etc/sing-box usr/local/etc/xray etc/ssh/.ssh.db etc/dropbear \
            etc/apt/keyrings/sagernet.asc etc/apt/sources.list.d/sagernet.sources \
            etc/shells etc/systemd/system/xray.service etc/systemd/system/dropbear.service \
            etc/systemd/system/cassanova-dropbear.service etc/systemd/system/ws-ssh.service \
            etc/systemd/system/bot-tele.service etc/systemd/system/cassanova-bandwidth.service etc/systemd/system/cassanova-bandwidth.timer etc/bot usr/bin/menu usr/bin/m-ssh \
            usr/bin/m-vless usr/bin/m-vmess usr/bin/m-trojan usr/bin/m-hysteria2 \
            usr/bin/m-feature usr/bin/m-bot usr/bin/xray-manager usr/bin/hy2-manager usr/bin/cassanova-service usr/bin/cassanova-bandwidth \
            usr/bin/update-sc usr/bin/cassanova-ssh-expire var/lib/cassanova/bandwidth-xray.json usr/local/bin/bot-tele.py usr/local/share/cassanova root/.bashrc; do
    [[ -e "/$path" || -L "/$path" ]] && BACKUP_PATHS+=("$path")
done
if ((${#BACKUP_PATHS[@]})); then
    tar -czpf "$BACKUP_DIR/pre-install.tar.gz" -C / "${BACKUP_PATHS[@]}" || {
        echo "[ERROR] Gagal membuat snapshot konfigurasi. Instalasi dibatalkan."; exit 1;
    }
    chmod 0600 "$BACKUP_DIR/pre-install.tar.gz"
fi

export DEBIAN_FRONTEND=noninteractive
echo -e "${YELLOW}[1/8] Memperbarui sistem & memasang dependensi...${NC}"
if ! apt-get update -y; then
    echo -e "${RED}[ERROR] apt-get update gagal. Periksa koneksi dan repository OS.${NC}"
    exit 1
fi
if ! apt-get install -y jq curl wget openssl net-tools uuid-runtime vnstat dropbear nginx certbot fail2ban python3 tar gzip cron bc; then
    echo -e "${RED}[ERROR] Instalasi dependensi gagal. Tidak melanjutkan konfigurasi.${NC}"
    exit 1
fi

# Hysteria2 backend: sing-box (official signed APT repository).
echo -e "${YELLOW}[1b/8] Memasang sing-box untuk Hysteria2...${NC}"
install -d -m 0755 /etc/apt/keyrings
if ! curl -fsSL --retry 3 https://sing-box.app/gpg.key -o /etc/apt/keyrings/sagernet.asc; then
    echo -e "${RED}[ERROR] Gagal mengambil signing key resmi sing-box.${NC}"; exit 1
fi
chmod 0644 /etc/apt/keyrings/sagernet.asc
cat > /etc/apt/sources.list.d/sagernet.sources <<'SBOX_REPO'
Types: deb
URIs: https://deb.sagernet.org/
Suites: *
Components: *
Enabled: yes
Signed-By: /etc/apt/keyrings/sagernet.asc
SBOX_REPO
if ! apt-get update -y || ! apt-get install -y sing-box; then
    echo -e "${RED}[ERROR] Instalasi sing-box gagal. Hysteria2 tidak dapat diaktifkan.${NC}"; exit 1
fi
command -v sing-box >/dev/null 2>&1 || { echo "[ERROR] Binary sing-box tidak ditemukan."; exit 1; }

mkdir -p /etc/xray/limit/ip /etc/xray/limit/bw /var/log/xray /usr/local/etc/xray /etc/ssh /etc/bot /etc/dropbear /usr/bin
touch /etc/xray/vless.db /etc/xray/vmess.db /etc/xray/trojan.db /etc/ssh/.ssh.db
if ! getent group sing-box >/dev/null 2>&1; then groupadd --system sing-box; fi
if ! getent passwd sing-box >/dev/null 2>&1; then
    useradd --system --gid sing-box --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin sing-box
fi
install -d -o root -g sing-box -m 0750 /etc/sing-box /var/backups/cassanova/hysteria2
if [[ ! -s /etc/sing-box/users.json ]]; then printf '[]\n' > /etc/sing-box/users.json; fi
chown root:root /etc/sing-box/users.json; chmod 0600 /etc/sing-box/users.json
if [[ ! -s /etc/sing-box/config.json ]]; then
    cat > /etc/sing-box/config.json <<'SBOX_EMPTY'
{
  "log": { "level": "warn" },
  "inbounds": [],
  "outbounds": [{ "type": "direct", "tag": "direct" }]
}
SBOX_EMPTY
fi
chown root:sing-box /etc/sing-box/config.json; chmod 0640 /etc/sing-box/config.json
touch /var/log/xray/access.log /var/log/xray/error.log
chmod 750 /var/log/xray
chmod 640 /var/log/xray/access.log /var/log/xray/error.log

MY_IP=$(curl -sS --max-time 5 https://ipv4.icanhazip.com || echo "127.0.0.1")
DOMAIN="${INPUT_DOM:-$MY_IP}"
echo "$DOMAIN" > /etc/xray/domain.txt
echo "$DOMAIN" > /etc/xray/sni.txt
echo "POTATO TUNNELING" > /etc/xray/brand.txt

echo -e "${YELLOW}[2/8] Menyiapkan SSL & Instalasi Xray-Core...${NC}"
if [[ "$DOMAIN" != "$MY_IP" && "$DOMAIN" != "127.0.0.1" ]] && ! ss -ltnH '( sport = :80 )' | grep -q .; then
    certbot certonly --standalone --agree-tos --register-unsafely-without-email -d "$DOMAIN" --non-interactive 2>/dev/null || true
fi
if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" /etc/xray/xray.crt
    cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" /etc/xray/xray.key
else
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/xray/xray.key -out /etc/xray/xray.crt -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Cassanova/CN=${DOMAIN}" >/dev/null 2>&1
fi
chmod 644 /etc/xray/xray.crt
chmod 600 /etc/xray/xray.key
chown root:root /etc/xray/xray.crt /etc/xray/xray.key

if ! command -v xray >/dev/null 2>&1; then
    XRAY_INSTALLER=$(mktemp)
    if ! curl -fL --retry 3 --connect-timeout 15 https://github.com/XTLS/Xray-install/raw/main/install-release.sh -o "$XRAY_INSTALLER"; then
        rm -f "$XRAY_INSTALLER"
        echo -e "${RED}[ERROR] Gagal mengunduh installer Xray.${NC}"
        exit 1
    fi
    if ! bash "$XRAY_INSTALLER" install; then
        rm -f "$XRAY_INSTALLER"
        echo -e "${RED}[ERROR] Instalasi Xray gagal.${NC}"
        exit 1
    fi
    rm -f "$XRAY_INSTALLER"
fi
if ! command -v xray >/dev/null 2>&1; then
    echo -e "${RED}[ERROR] Binary Xray tidak ditemukan setelah instalasi.${NC}"
    exit 1
fi

cat << 'XCFG' > /usr/local/etc/xray/config.json
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "api": { "tag": "api", "services": ["HandlerService", "StatsService"] },
  "stats": {},
  "policy": { "levels": { "0": { "statsUserUplink": true, "statsUserDownlink": true } } },
  "inbounds": [
    { "tag": "api-in", "listen": "127.0.0.1", "port": 10085, "protocol": "dokodemo-door", "settings": { "address": "127.0.0.1" } },
    { "tag": "vless-ws", "port": 10001, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vless" } } },
    { "tag": "vmess-ws", "port": 10002, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/vmess" } } },
    { "tag": "trojan-ws", "port": 10003, "listen": "127.0.0.1", "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "ws", "wsSettings": { "path": "/trojan" } } },
    { "tag": "vless-grpc", "port": 10004, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vless-grpc" } } },
    { "tag": "vmess-grpc", "port": 10005, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "vmess-grpc" } } },
    { "tag": "trojan-grpc", "port": 10006, "listen": "127.0.0.1", "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "grpc", "grpcSettings": { "serviceName": "trojan-grpc" } } },
    { "tag": "vless-up", "port": 10007, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/upvless" } } },
    { "tag": "vmess-up", "port": 10008, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/upvmess" } } },
    { "tag": "trojan-up", "port": 10009, "listen": "127.0.0.1", "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "httpupgrade", "httpupgradeSettings": { "path": "/uptrojan" } } },
    { "tag": "vless-xh", "port": 10010, "listen": "127.0.0.1", "protocol": "vless", "settings": { "clients": [], "decryption": "none" }, "streamSettings": { "network": "xhttp", "xhttpSettings": { "path": "/xhvless" } } },
    { "tag": "vmess-xh", "port": 10011, "listen": "127.0.0.1", "protocol": "vmess", "settings": { "clients": [] }, "streamSettings": { "network": "xhttp", "xhttpSettings": { "path": "/xhvmess" } } },
    { "tag": "trojan-xh", "port": 10012, "listen": "127.0.0.1", "protocol": "trojan", "settings": { "clients": [] }, "streamSettings": { "network": "xhttp", "xhttpSettings": { "path": "/xhtrojan" } } }
  ],
  "outbounds": [ { "protocol": "freedom", "tag": "direct" }, { "protocol": "blackhole", "tag": "blocked" }, { "protocol": "freedom", "tag": "api" } ],
  "routing": { "rules": [ { "type": "field", "inboundTag": ["api-in"], "outboundTag": "api" } ] }
}
XCFG

XRAY_BIN=$(command -v xray || echo "/usr/local/bin/xray")
cat << SVC > /etc/systemd/system/xray.service
[Unit]
Description=Xray Service
After=network.target nss-lookup.target
[Service]
User=root
ExecStart=${XRAY_BIN} run -config /usr/local/etc/xray/config.json
Restart=on-failure
LimitNOFILE=1000000
[Install]
WantedBy=multi-user.target
SVC

echo -e "${YELLOW}[3/8] Mengonfigurasi Nginx Reverse Proxy (Multi-Port)...${NC}"
# Jangan menimpa nginx.conf atau konfigurasi situs milik administrator.
# Cassanova hanya memasang satu drop-in yang menjadi miliknya sendiri.
NGINX_PANEL_CONF="/etc/nginx/conf.d/cassanova-xray.conf"
cat << 'NCFG' > "$NGINX_PANEL_CONF"
server {
    listen 80;
    listen [::]:80;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    listen 2096 ssl http2;
    listen [::]:2096 ssl http2;
    server_name _;
    ssl_certificate /etc/xray/xray.crt;
    ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;

    location / { default_type text/html; return 200 "<h1>CASSANOVA ENGINE ACTIVE</h1>"; }
    location = /vless { proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location = /vmess { proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location = /trojan { proxy_pass http://127.0.0.1:10003; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location ^~ /vless-grpc { grpc_pass grpc://127.0.0.1:10004; grpc_set_header Host $http_host; grpc_read_timeout 86400s; }
    location ^~ /vmess-grpc { grpc_pass grpc://127.0.0.1:10005; grpc_set_header Host $http_host; grpc_read_timeout 86400s; }
    location ^~ /trojan-grpc { grpc_pass grpc://127.0.0.1:10006; grpc_set_header Host $http_host; grpc_read_timeout 86400s; }
    location ^~ /upvless { proxy_pass http://127.0.0.1:10007; proxy_http_version 1.1; proxy_buffering off; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location ^~ /upvmess { proxy_pass http://127.0.0.1:10008; proxy_http_version 1.1; proxy_buffering off; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location ^~ /uptrojan { proxy_pass http://127.0.0.1:10009; proxy_http_version 1.1; proxy_buffering off; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location ^~ /xhvless { proxy_pass http://127.0.0.1:10010; proxy_http_version 1.1; proxy_buffering off; proxy_request_buffering off; proxy_set_header Connection ""; proxy_set_header Host $host; }
    location ^~ /xhvmess { proxy_pass http://127.0.0.1:10011; proxy_http_version 1.1; proxy_buffering off; proxy_request_buffering off; proxy_set_header Connection ""; proxy_set_header Host $host; }
    location ^~ /xhtrojan { proxy_pass http://127.0.0.1:10012; proxy_http_version 1.1; proxy_buffering off; proxy_request_buffering off; proxy_set_header Connection ""; proxy_set_header Host $host; }
}
NCFG
if [[ "$DOMAIN" =~ ^[A-Za-z0-9.-]+$ ]]; then
    sed -i "s/server_name _;/server_name ${DOMAIN};/" "$NGINX_PANEL_CONF"
fi
if ! nginx -t; then
    echo "[ERROR] Konfigurasi Nginx tidak valid. File konfigurasi lain tidak disentuh. Periksa $NGINX_PANEL_CONF dan snapshot $BACKUP_DIR."
    exit 1
fi

echo -e "${YELLOW}[4/8] Membangun Engine Sentral (Backend)...${NC}"

echo -e "${YELLOW}[5/8] Menyiapkan Dropbear & Python WS-SSH...${NC}"
[[ ! -f /etc/dropbear/dropbear_rsa_host_key ]] && dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1
cat << 'DB_SVC' > /etc/systemd/system/cassanova-dropbear.service
[Unit]
Description=Cassanova Dropbear SSH
After=network.target
[Service]
Type=simple
ExecStart=/usr/sbin/dropbear -F -E -p 143 -p 109
Restart=on-failure
RestartSec=3
[Install]
WantedBy=multi-user.target
DB_SVC
grep -qxF "/bin/false" /etc/shells || echo "/bin/false" >> /etc/shells

# SSH-over-WebSocket custom proxy sengaja tidak dipasang: implementasi lama
# tidak melakukan WebSocket handshake/frame handling dengan benar.
# SSH biasa tetap tersedia melalui OpenSSH dan Dropbear.

echo -e "${YELLOW}[6/8] Menyiapkan housekeeping aman...${NC}"
# Auto-kill/IP-limit Xray versi lama dinonaktifkan karena format database
# dan enforcement-nya tidak aman. Crontab administrator tidak disentuh.

echo -e "${YELLOW}[7/8] Mengunduh UI Menu & Bot Telegram dari GitHub Anda...${NC}"
REPO="https://raw.githubusercontent.com/amiercassanova-21/sc-tunnel/r6-testing"
STAGE=$(mktemp -d)
cleanup_stage() { rm -rf "$STAGE"; }
trap cleanup_stage EXIT
FILES=(
    "VERSION:/usr/local/share/cassanova/VERSION"
    "menu.sh:/usr/bin/menu"
    "modules/m-vless.sh:/usr/bin/m-vless"
    "modules/m-vmess.sh:/usr/bin/m-vmess"
    "modules/m-trojan.sh:/usr/bin/m-trojan"
    "modules/xray-manager.sh:/usr/bin/xray-manager"
    "modules/cassanova-notify.py:/usr/local/bin/cassanova-notify.py"
    "modules/cassanova-bandwidth.py:/usr/bin/cassanova-bandwidth"
    "modules/cassanova-expire.sh:/usr/bin/cassanova-expire"
    "modules/cassanova-ssh-expire.sh:/usr/bin/cassanova-ssh-expire"
    "modules/hy2-manager.sh:/usr/bin/hy2-manager"
    "modules/m-hysteria2.sh:/usr/bin/m-hysteria2"
    "install-hysteria2.sh:/usr/bin/install-hysteria2"
    "modules/m-ssh.sh:/usr/bin/m-ssh"
    "modules/m-feature.sh:/usr/bin/m-feature"
    "modules/m-bot.sh:/usr/bin/m-bot"
    "modules/cassanova-backup.sh:/usr/bin/cassanova-backup"
    "modules/cassanova-restore.sh:/usr/bin/cassanova-restore"
    "modules/cassanova-service.sh:/usr/bin/cassanova-service"
    "bot-tele.py:/usr/local/bin/bot-tele.py"
    "update.sh:/usr/bin/update-sc"
)
install -d -m 0755 /usr/local/share/cassanova
for ITEM in "${FILES[@]}"; do
    SRC="${ITEM%%:*}"
    DEST="${ITEM#*:}"
    if ! curl -fsSL --retry 3 --connect-timeout 15 "${REPO}/${SRC}" -o "${STAGE}/$(basename "$DEST")"; then
        echo -e "${RED}[ERROR] Gagal mengunduh ${SRC}; file sistem tidak akan diperbarui.${NC}"
        exit 1
    fi
    if [[ ! -s "${STAGE}/$(basename "$DEST")" ]]; then
        echo -e "${RED}[ERROR] File ${SRC} kosong; membatalkan instalasi.${NC}"
        exit 1
    fi
    if [[ "$SRC" == *.sh ]] && ! bash -n "${STAGE}/$(basename "$DEST")"; then
        echo -e "${RED}[ERROR] Sintaks shell tidak valid: ${SRC}${NC}"
        exit 1
    fi
    if [[ "$SRC" == *.py ]] && ! python3 -m py_compile "${STAGE}/$(basename "$DEST")"; then
        echo -e "${RED}[ERROR] Sintaks Python tidak valid: ${SRC}${NC}"
        exit 1
    fi
done
for ITEM in "${FILES[@]}"; do
    DEST="${ITEM#*:}"
    install -D -m 0755 "${STAGE}/$(basename "$DEST")" "$DEST"
done
chmod 0644 /usr/local/bin/bot-tele.py /usr/local/bin/cassanova-notify.py /usr/local/share/cassanova/VERSION

cat << 'EXP_SVC' > /etc/systemd/system/cassanova-expire.service
[Unit]
Description=Cassanova Xray Account Expiry Reconciliation
After=network.target xray.service

[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/cassanova-expire
UMask=0077

[Install]
WantedBy=multi-user.target
EXP_SVC

cat << 'EXP_TIMER' > /etc/systemd/system/cassanova-expire.timer
[Unit]
Description=Daily Cassanova Xray Account Expiry Check

[Timer]
OnCalendar=*-*-* 00:15:00
RandomizedDelaySec=300
Persistent=true
Unit=cassanova-expire.service

[Install]
WantedBy=timers.target
EXP_TIMER

cat << 'BW_SVC' > /etc/systemd/system/cassanova-bandwidth.service
[Unit]
Description=Cassanova Xray Per-User Bandwidth Enforcement
After=network.target xray.service

[Service]
Type=oneshot
User=root
ExecStart=/usr/bin/cassanova-bandwidth
UMask=0077

BW_SVC

cat << 'BW_TIMER' > /etc/systemd/system/cassanova-bandwidth.timer
[Unit]
Description=Run Cassanova Xray bandwidth enforcement every minute

[Timer]
OnBootSec=2min
OnUnitActiveSec=60s
AccuracySec=10s
Persistent=true
Unit=cassanova-bandwidth.service

[Install]
WantedBy=timers.target
BW_TIMER

cat << 'BOT_SVC' > /etc/systemd/system/bot-tele.service
[Unit]
Description=Cassanova Telegram Bot Panel
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/python3 /usr/local/bin/bot-tele.py
Restart=always
RestartSec=5
UMask=0077

[Install]
WantedBy=multi-user.target
BOT_SVC

BASHRC_MARKER="# >>> CASSANOVA TUNNELING V2 >>>"
if ! grep -Fq "$BASHRC_MARKER" /root/.bashrc 2>/dev/null; then
    cat << 'BRC_EOF' >> /root/.bashrc

# >>> CASSANOVA TUNNELING V2 >>>
case $- in *i*) ;; *) return;; esac
if [[ -x /usr/bin/menu && -z "${CASSANOVA_MENU_DISABLED:-}" ]]; then /usr/bin/menu; fi
# <<< CASSANOVA TUNNELING V2 <<<
BRC_EOF
fi

echo -e "${YELLOW}[8/8] Validasi konfigurasi dan memulai layanan...${NC}"
if ! xray run -test -config /usr/local/etc/xray/config.json; then
    echo -e "${RED}[ERROR] Konfigurasi Xray tidak valid. Layanan tidak akan direstart.${NC}"
    echo "Snapshot pra-instalasi: $BACKUP_DIR"
    exit 1
fi
if ! nginx -t; then
    echo -e "${RED}[ERROR] Konfigurasi Nginx tidak valid. Layanan tidak akan direstart.${NC}"
    echo "Snapshot pra-instalasi: $BACKUP_DIR"
    exit 1
fi
if ! sing-box check -c /etc/sing-box/config.json; then
    echo -e "${RED}[ERROR] Konfigurasi sing-box tidak valid. Layanan tidak akan direstart.${NC}"
    echo "Snapshot pra-instalasi: $BACKUP_DIR"
    exit 1
fi
systemctl daemon-reload
for svc in xray nginx cassanova-dropbear fail2ban vnstat sing-box; do
    if ! systemctl enable "$svc" >/dev/null 2>&1; then
        echo "[ERROR] Gagal mengaktifkan service $svc. Snapshot: $BACKUP_DIR"
        exit 1
    fi
    if ! systemctl restart "$svc" || ! systemctl is-active --quiet "$svc"; then
        echo "[ERROR] Service $svc gagal berjalan. Detail: systemctl status $svc"
        systemctl status "$svc" --no-pager || true
        echo "Snapshot pra-instalasi: $BACKUP_DIR"
        exit 1
    fi
done
systemctl enable --now cassanova-expire.timer >/dev/null 2>&1 || echo "[WARN] Timer expiry belum dapat diaktifkan. Periksa systemctl status cassanova-expire.timer."
systemctl daemon-reload
if jq -e '((.api.services // []) | index("StatsService") != null) and any(.inbounds[]?; .tag == "api-in" and .port == 10085) and any(.routing.rules[]?; ((.inboundTag // []) | index("api-in") != null) and .outboundTag == "api")' /usr/local/etc/xray/config.json >/dev/null 2>&1; then systemctl enable --now cassanova-bandwidth.timer >/dev/null 2>&1 || echo "[WARN] Timer bandwidth belum dapat diaktifkan. Periksa systemctl status cassanova-bandwidth.timer."; fi
# Bot opsional sampai token dan admin dikonfigurasi.
if [[ -s /etc/bot/token && -s /etc/bot/admin ]]; then
    systemctl enable bot-tele >/dev/null 2>&1 || true
    if ! systemctl restart bot-tele; then
        echo "[WARN] Telegram Bot gagal start; engine protokol utama tetap berjalan."
    fi
fi

echo -e "${GREEN}====================================================${NC}"
echo -e "${GREEN}[OK] Instalasi Cassanova Tunneling selesai.${NC}"
echo -e "${YELLOW}Snapshot pra-instalasi: ${BACKUP_DIR}${NC}"
echo -e "${YELLOW}SSH-over-WebSocket dan Xray auto-kill dinonaktifkan sampai implementasinya tervalidasi.${NC}"
echo -e "${GREEN}====================================================${NC}"
