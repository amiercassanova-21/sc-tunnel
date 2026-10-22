#!/bin/bash
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'
clear
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}             ${GREEN}PEMBUATAN AKUN VLESS WS${NC}              ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
mkdir -p /etc/xray; touch /etc/xray/vless.db
read -rp " Masukkan Username : " USERNAME
[[ -z "$USERNAME" ]] && { echo -e "${RED}Username kosong!${NC}"; sleep 1; m-vless; exit 1; }
grep -w -q "### $USERNAME" /etc/xray/vless.db && { echo -e "${RED}Username sudah terdaftar!${NC}"; sleep 1; m-vless; exit 1; }
read -rp " Masa Aktif (Hari) : " DAYS
[[ ! "$DAYS" =~ ^[0-9]+$ ]] && DAYS=30
DOMAIN=$(cat /etc/xray/domain.txt 2>/dev/null || curl -sS https://ipv4.icanhazip.com)
UUID=$(cat /proc/sys/kernel/random/uuid)
EXP_DATE=$(date -d "+${DAYS} days" +"%Y-%m-%d")
echo "### $USERNAME $EXP_DATE $UUID" >> /etc/xray/vless.db
CONFIG="/usr/local/etc/xray/config.json"
if [[ -f "$CONFIG" ]]; then
    TMP=$(mktemp)
    jq --arg id "$UUID" --arg user "$USERNAME" '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": $id, "level": 0, "email": $user}]' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
    systemctl restart xray
fi
VLESS_LINK="vless://${UUID}@${DOMAIN}:443?path=%2Fvless&security=tls&encryption=none&type=ws&sni=${DOMAIN}#${USERNAME}"
clear
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}           ${GREEN}DETAIL AKUN VLESS TERDAFTAR${NC}            ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo -e " Remarks       : ${USERNAME}"
echo -e " Domain / Host : ${DOMAIN}"
echo -e " Port          : 443"
echo -e " UUID          : ${UUID}"
echo -e " Path          : /vless"
echo -e " Kedaluwarsa   : ${RED}${EXP_DATE}${NC} (${DAYS} Hari)"
echo -e " ${BLUE}──────────────────────────────────────────────────${NC}"
echo -e " ${YELLOW}VLESS LINK:${NC}"
echo -e "${VLESS_LINK}"
echo -e " ${BLUE}──────────────────────────────────────────────────${NC}"
echo ""
read -n 1 -s -r -p "Tekan tombol apa saja untuk kembali..."
m-vless
