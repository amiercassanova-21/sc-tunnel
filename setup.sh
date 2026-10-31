#!/bin/bash
# ==============================================================================
# CASSANOVA TUNNELING V2 - ULTIMATE AUTO-INSTALLER (FULL CODE)
# OS Support: Ubuntu 20.04/22.04/24.04 & Debian 11/12
# ==============================================================================

# Memastikan dijalankan sebagai root
if [[ $EUID -ne 0 ]]; then
   echo -e "\e[1;31m[ERROR] Script wajib dijalankan sebagai root!\e[0m"
   exit 1
fi

NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; CYAN='\e[1;36m'; MAGENTA='\e[1;35m'
clear
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "        ${GREEN}INSTALASI CASSANOVA TUNNELING V2 (MULTI-PORT)${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
read -rp " Masukkan Domain VPS Anda (Kosongkan = Pakai IP): " INPUT_DOM

export DEBIAN_FRONTEND=noninteractive
echo -e "${YELLOW}[1/8] Memperbarui sistem & memasang dependensi...${NC}"
apt-get update -y >/dev/null 2>&1
apt-get install -y jq curl wget openssl net-tools uuid-runtime vnstat dropbear nginx certbot fail2ban python3 tar gzip cron bc >/dev/null 2>&1

mkdir -p /etc/xray/limit/ip /etc/xray/limit/bw /etc/xray/usage /var/log/xray /usr/local/etc/xray /etc/ssh /etc/bot /etc/dropbear /usr/bin
touch /etc/xray/vless.db /etc/xray/vmess.db /etc/xray/trojan.db /etc/ssh/.ssh.db
touch /var/log/xray/access.log /var/log/xray/error.log
chmod -R 777 /var/log/xray

