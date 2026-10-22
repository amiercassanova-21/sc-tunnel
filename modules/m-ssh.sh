#!/bin/bash
# ==============================================================================
# SUB-MENU: SSH-Dropbear-OpenVPN (POTATO EDITION)
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
echo -e "             ${MAGENTA}SSH-Dropbear-OpenVPN${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}1.)${NC}  Create"
echo -e "  ${GREEN}2.)${NC}  Trial"
echo -e "  ${GREEN}3.)${NC}  Delete"
echo -e "  ${GREEN}4.)${NC}  Renew/Extend"
echo -e "  ${GREEN}5.)${NC}  Modify Password"
echo -e "  ${GREEN}6.)${NC}  Check Users Login"
echo -e "  ${GREEN}7.)${NC}  List Users"
echo ""
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e " ${BLUE}│${NC}                 ${CYAN}LOCK & UNLOCK${NC}                    ${BLUE}│${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}8.)${NC}  Lock"
echo -e "  ${GREEN}9.)${NC}  Unlock"
echo ""
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e " ${BLUE}│${NC}                   ${CYAN}UTILITIES${NC}                     ${BLUE}│${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}10.)${NC} Check Config"
echo -e "  ${GREEN}11.)${NC} Recovery"
echo -e "  ${GREEN}12.)${NC} Edit Limit IP"
echo -e "  ${GREEN}13.)${NC} Edit Limit IP All"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}14.)${NC} Back to Menu"
echo -e "  ${RED}x.)${NC}  Exit"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
read -rp " Select From Options [1-14 or x] : " OPT_SSH

case $OPT_SSH in
    1) add-ssh ;;
    2)
        clear
        echo -e "${YELLOW}--- PEMBUATAN AKUN TRIAL SSH ---${NC}"
        USER_TRIAL="trial-$(head /dev/urandom | tr -dc 0-9 | head -c 4)"
        PASS_TRIAL="1"
        EXP_TRIAL=$(date -d "+1 days" +"%Y-%m-%d")
        DOMAIN=$(cat /etc/xray/domain.txt 2>/dev/null || curl -sS https://ipv4.icanhazip.com)
        useradd -e "$EXP_TRIAL" -s /bin/false -M "$USER_TRIAL" 2>/dev/null
        echo "$USER_TRIAL:$PASS_TRIAL" | chpasswd
        echo "### $USER_TRIAL $EXP_TRIAL$PASS_TRIAL" >> /etc/ssh/.ssh.db
        echo -e "Username : ${GREEN}${USER_TRIAL}${NC}"
        echo -e "Password : ${GREEN}${PASS_TRIAL}${NC}"
        echo -e "Host/IP  : ${DOMAIN}"
        echo -e "Masa Aktif : 1 Hari"
        read -n 1 -s -r -p "Tekan enter..."; m-ssh
        ;;
    3) del-ssh ;;
    4) renew-ssh ;;
    5)
        clear
        read -rp "Masukkan Username: " USER_CH
        read -rp "Masukkan Password Baru: " PASS_NEW
        echo "$USER_CH:$PASS_NEW" | chpasswd
        sed -i "/### $USER_CH/d" /etc/ssh/.ssh.db
        EXP_CH=$(chage -l "$USER_CH" | grep "Account expires" | awk -F': ' '{print $2}')
        echo "### $USER_CH $EXP_CH$PASS_NEW" >> /etc/ssh/.ssh.db
        echo -e "${GREEN}Password user $USER_CH berhasil diperbarui!${NC}"
        sleep 2; m-ssh
        ;;
    6) cek-ssh ;;
    7)
        clear
        echo -e "${GREEN}--- LIST ALL SSH USERS ---${NC}"
        grep -E "^### " /etc/ssh/.ssh.db 2>/dev/null | nl -s ') '
        read -n 1 -s -r -p "Tekan enter..."; m-ssh
        ;;
    8)
        read -rp "Masukkan User SSH yang dikunci: " U_LOCK
        passwd -l "$U_LOCK" 2>/dev/null && echo -e "${RED}Akun $U_LOCK dikunci!${NC}"
        sleep 2; m-ssh
        ;;
    9)
        read -rp "Masukkan User SSH yang dibuka: " U_UNLOCK
        passwd -u "$U_UNLOCK" 2>/dev/null && echo -e "${GREEN}Akun $U_UNLOCK dibuka kembali!${NC}"
        sleep 2; m-ssh
        ;;
    10)
        clear
        cat /etc/ssh/sshd_config | grep -v "^#" | grep -v "^$"
        read -n 1 -s -r -p "Tekan enter..."; m-ssh
        ;;
    11)
        systemctl restart ssh sshd dropbear 2>/dev/null
        echo -e "${GREEN}Service SSH dipulihkan!${NC}"; sleep 2; m-ssh
        ;;
    12)
        read -rp "Username: " U_LIM
        read -rp "Maksimal Login IP: " MAX_IP
        echo "$U_LIM $MAX_IP" > /etc/ssh/ip_${U_LIM}.limit
        echo -e "${GREEN}Limit$MAX_IP IP aktif untuk $U_LIM${NC}"; sleep 2; m-ssh
        ;;
    13)
        read -rp "Set Limit Semua Akun SSH (Max IP): " MAX_ALL
        echo "$MAX_ALL" > /etc/ssh/global.limit
        echo -e "${GREEN}Seluruh akun dibatasi maksimal $MAX_ALL IP login!${NC}"; sleep 2; m-ssh
        ;;
    14) menu ;;
    x|X) exit 0 ;;
    *) echo -e "${RED}Pilihan salah!${NC}"; sleep 1; m-ssh ;;
esac
