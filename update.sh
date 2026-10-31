#!/bin/bash
NC='\e[0m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'
clear
echo -e "${YELLOW}Mengunduh versi terbaru dari GitHub Cassanova...${NC}"
REPO="https://raw.githubusercontent.com/amiercassanova-21/sc-tunnel/main"

wget -qO /tmp/menu "${REPO}/menu.sh"
if [ $? -eq 0 ]; then
    mv /tmp/menu /usr/bin/menu
    wget -qO /usr/bin/m-vless "${REPO}/modules/m-vless.sh"
    wget -qO /usr/bin/m-vmess "${REPO}/modules/m-vmess.sh"
    wget -qO /usr/bin/m-trojan "${REPO}/modules/m-trojan.sh"
    wget -qO /usr/bin/m-ssh "${REPO}/modules/m-ssh.sh"
    wget -qO /usr/bin/m-feature "${REPO}/modules/m-feature.sh"
    wget -qO /usr/bin/m-bot "${REPO}/modules/m-bot.sh"
    wget -qO /usr/local/bin/bot-tele.py "${REPO}/bot-tele.py"
    wget -qO /usr/bin/update-sc "${REPO}/update.sh"
    chmod +x /usr/bin/menu /usr/bin/m-* /usr/bin/update-sc /usr/local/bin/bot-tele.py
    systemctl restart bot-tele 2>/dev/null
    echo -e "${GREEN}Berhasil! Script telah diperbarui ke versi GitHub terbaru.${NC}"
else
    echo -e "${RED}Gagal mengunduh. Pastikan link GitHub valid.${NC}"
fi
sleep 2
menu