MY_IP=$(curl -sS --max-time 5 https://ipv4.icanhazip.com || echo "127.0.0.1")
DOMAIN="${INPUT_DOM:-$MY_IP}"
echo "$DOMAIN" > /etc/xray/domain.txt
echo "$DOMAIN" > /etc/xray/sni.txt
echo "POTATO TUNNELING" > /etc/xray/brand.txt

echo -e "${YELLOW}[2/8] Menyiapkan SSL & Instalasi Xray-Core...${NC}"
systemctl stop nginx 2>/dev/null || true
if [[ "$DOMAIN" != "$MY_IP" ]]; then
    certbot certonly --standalone --agree-tos --register-unsafely-without-email -d "$DOMAIN" --non-interactive 2>/dev/null || true
fi
if [[ -f "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" ]]; then
    cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" /etc/xray/xray.crt
    cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" /etc/xray/xray.key
else
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/xray/xray.key -out /etc/xray/xray.crt -subj "/C=ID/ST=Jakarta/L=Jakarta/O=Cassanova/CN=${DOMAIN}" >/dev/null 2>&1
fi
chmod 644 /etc/xray/xray.crt /etc/xray/xray.key

if ! command -v xray >/dev/null 2>&1; then
    bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install >/dev/null 2>&1
fi

cat << 'XCFG' > /usr/local/etc/xray/config.json
{
  "log": { "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log", "loglevel": "warning" },
  "inbounds": [
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
  "outbounds": [ { "protocol": "freedom", "tag": "direct" }, { "protocol": "blackhole", "tag": "blocked" } ]
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

echo -e "${YELLOW}[3/8] Mengonfigurasi Nginx Reverse Proxy (Multi-Port 80, 443, 2096)...${NC}"
cat << 'NGNX' > /etc/nginx/nginx.conf
user www-data;
worker_processes auto;
pid /run/nginx.pid;
include /etc/nginx/modules-enabled/*.conf;
events { worker_connections 4096; multi_accept on; }
http {
    sendfile on; tcp_nopush on; tcp_nodelay on; keepalive_timeout 65; types_hash_max_size 2048; client_max_body_size 0;
    include /etc/nginx/mime.types; default_type application/octet-stream;
    map $http_upgrade$connection_upgrade { default upgrade; '' close; }
    include /etc/nginx/conf.d/*.conf;
}
NGNX
rm -f /etc/nginx/sites-enabled/* /etc/nginx/conf.d/*.conf
cat << 'NCFG' > /etc/nginx/conf.d/xray.conf
server {
    listen 80 default_server; listen [::]:80 default_server;
    listen 443 ssl http2 default_server; listen [::]:443 ssl http2 default_server;
    listen 2096 ssl http2 default_server; listen [::]:2096 ssl http2 default_server;
    server_name _;
    ssl_certificate /etc/xray/xray.crt; ssl_certificate_key /etc/xray/xray.key;
    ssl_protocols TLSv1.2 TLSv1.3; ssl_ciphers HIGH:!aNULL:!MD5;
    
    location / {
        if ($http_upgrade ~* "websocket") { proxy_pass http://127.0.0.1:10015; break; }
        default_type text/html; return 200 "<h1>CASSANOVA ENGINE ACTIVE</h1>";
    }
    location = /vless { proxy_redirect off; proxy_pass http://127.0.0.1:10001; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location = /vmess { proxy_redirect off; proxy_pass http://127.0.0.1:10002; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location = /trojan { proxy_redirect off; proxy_pass http://127.0.0.1:10003; proxy_http_version 1.1; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location ^~ /vless-grpc { proxy_redirect off; grpc_pass grpc://127.0.0.1:10004; grpc_set_header Host $http_host; grpc_read_timeout 86400s; }
    location ^~ /vmess-grpc { proxy_redirect off; grpc_pass grpc://127.0.0.1:10005; grpc_set_header Host $http_host; grpc_read_timeout 86400s; }
    location ^~ /trojan-grpc { proxy_redirect off; grpc_pass grpc://127.0.0.1:10006; grpc_set_header Host $http_host; grpc_read_timeout 86400s; }
    location ^~ /upvless { proxy_redirect off; proxy_pass http://127.0.0.1:10007; proxy_http_version 1.1; proxy_buffering off; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location ^~ /upvmess { proxy_redirect off; proxy_pass http://127.0.0.1:10008; proxy_http_version 1.1; proxy_buffering off; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location ^~ /uptrojan { proxy_redirect off; proxy_pass http://127.0.0.1:10009; proxy_http_version 1.1; proxy_buffering off; proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade"; proxy_set_header Host $host; }
    location ^~ /xhvless { proxy_redirect off; proxy_pass http://127.0.0.1:10010; proxy_http_version 1.1; proxy_buffering off; proxy_request_buffering off; proxy_set_header Connection ""; proxy_set_header Host $host; }
    location ^~ /xhvmess { proxy_redirect off; proxy_pass http://127.0.0.1:10011; proxy_http_version 1.1; proxy_buffering off; proxy_request_buffering off; proxy_set_header Connection ""; proxy_set_header Host $host; }
    location ^~ /xhtrojan { proxy_redirect off; proxy_pass http://127.0.0.1:10012; proxy_http_version 1.1; proxy_buffering off; proxy_request_buffering off; proxy_set_header Connection ""; proxy_set_header Host $host; }
}
NCFG
if ! nginx -t >/dev/null 2>&1; then sed -i 's/http2 //g' /etc/nginx/conf.d/xray.conf; fi

echo -e "${YELLOW}[4/8] Membangun Engine Sentral Xray-Manager...${NC}"
cat << 'XMGR_EOF' > /usr/bin/xray-manager
#!/bin/bash
PROTO="$1"; ACTION="$2"; UPPER_PROTO=$(echo "$PROTO" | tr 'a-z' 'A-Z')
DB_FILE="/etc/xray/${PROTO}.db"; CONFIG="/usr/local/etc/xray/config.json"
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; CYAN='\e[1;36m'

inject_user() {
    local tmp=$(mktemp)
    if [[ "$PROTO" == "trojan" ]]; then
        jq --arg p "$PROTO" --arg pw "$2" --arg u "$1" '(.inbounds[] | select(.protocol==$p) | .settings.clients) |= map(select(.email != $u)) | (.inbounds[] | select(.protocol==$p) | .settings.clients) += [{"password": $pw, "email": $u}]' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
    else
        jq --arg p "$PROTO" --arg id "$2" --arg u "$1" '(.inbounds[] | select(.protocol==$p) | .settings.clients) |= map(select(.email != $u)) | (.inbounds[] | select(.protocol==$p) | .settings.clients) += [{"id": $id, "email": $u}]' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
    fi
}
remove_user() {
    local tmp=$(mktemp)
    jq --arg p "$PROTO" --arg u "$1" '(.inbounds[] | select(.protocol==$p) | .settings.clients) |= map(select(.email != $u))' "$CONFIG" > "$tmp" && mv "$tmp" "$CONFIG"
}
print_6_links() {
    local user="$1"; local cred="$2"; local exp="$3"; local days="$4"
    local domain=$(cat /etc/xray/domain.txt 2>/dev/null); local sni=$(cat /etc/xray/sni.txt 2>/dev/null); [[ -z "$sni" ]] && sni="$domain"
    local lim=$(cat "/etc/xray/limit/ip/${PROTO}_${user}" 2>/dev/null || echo "2"); local bw=$(cat "/etc/xray/limit/bw/${PROTO}_${user}" 2>/dev/null || echo "0")
    local ip_lbl="$lim"; [[ "$lim" == "0" ]] && ip_lbl="Unli"
    local bw_lbl="${bw} GB"; [[ "$bw" == "0" ]] && bw_lbl="Unlimited"
    local rem="${user}%E3%80%8A${ip_lbl}%E3%80%8B%F0%9F%94%B5"
    if [[ "$PROTO" == "vless" ]]; then
        LT="vless://${cred}@${domain}:443?path=%2Fvless&security=tls&encryption=none&host=${sni}&type=ws&sni=${sni}#${rem}"
        LNT="vless://${cred}@${domain}:80?path=%2Fvless&security=none&encryption=none&host=${sni}&type=ws#${rem}"
        LG="vless://${cred}@${domain}:443?mode=gun&security=tls&encryption=none&type=grpc&serviceName=vless-grpc&sni=${sni}#${rem}"
        LU="vless://${cred}@${domain}:443?path=%2Fupvless&security=tls&encryption=none&host=${sni}&type=httpupgrade&sni=${sni}#${rem}"
        LX="vless://${cred}@${domain}:2096?path=%2Fxhvless&security=tls&encryption=none&host=${sni}&type=xhttp&fp=chrome&sni=${sni}#${rem}"
    elif [[ "$PROTO" == "trojan" ]]; then
        LT="trojan://${cred}@${domain}:443?path=%2Ftrojan&security=tls&host=${sni}&type=ws&sni=${sni}#${rem}"
        LNT="trojan://${cred}@${domain}:80?path=%2Ftrojan&security=none&host=${sni}&type=ws#${rem}"
        LG="trojan://${cred}@${domain}:443?mode=gun&security=tls&type=grpc&serviceName=trojan-grpc&sni=${sni}#${rem}"
        LU="trojan://${cred}@${domain}:443?path=%2Fuptrojan&security=tls&host=${sni}&type=httpupgrade&sni=${sni}#${rem}"
        LX="trojan://${cred}@${domain}:2096?path=%2Fxhtrojan&security=tls&host=${sni}&type=xhttp&fp=chrome&sni=${sni}#${rem}"
    else
        local rp="${user}《${ip_lbl}》🔵"; local b64="base64 -w 0"
        LT="vmess://$(jq -n --arg ps "$rp" --arg add "$domain" --arg id "$cred" --arg h "$sni" '{v:"2",ps:$ps,add:$add,port:"443",id:$id,aid:"0",scy:"auto",net:"ws",type:"none",host:$h,path:"/vmess",tls:"tls",sni:$h}' | $b64)"
        LNT="vmess://$(jq -n --arg ps "$rp" --arg add "$domain" --arg id "$cred" --arg h "$sni" '{v:"2",ps:$ps,add:$add,port:"80",id:$id,aid:"0",scy:"auto",net:"ws",type:"none",host:$h,path:"/vmess",tls:"none"}' | $b64)"
        LG="vmess://$(jq -n --arg ps "$rp" --arg add "$domain" --arg id "$cred" --arg h "$sni" '{v:"2",ps:$ps,add:$add,port:"443",id:$id,aid:"0",scy:"auto",net:"grpc",type:"gun",host:$h,path:"vmess-grpc",tls:"tls",sni:$h}' | $b64)"
        LU="vmess://$(jq -n --arg ps "$rp" --arg add "$domain" --arg id "$cred" --arg h "$sni" '{v:"2",ps:$ps,add:$add,port:"443",id:$id,aid:"0",scy:"auto",net:"httpupgrade",type:"none",host:$h,path:"/upvmess",tls:"tls",sni:$h}' | $b64)"
        LX="vmess://$(jq -n --arg ps "$rp" --arg add "$domain" --arg id "$cred" --arg h "$sni" '{v:"2",ps:$ps,add:$add,port:"2096",id:$id,aid:"0",scy:"auto",net:"xhttp",type:"none",host:$h,path:"/xhvmess",tls:"tls",sni:$h,fp:"chrome"}' | $b64)"
    fi
    clear
    echo -e "             ${GREEN}${UPPER_PROTO}${NC}\n ${BLUE}────────────────────────────────${NC}"
    echo -e " Remarks      : ${CYAN}${user}${NC}\n Host / SNI   : ${GREEN}${sni}${NC}\n UUID / Pass  : ${YELLOW}${cred}${NC}"
    echo -e " Limit        : ${CYAN}${ip_lbl} IP${NC} | Quota: ${CYAN}${bw_lbl}${NC}\n Expired      : ${RED}${exp}${NC} (${days})\n ${BLUE}────────────────────────────────${NC}"
    echo -e " ${YELLOW}WS TLS${NC}:\n${LT}\n ${BLUE}────────────────────────────────${NC}"
    echo -e " ${YELLOW}WS NON-TLS${NC}:\n${LNT}\n ${BLUE}────────────────────────────────${NC}"
    echo -e " ${YELLOW}GRPC${NC}:\n${LG}\n ${BLUE}────────────────────────────────${NC}"
    echo -e " ${YELLOW}HTTP UPGRADE${NC}:\n${LU}\n ${BLUE}────────────────────────────────${NC}"
    echo -e " ${YELLOW}XHTTP${NC}:\n${LX}\n ${BLUE}────────────────────────────────${NC}"
}
case "$ACTION" in
    create|custom)
        read -rp " Username : " U; U=$(echo "$U"|tr -d '[:space:]'); grep -q "^### ${U} " "$DB_FILE" && exit 1
        if [[ "$ACTION" == "custom" ]]; then
            read -rp " Custom UUID/Pass : " C; C=$(echo "$C"|tr -d '[:space:]')
            [[ -z "$C" ]] && C=$(cat /proc/sys/kernel/random/uuid)
            [[ "$PROTO" != "trojan" && ! "$C" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]] && C=$(uuidgen --sha1 --namespace @dns --name "$C" 2>/dev/null)
        else
            C=$(cat /proc/sys/kernel/random/uuid)
        fi
        read -rp " Hari : " D; read -rp " Limit IP (0=Unli) : " LIM; read -rp " Limit GB (0=Unli) : " BW
        [[ ! "$D" =~ ^[0-9]+$ ]] && D=30; [[ ! "$LIM" =~ ^[0-9]+$ ]] && LIM=2; [[ ! "$BW" =~ ^[0-9]+$ ]] && BW=0
        E=$(date -d "+${D} days" +"%Y-%m-%d")
        echo "$LIM" > "/etc/xray/limit/ip/${PROTO}_${U}"; echo "$BW" > "/etc/xray/limit/bw/${PROTO}_${U}"
        inject_user "$U" "$C"; echo "### $U $E $C unlocked" >> "$DB_FILE"; systemctl restart xray
        print_6_links "$U" "$C" "$E" "${D} Days"; read -n1 -srp "Enter..."
        ;;
    delete|renew|modify|check-config)
        grep -E "^### " "$DB_FILE" | awk '{print $2, $3, $5}' | nl -s ') '
        read -rp " Input Username/No: " IN_U
        [[ "$IN_U" =~ ^[0-9]+$]] && U=$(grep -E "^### " "$DB_FILE" | sed -n "${IN_U}p" | awk '{print $2}') || U="$IN_U"
        DATA=$(grep -E "^### ${U} " "$DB_FILE"); [[ -z "$DATA" ]] && exit 1
        E=$(echo "$DATA" | awk '{print $3}'); C=$(echo "$DATA" | awk '{print $4}'); ST=$(echo "$DATA" | awk '{print $5}')
        if [[ "$ACTION" == "delete" ]]; then
            sed -i "/^### ${U} /d" "$DB_FILE"; remove_user "$U"; systemctl restart xray; echo -e "${GREEN}Deleted!${NC}"; sleep 1
        elif [[ "$ACTION" == "renew" ]]; then
            read -rp " Tambah Hari: " D; [[ ! "$D" =~ ^[0-9]+$ ]] && D=30
            NOW=$(date +%s); EXP=$(date -d "$E" +%s 2>/dev/null || echo "$NOW"); [[ "$NOW" -gt "$EXP" ]] && BASE=$NOW || BASE=$EXP
            NEW_E=$(date -d "@$((BASE + D * 86400))" +"%Y-%m-%d")
            sed -i "/^### ${U} /d" "$DB_FILE"; echo "### $U $NEW_E$C ${ST:-unlocked}" >> "$DB_FILE"; echo -e "${GREEN}Renewed!${NC}"; sleep 1
        elif [[ "$ACTION" == "modify" ]]; then
            read -rp " New UUID/Pass: " C
            sed -i "/^### ${U} /d" "$DB_FILE"; echo "### $U $E$C ${ST:-unlocked}" >> "$DB_FILE"; inject_user "$U" "$C"; systemctl restart xray; echo -e "${GREEN}Modified!${NC}"; sleep 1
        else
            print_6_links "$U" "$C" "$E" "${ST:-Active}"; read -n1 -srp "Enter..."
        fi
        ;;
    list|cek-login)
        printf "  %-4s %-14s %-12s %-10s\n" "NO" "USERNAME" "STATUS/ONLINE" "LIMIT IP"
        i=1
        while read -r line; do
            U=$(echo "$line" | awk '{print $2}'); ST=$(echo "$line" | awk '{print $5}')
            LIM=$(cat "/etc/xray/limit/ip/${PROTO}_${U}" 2>/dev/null || echo "2"); [[ "$LIM" == "0" ]] && L="Unli" || L="${LIM} IP"
            if [[ "$ACTION" == "cek-login" ]]; then
                CNT=$(tail -n 500 /var/log/xray/access.log 2>/dev/null | grep -w "email: $U" | awk '{print $3}' | cut -d: -f1 | sort -u | wc -l)
                [[ "$CNT" -gt 0 ]] && printf "  %-4s %-14s %-12s %-10s\n" "${i})" "$U" "${CNT} IP" "$L"
            else
                printf "  %-4s %-14s %-12s %-10s\n" "${i})" "$U" "${ST:-unlocked}" "$L"
            fi
            i=$((i+1))
        done < <(grep -E "^### " "$DB_FILE")
        read -n1 -srp "Enter..."
        ;;
    lock|unlock)
        [[ "$ACTION" == "lock" ]] && TARGET="unlocked" || TARGET="locked"
        grep -E "^### .* $TARGET$" "$DB_FILE" | awk '{print $2}' | nl -s ') '
        read -rp " Input Username/No: " IN_U
        [[ "$IN_U" =~ ^[0-9]+$]] && U=$(grep -E "^### .* $TARGET$" "$DB_FILE" | sed -n "${IN_U}p" | awk '{print $2}') || U="$IN_U"
        DATA=$(grep -E "^### ${U} " "$DB_FILE"); [[ -z "$DATA" ]] && exit 1
        E=$(echo "$DATA" | awk '{print $3}'); C=$(echo "$DATA" | awk '{print $4}')
        sed -i "/^### ${U} /d" "$DB_FILE"
        if [[ "$ACTION" == "lock" ]]; then
            echo "### $U $E$C locked" >> "$DB_FILE"; remove_user "$U"; echo -e "${RED}Locked!${NC}"
        else
            echo "### $U $E$C unlocked" >> "$DB_FILE"; inject_user "$U" "$C"; echo -e "${GREEN}Unlocked!${NC}"
        fi
        systemctl restart xray; sleep 1
        ;;
    limit-ip|limit-bw)
        read -rp " Username: " U
        read -rp " Nilai Baru (0=Unli): " V
        [[ "$ACTION" == "limit-ip" ]] && echo "$V" > "/etc/xray/limit/ip/${PROTO}_${U}" || echo "$V" > "/etc/xray/limit/bw/${PROTO}_${U}"
        echo -e "${GREEN}Saved!${NC}"; sleep 1
        ;;
    recovery)
        while read -r line; do
            U=$(echo "$line" | awk '{print $2}'); C=$(echo "$line" | awk '{print $4}'); S=$(echo "$line" | awk '{print $5}')
            [[ "$S" != "locked" ]] && inject_user "$U" "$C"
        done < <(grep -E "^### " "$DB_FILE")
        ;;
esac
XMGR_EOF
chmod +x /usr/bin/xray-manager

for P in vless vmess trojan; do
    UP=$(echo "$P" | tr 'a-z' 'A-Z')
    cat << MENU_PROTO > "/usr/bin/m-${P}"
#!/bin/bash
trap 'echo ""; /usr/bin/menu; exit 0' SIGINT
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; CYAN='\e[1;36m'; MAGENTA='\e[1;35m'
clear
echo -e " \${BLUE}══════════════════════════════════════════════════\${NC}\n                      \${MAGENTA}${UP}\${NC}\n \${BLUE}══════════════════════════════════════════════════\${NC}"
echo -e "  \${GREEN}1.)\${NC} Create             \${GREEN}6.)\${NC} Modify UUID\n  \${GREEN}2.)\${NC} Create Custom      \${GREEN}7.)\${NC} Check Login\n  \${GREEN}3.)\${NC} Delete             \${GREEN}8.)\${NC} List Users\n  \${GREEN}4.)\${NC} Renew              \${GREEN}9.)\${NC} Lock\n  \${GREEN}5.)\${NC} Check Config       \${GREEN}10.)\${NC} Unlock"
echo -e " \${BLUE}──────────────────────────────────────────────────\${NC}"
echo -e "  \${GREEN}11.)\${NC} Edit Limit IP     \${GREEN}12.)\${NC} Edit Limit BW\n  \${RED}x.)\${NC}  Back"
read -rp " Pilih: " OPT
trap 'echo ""; /usr/bin/m-${P}; exit 0' SIGINT
case \$OPT in
    1) xray-manager ${P} create ;; 2) xray-manager ${P} custom ;; 3) xray-manager ${P} delete ;;
    4) xray-manager ${P} renew ;; 5) xray-manager ${P} check-config ;; 6) xray-manager ${P} modify ;;
    7) xray-manager ${P} cek-login ;; 8) xray-manager ${P} list ;; 9) xray-manager ${P} lock ;;
    10) xray-manager ${P} unlock ;; 11) xray-manager ${P} limit-ip ;; 12) xray-manager ${P} limit-bw ;;
    x|X) menu ;; *) m-${P} ;;
esac
MENU_PROTO
    chmod +x "/usr/bin/m-${P}"
done

echo -e "${YELLOW}[5/8] Menetapkan Dropbear & Python WS-SSH...${NC}"
[[ ! -f /etc/dropbear/dropbear_rsa_host_key ]] && dropbearkey -t rsa -f /etc/dropbear/dropbear_rsa_host_key >/dev/null 2>&1
cat << 'DB_SVC' > /etc/systemd/system/dropbear.service
[Unit]
Description=Dropbear SSH
[Service]
ExecStart=/usr/sbin/dropbear -F -E -p 143 -p 109 -b /etc/issue.net
Restart=on-failure
[Install]
WantedBy=multi-user.target
DB_SVC
grep -qxF "/bin/false" /etc/shells || echo "/bin/false" >> /etc/shells

cat << 'PY_WS' > /usr/local/bin/ws-ssh.py
import socket, threading, select
RESPONSE = b'HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n'
class Handler(threading.Thread):
    def __init__(self, c): super().__init__(daemon=True); self.c = c
    def run(self):
        try:
            self.c.recv(4096); self.c.sendall(RESPONSE); t = socket.create_connection(('127.0.0.1', 22), timeout=10)
            while True:
                r, _, e = select.select([self.c, t], [], [self.c, t], 60)
                if e or not r: break
                for s in r:
                    d = s.recv(4096)
                    if not d: return
                    (t if s is self.c else self.c).sendall(d)
        except: pass
        finally:
            try: self.c.close()
            except: pass
server = socket.socket(socket.AF_INET, socket.SOCK_STREAM); server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
server.bind(('127.0.0.1', 10015)); server.listen(128)
while True: c, _ = server.accept(); Handler(c).start()
PY_WS
chmod +x /usr/local/bin/ws-ssh.py
cat << 'WS_SVC' > /etc/systemd/system/ws-ssh.service
[Unit]
Description=SSH WebSocket Proxy
[Service]
ExecStart=/usr/bin/python3 /usr/local/bin/ws-ssh.py
Restart=always
[Install]
WantedBy=multi-user.target
WS_SVC

echo -e "${YELLOW}[6/8] Memasang Auto-Kill & Auto-Exp Daemon...${NC}"
cat << 'AKILL' > /usr/bin/autokill-xray
#!/bin/bash
for P in vless vmess trojan; do
    DB="/etc/xray/${P}.db"; [[ ! -s "$DB" ]] && continue
    while read -r line; do
        U=$(echo "$line" | awk '{print $2}'); C=$(echo "$line" | awk '{print $4}'); S=$(echo "$line" | awk '{print $5}')
        [[ "$S" == "locked" ]] && continue
        LIM=$(cat "/etc/xray/limit/ip/${P}_${U}" 2>/dev/null || echo "2")
        [[ "$LIM" -le 0 ]] && continue
        IP_CNT=$(tail -n 500 /var/log/xray/access.log 2>/dev/null | grep -w "email: $U" | awk '{print $3}' | awk -F: '{print $1}' | sort -u | wc -l)
        if [[ "$IP_CNT" -gt "$LIM" ]]; then
            sed -i "/^### ${U} /d" "$DB"; echo "### $U $(echo "$line"|awk '{print $3}') $C locked" >> "$DB"
            /usr/bin/xray-manager "$P" recovery silent
        fi
    done < <(grep -E "^### " "$DB")
done
AKILL
cat << 'AEXP' > /usr/bin/auto-exp
#!/bin/bash
NOW=$(date +%s)
for P in vless vmess trojan; do
    DB="/etc/xray/${P}.db"; [[ ! -s "$DB" ]] && continue
    while read -r line; do
        U=$(echo "$line" | awk '{print $2}'); E=$(date -d "$(echo "$line"|awk '{print $3}')" +%s 2>/dev/null)
        if [[ "$NOW" -gt "$E" ]]; then
            sed -i "/^### ${U} /d" "$DB"; /usr/bin/xray-manager "$P" recovery silent
        fi
    done < <(grep -E "^### " "$DB")
done
AEXP
chmod +x /usr/bin/autokill-xray /usr/bin/auto-exp
(crontab -l 2>/dev/null | grep -v "autokill" | grep -v "auto-exp"; echo "0 0 * * * /usr/bin/auto-exp"; echo "*/2 * * * * /usr/bin/autokill-xray") | crontab -

echo -e "${YELLOW}[7/8] Menyiapkan Menu Utama & Bashrc Login (Tampilan Potato Tunneling)...${NC}"
cat << 'MENU_EOF' > /usr/bin/menu
#!/bin/bash
trap 'echo -e "\n\e[1;33mKembali ke Terminal...\e[0m"; exit 0' SIGINT
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; CYAN='\e[1;36m'
B=$(cat /etc/xray/brand.txt 2>/dev/null); [[ -z "$B" ]] && B="POTATO TUNNELING"
O=$(grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"'); R=$(free -m | awk 'NR==2{print $3"M"}'); SWP=$(free -m | awk 'NR==3{print $2"M"}')
I=$(curl -sS --max-time 2 https://ipv4.icanhazip.com || echo "127.0.0.1")
D=$(cat /etc/xray/domain.txt 2>/dev/null || echo "$I")
CTY=$(curl -sS --max-time 2 "http://ip-api.com/json/${I}" | jq -r '.city // "Singapore"' 2>/dev/null || echo "Singapore")
ISP=$(curl -sS --max-time 2 "http://ip-api.com/json/${I}" | jq -r '.isp // "DigitalOcean"' 2>/dev/null || echo "DigitalOcean")
UPT=$(uptime -p | sed 's/up //')
TS=$(awk '/^### /{c++} END{print c+0}' /etc/ssh/.ssh.db 2>/dev/null || echo "0")
TV=$(awk '/^### /{c++} END{print c+0}' /etc/xray/vmess.db 2>/dev/null || echo "0")
TL=$(awk '/^### /{c++} END{print c+0}' /etc/xray/vless.db 2>/dev/null || echo "0")
TT=$(awk '/^### /{c++} END{print c+0}' /etc/xray/trojan.db 2>/dev/null || echo "0")

IFACE=$(ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -n1); IFACE=${IFACE:-eth0}
if command -v vnstat >/dev/null 2>&1; then
    M_DATA=$(vnstat -i "$IFACE" -m --oneline 2>/dev/null); D_DATA=$(vnstat -i "$IFACE" -d --oneline 2>/dev/null)
    MT=$(echo "$M_DATA" | cut -d';' -f11); MRX=$(echo "$M_DATA" | cut -d';' -f9); MTX=$(echo "$M_DATA" | cut -d';' -f10)
    DT=$(echo "$D_DATA" | cut -d';' -f6); DRX=$(echo "$D_DATA" | cut -d';' -f4); DTX=$(echo "$D_DATA" | cut -d';' -f5)
fi
CUR_M=$(date +%B); CUR_D=$(date +%A)

echo -e "${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${
