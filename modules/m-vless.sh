#!/bin/bash
trap 'echo ""; /usr/bin/menu; exit 0' SIGINT
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; CYAN='\e[1;36m'; MAGENTA='\e[1;35m'
clear
echo -e " \${BLUE}══════════════════════════════════════════════════\${NC}"
echo -e "                      \${MAGENTA}VLESS\${NC}"
echo -e " \${BLUE}══════════════════════════════════════════════════\${NC}"
echo -e "  \${GREEN}1.)\${NC} Create             \${GREEN}6.)\${NC} Modify UUID"
echo -e "  \${GREEN}2.)\${NC} Create Custom      \${GREEN}7.)\${NC} Check Login"
echo -e "  \${GREEN}3.)\${NC} Delete             \${GREEN}8.)\${NC} List Users"
echo -e "  \${GREEN}4.)\${NC} Renew              \${GREEN}9.)\${NC} Lock"
echo -e "  \${GREEN}5.)\${NC} Check Config       \${GREEN}10.)\${NC} Unlock"
echo -e " \${BLUE}──────────────────────────────────────────────────\${NC}"
echo -e "  \${GREEN}11.)\${NC} Edit Limit IP     \${GREEN}12.)\${NC} Edit Limit BW"
echo -e "  \${RED}x.)\${NC}  Back"
read -rp " Pilih: " OPT
trap 'echo ""; /usr/bin/m-vless; exit 0' SIGINT
case \$OPT in
    1) xray-manager vless create ;;
    2) xray-manager vless custom ;;
    3) xray-manager vless delete ;;
    4) xray-manager vless renew ;;
    5) xray-manager vless check-config ;;
    6) xray-manager vless modify ;;
    7) xray-manager vless cek-login ;;
    8) xray-manager vless list ;;
    9) xray-manager vless lock ;;
    10) xray-manager vless unlock ;;
    11) xray-manager vless limit-ip ;;
    12) xray-manager vless limit-bw ;;
    x|X) menu ;;
    *) m-vless ;;
esac
