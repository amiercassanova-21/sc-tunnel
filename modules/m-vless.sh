#!/bin/bash
# ==============================================================================
# SUB-MENU: VLESS (POTATO EDITION)
# ==============================================================================

printf "\033[2J\033[H\033[3J"

NC='\e[0m'
BLUE='\e[1;34m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'
CYAN='\e[1;36m'
MAGENTA='\e[1;35m'
BG_BLUE='\e[44;97m'

clear
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "                      ${MAGENTA}VLESS${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}1.)${NC}  Create"
echo -e "  ${GREEN}2.)${NC}  Create [Custom UUID]"
echo -e "  ${GREEN}3.)${NC}  Trial"
echo -e "  ${GREEN}4.)${NC}  Delete"
echo -e "  ${GREEN}5.)${NC}  Renew/Extend"
echo -e "  ${GREEN}6.)${NC}  Modify UUID"
echo -e "  ${GREEN}7.)${NC}  Check Users Login"
echo -e "  ${GREEN}8.)${NC}  List Users"
echo ""
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e " ${BLUE}│${NC}                 ${CYAN}LOCK & UNLOCK${NC}                    ${BLUE}│${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}9.)${NC}  Lock"
echo -e "  ${GREEN}10.)${NC} Unlock"
echo ""
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e " ${BLUE}│${NC}                   ${CYAN}UTILITIES${NC}                     ${BLUE}│${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}11.)${NC} Check Config"
echo -e "  ${GREEN}12.)${NC} Recovery"
echo -e "  ${GREEN}13.)${NC} Edit Limit IP"
echo -e "  ${GREEN}14.)${NC} Edit Limit IP All"
echo -e "  ${GREEN}15.)${NC} Edit Limit Bandwidth"
echo -e "  ${GREEN}16.)${NC} Edit Limit All Bandwidth"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}17.)${NC} Back to Menu"
echo -e "  ${RED}x.)${NC}  Exit"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
read -rp " Select From Options [1-17 or x] : " OPT_VLESS

