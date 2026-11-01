#!/usr/bin/env bash
# Cassanova Tunneling V2 - executable menu runtime
#!/bin/bash
trap 'echo -e "\n\e[1;33mKeluar dari Menu ke Terminal Utama...\e[0m"; exit 0' SIGINT
printf "\033[2J\033[H\033[3J"

NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; WHITE='\e[1;37m'; CYAN='\e[1;36m'

OS_NAME=$(grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
UPTIME=$(uptime -p | sed 's/up //')
RAM_USED=$(free -m | awk 'NR==2{print $3}')
RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
RAM_PERCENT=$(( RAM_USED * 100 / RAM_TOTAL ))

IP_VPS=$(curl -fsS --max-time 3 https://ipv4.icanhazip.com 2>/dev/null | tr -d '[:space:]' || true)
[[ -n "$IP_VPS" ]] || IP_VPS="Tidak terdeteksi"
# Geolocation is intentionally not queried on every menu render.
CITY="-"
ISP="-"
DOMAIN=$(cat /etc/xray/domain.txt 2>/dev/null | tr -d '[:space:]')
[[ -z "$DOMAIN" ]] && DOMAIN="$IP_VPS"

STATUS_XRAY=$(systemctl is-active --quiet xray && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
STATUS_HY2=$(systemctl is-active --quiet sing-box && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
STATUS_SSH=$(systemctl is-active --quiet cassanova-dropbear || systemctl is-active --quiet ssh && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
STATUS_BBR=$(sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr" && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")
STATUS_F2B=$(systemctl is-active --quiet fail2ban 2>/dev/null && echo -e "${GREEN}ON${NC}" || echo -e "${RED}OFF${NC}")

TOTAL_SSH=$(grep -E "^### " /etc/ssh/.ssh.db 2>/dev/null | wc -l)
TOTAL_VMESS=$(grep -E "^### " /etc/xray/vmess.db 2>/dev/null | wc -l)
TOTAL_VLESS=$(grep -E "^### " /etc/xray/vless.db 2>/dev/null | wc -l)
TOTAL_TROJAN=$(grep -E "^### " /etc/xray/trojan.db 2>/dev/null | wc -l)
TOTAL_HY2=$(jq 'length' /etc/sing-box/users.json 2>/dev/null || echo 0)

CURR_MONTH=$(date +%B)
CURR_DAY=$(date +%A)

IFACE=$(ip -o -4 route show to default 2>/dev/null | awk '{print $5}' | head -n1)
IFACE=${IFACE:-eth0}
if command -v vnstat >/dev/null 2>&1; then
    M_DATA=$(vnstat -i "$IFACE" -m --oneline 2>/dev/null)
    D_DATA=$(vnstat -i "$IFACE" -d --oneline 2>/dev/null)
    MONTH_TOTAL=$(echo "$M_DATA" | cut -d';' -f11)
    MONTH_RX=$(echo "$M_DATA" | cut -d';' -f9)
    MONTH_TX=$(echo "$M_DATA" | cut -d';' -f10)
    DAY_TOTAL=$(echo "$D_DATA" | cut -d';' -f6)
    DAY_RX=$(echo "$D_DATA" | cut -d';' -f4)
    DAY_TX=$(echo "$D_DATA" | cut -d';' -f5)
    
    RX1=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
    TX1=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)
    sleep 1
    RX2=$(cat /sys/class/net/$IFACE/statistics/rx_bytes 2>/dev/null || echo 0)
    TX2=$(cat /sys/class/net/$IFACE/statistics/tx_bytes 2>/dev/null || echo 0)
    RX_SPEED=$(( (RX2 - RX1) * 8 / 1000000 ))
    TX_SPEED=$(( (TX2 - TX1) * 8 / 1000000 ))
    TRAFFIC_MBPS=$(echo "$RX_SPEED + $TX_SPEED" | bc -l 2>/dev/null || echo "0.00")
    TRAFFIC="${TRAFFIC_MBPS} Mbit/s"
fi

[[ -z "$MONTH_TOTAL" || "$MONTH_TOTAL" == *"*"* ]] && MONTH_TOTAL="0.00 GiB"
[[ -z "$MONTH_RX" || "$MONTH_RX" == *"*"* ]] && MONTH_RX="0.00 GiB"
[[ -z "$MONTH_TX" || "$MONTH_TX" == *"*"* ]] && MONTH_TX="0.00 GiB"
[[ -z "$DAY_TOTAL" || "$DAY_TOTAL" == *"*"* ]] && DAY_TOTAL="0.00 GiB"
[[ -z "$DAY_RX" || "$DAY_RX" == *"*"* ]] && DAY_RX="0.00 GiB"
[[ -z "$DAY_TX" || "$DAY_TX" == *"*"* ]] && DAY_TX="0.00 GiB"
[[ -z "$TRAFFIC" ]] && TRAFFIC="0.00 Mbit/s"

VERSION=$(cat /usr/local/share/cassanova/VERSION 2>/dev/null || echo "2.3.0-r3-dev")
ORDER_BY=$(cat /etc/xray/order.txt 2>/dev/null || echo "Cassanova VIP")
CLIENT_NAME=$(cat /etc/xray/client.txt 2>/dev/null || echo "$(hostname)")
EXP_DAYS=$(cat /etc/xray/exp.txt 2>/dev/null || echo "Lifetime")

# Banner CASSANOVA (Kotak Penuh 50 Karakter)
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}       ${RED}█▀▀ █▀█ █▀▀ █▀▀ █▀█ █▄ █ █▀█ █ █ █▀█${NC}       ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}       ${WHITE}█▄▄ █▀█ ▄██ ▄██ █▀█ █ ▀█ █▄█ ▀▄▀ █▀█${NC}       ${BLUE}│${NC}"
echo -e " ${BLUE}│${NC}            ${CYAN}• CASSANOVA TUNNELING V2 •${NC}            ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# Info Sistem (Hanya Garis Kiri)
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}OS${NC}       : ${OS_NAME}"
echo -e " ${BLUE}│${NC} ${GREEN}RAM${NC}      : ${RAM_PERCENT}% (${RAM_USED}M/${RAM_TOTAL}M)"
echo -e " ${BLUE}│${NC} ${GREEN}CITY${NC}     : ${CITY}"
echo -e " ${BLUE}│${NC} ${GREEN}ISP${NC}      : ${ISP}"
echo -e " ${BLUE}│${NC} ${GREEN}IP${NC}       : ${IP_VPS}"
echo -e " ${BLUE}│${NC} ${GREEN}DOMAIN${NC}   : ${DOMAIN}"
echo -e " ${BLUE}│${NC} ${GREEN}UPTIME${NC}   : ${UPTIME}"
echo -e " ${BLUE}│${NC} ${RED}──────────────────────────────────────────────────${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}MONTH${NC}    : ${MONTH_TOTAL}          ${YELLOW}[${CURR_MONTH}]${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}RX${NC}       : ${MONTH_RX}"
echo -e " ${BLUE}│${NC} ${GREEN}TX${NC}       : ${MONTH_TX}"
echo -e " ${BLUE}│${NC} ${RED}──────────────────────────────────────────────────${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}DAY${NC}      : ${DAY_TOTAL}          ${YELLOW}[${CURR_DAY}]${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}RX${NC}       : ${DAY_RX}"
echo -e " ${BLUE}│${NC} ${GREEN}TX${NC}       : ${DAY_TX}"
echo -e " ${BLUE}│${NC} ${GREEN}TRAFFIC${NC}  : ${TRAFFIC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# Status Service (Hanya Garis Kiri)
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC} ${GREEN}XRAY:${STATUS_XRAY}${NC} │ ${GREEN}HY2:${STATUS_HY2}${NC} │ ${GREEN}SSH:${STATUS_SSH}${NC} │ ${GREEN}BBR:${STATUS_BBR}${NC} │ ${GREEN}F2B:${STATUS_F2B}${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# List Akun (Hanya Garis Kiri - Digeser Tengah)
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}                  ${GREEN}LIST ACCOUNTS${NC}"
echo -e " ${BLUE}│${NC} ${RED}──────────────────────────────────────────────────${NC}"
printf " ${BLUE}│${NC}           ${GREEN}%-14s${NC} : ${YELLOW}%-3s${NC} ${GREEN}ACCOUNT${NC}\n" "SSH/OPENVPN" "$TOTAL_SSH"
printf " ${BLUE}│${NC}           ${GREEN}%-14s${NC} : ${YELLOW}%-3s${NC} ${GREEN}ACCOUNT${NC}\n" "VMESS" "$TOTAL_VMESS"
printf " ${BLUE}│${NC}           ${GREEN}%-14s${NC} : ${YELLOW}%-3s${NC} ${GREEN}ACCOUNT${NC}\n" "VLESS" "$TOTAL_VLESS"
printf " ${BLUE}│${NC}           ${GREEN}%-14s${NC} : ${YELLOW}%-3s${NC} ${GREEN}ACCOUNT${NC}\n" "TROJAN" "$TOTAL_TROJAN"
printf " ${BLUE}│${NC}           ${GREEN}%-14s${NC} : ${YELLOW}%-3s${NC} ${GREEN}ACCOUNT${NC}\n" "HYSTERIA2" "$TOTAL_HY2"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# Client Info (Hanya Garis Kiri - Digeser Tengah)
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}           ${GREEN}Version${NC}     : ${VERSION}"
echo -e " ${BLUE}│${NC}           ${GREEN}Order By${NC}    : ${RED}${ORDER_BY}${NC}"
echo -e " ${BLUE}│${NC}           ${GREEN}Client Name${NC} : ${RED}${CLIENT_NAME}${NC}"
echo -e " ${BLUE}│${NC}           ${GREEN}Expiry In${NC}   : ${RED}${EXP_DAYS}${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"

