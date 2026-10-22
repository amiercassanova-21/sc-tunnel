#!/bin/bash
# ==============================================================================
# EKSEKUTOR: CREATE USER VLESS WEBSOCKET TLS
# ==============================================================================

NC='\e[0m'
BLUE='\e[1;34m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'
CYAN='\e[1;36m'

clear
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}             ${GREEN}PEMBUATAN AKUN VLESS WS${NC}              ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# Validasi Database Folder
mkdir -p /etc/xray
touch /etc/xray/vless.db

# Input Data User
read -rp " Masukkan Username : " USERNAME
if [[ -z "$USERNAME" ]]; then
    echo -e "${RED}[ERROR] Username tidak boleh kosong!${NC}"
    sleep 2
    m-vless
    exit 1
fi

# Cek apakah user sudah terdaftar
USER_EXISTS=$(grep -w -c "### $USERNAME" /etc/xray/vless.db)
if [[ "$USER_EXISTS" -gt 0 ]]; then
    echo -e "${RED}[ERROR] Username '$USERNAME' sudah ada. Gunakan nama lain!${NC}"
    sleep 2
    m-vless
    exit 1
fi

read -rp " Masa Aktif (Hari) : " DAYS
if ! [[ "$DAYS" =~ ^[0-9]+$ ]]; then
    DAYS=30
fi

# Variabel Akun
DOMAIN=$(cat /etc/xray/domain.txt 2>/dev/null || echo "domain.anda.com")
UUID=$(cat /proc/sys/kernel/random/uuid)
EXP_DATE=$(date -d "+${DAYS} days" +"%Y-%m-%d")
TODAY=$(date +"%Y-%m-%d")

# 1. Simpan ke Database Internal Script
echo "### $USERNAME $EXP_DATE $UUID" >> /etc/xray/vless.db

# 2. Sisipkan User ke Inbound VLESS Xray Config (Port 10001)
# Menggunakan jq untuk manipulasi JSON yang aman
CONFIG_FILE="/usr/local/etc/xray/config.json"
if [[ -f "$CONFIG_FILE" ]]; then
    TMP_JSON=$(mktemp)
    jq --arg id "$UUID" --arg email "$USERNAME" \
       '.inbounds[0].settings.clients += [{"id": $id, "level": 0, "email": $email}]' \
       "$CONFIG_FILE" > "$TMP_JSON" && mv "$TMP_JSON" "$CONFIG_FILE"
    
    systemctl restart xray
fi

# 3. Format URL Client
VLESS_LINK="vless://${UUID}@${DOMAIN}:443?path=%2Fvless&security=tls&encryption=none&type=ws&sni=${DOMAIN}#${USERNAME}"

clear
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}           ${GREEN}DETAIL AKUN VLESS TERDAFTAR${NC}            ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo -e " Remarks       : ${USERNAME}"
echo -e " Domain / Host : ${DOMAIN}"
echo -e " Port          : 443"
echo -e " UUID          : ${UUID}"
echo -e " Encryption    : none"
echo -e " Network       : WebSocket (ws)"
echo -e " Path          : /vless"
echo -e " TLS / SNI     : TLS / ${DOMAIN}"
echo -e " Dibuat Pada   : ${TODAY}"
echo -e " Kedaluwarsa   : ${RED}${EXP_DATE}${NC} (${DAYS} Hari)"
echo -e " ${BLUE}──────────────────────────────────────────────────${NC}"
echo -e " ${YELLOW}VLESS WS TLS LINK:${NC}"
echo -e "${VLESS_LINK}"
echo -e " ${BLUE}──────────────────────────────────────────────────${NC}"
echo ""
read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali ke menu..."
m-vless