case $OPT_VLESS in
    1) add-vless ;;
    2)
        clear
        echo -e "${YELLOW}--- BUAT VLESS DENGAN UUID KUSTOM ---${NC}"
        read -rp "Username: " USERNAME
        read -rp "Custom UUID (Contoh: 12345678-abcd-...): " C_UUID
        read -rp "Masa Aktif (Hari): " DAYS
        [[ ! "$DAYS" =~ ^[0-9]+$ ]] && DAYS=30
        DOMAIN=$(cat /etc/xray/domain.txt 2>/dev/null || curl -sS https://ipv4.icanhazip.com)
        EXP_DATE=$(date -d "+${DAYS} days" +"%Y-%m-%d")
        echo "### $USERNAME $EXP_DATE $C_UUID" >> /etc/xray/vless.db
        CONFIG="/usr/local/etc/xray/config.json"
        if [[ -f "$CONFIG" ]]; then
            TMP=$(mktemp)
            jq --arg id "$C_UUID" --arg user "$USERNAME" '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": $id, "level": 0, "email": $user}]' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
            systemctl restart xray
        fi
        V_LINK="vless://${C_UUID}@${DOMAIN}:443?path=%2Fvless&security=tls&encryption=none&type=ws&sni=${DOMAIN}#${USERNAME}"
        echo -e "${GREEN}Akun berhasil dibuat dengan Custom UUID:${NC}\n$V_LINK"
        read -n 1 -s -r -p "Tekan enter..."; m-vless
        ;;
    3)
        clear
        U_TRIAL="vless-trial-$(head /dev/urandom | tr -dc 0-9 | head -c 3)"
        U_UUID=$(cat /proc/sys/kernel/random/uuid)
        EXP_TRIAL=$(date -d "+1 days" +"%Y-%m-%d")
        DOMAIN=$(cat /etc/xray/domain.txt 2>/dev/null || curl -sS https://ipv4.icanhazip.com)
        echo "### $U_TRIAL $EXP_TRIAL $U_UUID" >> /etc/xray/vless.db
        CONFIG="/usr/local/etc/xray/config.json"
        if [[ -f "$CONFIG" ]]; then
            TMP=$(mktemp)
            jq --arg id "$U_UUID" --arg user "$U_TRIAL" '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": $id, "level": 0, "email": $user}]' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
            systemctl restart xray
        fi
        echo -e "Trial 1 Hari Aktif: vless://${U_UUID}@${DOMAIN}:443?path=%2Fvless&security=tls&encryption=none&type=ws&sni=${DOMAIN}#${U_TRIAL}"
        read -n 1 -s -r -p "Tekan enter..."; m-vless
        ;;
    4) del-vless ;;
    5) renew-vless ;;
    6)
        read -rp "Masukkan User yang mau diganti UUID: " USER_MOD
        DATA=$(grep -w "### $USER_MOD" /etc/xray/vless.db)
        if [[ -n "$DATA" ]]; then
            NEW_UUID=$(cat /proc/sys/kernel/random/uuid)
            EXP=$(echo "$DATA" | awk '{print $3}')
            sed -i "/### $USER_MOD/d" /etc/xray/vless.db
            echo "### $USER_MOD $EXP $NEW_UUID" >> /etc/xray/vless.db
            CONFIG="/usr/local/etc/xray/config.json"
            TMP=$(mktemp)
            jq --arg id "$NEW_UUID" --arg user "$USER_MOD" '(.inbounds[] | select(.protocol=="vless") | .settings.clients) |= map(if .email == $user then .id = $id else . end)' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
            systemctl restart xray
            echo -e "${GREEN}UUID $USER_MOD berhasil diubah ke: $NEW_UUID${NC}"
        else
            echo -e "${RED}User tidak ditemukan!${NC}"
        fi
        sleep 2; m-vless
        ;;
    7) cek-vless ;;
    8)
        clear
        echo -e "${GREEN}--- LIST ALL VLESS USERS ---${NC}"
        grep -E "^### " /etc/xray/vless.db 2>/dev/null | cut -d ' ' -f 2,3,4 | nl -s ') '
        read -n 1 -s -r -p "Tekan enter..."; m-vless
        ;;
    9)
        read -rp "Username VLESS yang ingin di-Lock: " USER_LK
        CONFIG="/usr/local/etc/xray/config.json"
        TMP=$(mktemp)
        jq --arg user "$USER_LK" '(.inbounds[] | select(.protocol=="vless") | .settings.clients) |= map(select(.email != $user))' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
        systemctl restart xray
        echo -e "${RED}Akun $USER_LK dinonaktifkan dari Xray Core!${NC}"
        sleep 2; m-vless
        ;;
    10)
        read -rp "Username VLESS yang ingin di-Unlock: " USER_UNLK
        DATA=$(grep -w "### $USER_UNLK" /etc/xray/vless.db)
        if [[ -n "$DATA" ]]; then
            U_ID=$(echo "$DATA" | awk '{print $4}')
            CONFIG="/usr/local/etc/xray/config.json"
            TMP=$(mktemp)
            jq --arg id "$U_ID" --arg user "$USER_UNLK" '(.inbounds[] | select(.protocol=="vless") | .settings.clients) += [{"id": $id, "level": 0, "email": $user}]' "$CONFIG" > "$TMP" && mv "$TMP" "$CONFIG"
            systemctl restart xray
            echo -e "${GREEN}Akun $USER_UNLK kembali diaktifkan!${NC}"
        else
            echo -e "${RED}Data akun tidak ada di database!${NC}"
        fi
        sleep 2; m-vless
        ;;
    11)
        clear
        jq '.inbounds[] | select(.protocol=="vless")' /usr/local/etc/xray/config.json
        read -n 1 -s -r -p "Tekan enter..."; m-vless
        ;;
    12)
        systemctl restart xray
        echo -e "${GREEN}Engine Xray berhasil di-recovery!${NC}"; sleep 2; m-vless
        ;;
    13)
        read -rp "Username: " U_LIP
        read -rp "Limit Max IP: " MAX_IP
        echo "$MAX_IP" > /etc/xray/vless_${U_LIP}.iplimit
        echo -e "${GREEN}User $U_LIP dibatasi $MAX_IP IP!${NC}"; sleep 2; m-vless
        ;;
    14)
        read -rp "Limit IP untuk Seluruh User VLESS: " MAX_ALL
        echo "$MAX_ALL" > /etc/xray/vless_global.iplimit
        echo -e "${GREEN}Seluruh user VLESS dibatasi $MAX_ALL IP!${NC}"; sleep 2; m-vless
        ;;
    15)
        read -rp "Username: " U_BW
        read -rp "Limit Kuota (GB): " MAX_BW
        echo "$MAX_BW" > /etc/xray/vless_${U_BW}.bwlimit
        echo -e "${GREEN}User $U_BW dibatasi $MAX_BW GB!${NC}"; sleep 2; m-vless
        ;;
    16)
        read -rp "Limit Bandwidth Semua User VLESS (GB): " MAX_ALL_BW
        echo "$MAX_ALL_BW" > /etc/xray/vless_global.bwlimit
        echo -e "${GREEN}Semua user VLESS dibatasi $MAX_ALL_BW GB!${NC}"; sleep 2; m-vless
        ;;
    17) menu ;;
    x|X) exit 0 ;;
    *) echo -e "${RED}Pilihan salah!${NC}"; sleep 1; m-vless ;;
esac