# Tombol Menu (Hanya Garis Kiri)
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}1.)${NC} ⌨ SSH                 ${GREEN}6.)${NC} ⌨ SETUP BOT"
echo -e " ${BLUE}│${NC}  ${GREEN}2.)${NC} ⌨ VMESS               ${GREEN}7.)${NC} ⌨ FEATURES"
echo -e " ${BLUE}│${NC}  ${GREEN}3.)${NC} ⌨ VLESS               ${GREEN}8.)${NC} ⌨ SET REDUCE/TIME"
echo -e " ${BLUE}│${NC}  ${GREEN}4.)${NC} ⌨ TROJAN              ${GREEN}9.)${NC} ⌨ SET BRAND NAME"
echo -e " ${BLUE}│${NC}  ${GREEN}5.)${NC} ⌨ HYSTERIA2           ${GREEN}10.)${NC} ⌨ CHECK SERVICES"
echo -e " ${BLUE}│${NC}  ${RED}x.)${NC} ⌨ EXIT"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo ""

read -rp " Select From Options [1-10 or x] : " OPTION
case $OPTION in
    1) m-ssh ;;
    2) m-vmess ;;
    3) m-vless ;;
    4) m-trojan ;;
    5) m-hysteria2 ;;
    6) m-bot ;;
    7) m-feature ;;
    8) set-time ;;
    9) set-brand ;;
    10) cassanova-service ui ;;
    x|X) exit 0 ;;
    *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1 ;;
esac
