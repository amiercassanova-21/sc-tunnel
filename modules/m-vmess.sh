#!/usr/bin/env bash
set -u
PROTO="vmess"
trap 'echo; /usr/bin/menu; exit 0' INT
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; MAGENTA='\e[1;35m'
while true; do
  clear
  echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
  echo -e "                      ${MAGENTA}VMESS${NC}"
  echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
  echo -e "  ${GREEN}1.)${NC} Create             ${GREEN}6.)${NC} Modify Credential"
  echo -e "  ${GREEN}2.)${NC} Create Custom      ${GREEN}7.)${NC} Check Login"
  echo -e "  ${GREEN}3.)${NC} Delete             ${GREEN}8.)${NC} List Users"
  echo -e "  ${GREEN}4.)${NC} Renew              ${GREEN}9.)${NC} Lock"
  echo -e "  ${GREEN}5.)${NC} Check Config       ${GREEN}10.)${NC} Unlock"
  echo -e " ${BLUE}──────────────────────────────────────────────────${NC}"
  echo -e "  ${GREEN}11.)${NC} Edit Limit IP      ${GREEN}12.)${NC} Edit Limit BW"
  echo -e "  ${GREEN}13.)${NC} Recovery Account   ${GREEN}14.)${NC} Aktifkan API (sekali)"
  echo -e "  ${GREEN}15.)${NC} Reset Pemakaian BW"
  echo -e "  ${GREEN}x.)${NC} Back"
  read -rp " Pilih: " OPT
  case "$OPT" in
    1) xray-manager "$PROTO" create ;;
    2) xray-manager "$PROTO" custom ;;
    3) xray-manager "$PROTO" delete ;;
    4) xray-manager "$PROTO" renew ;;
    5) xray-manager "$PROTO" check-config ;;
    6) xray-manager "$PROTO" modify ;;
    7) xray-manager "$PROTO" cek-login ;;
    8) xray-manager "$PROTO" list ;;
    9) xray-manager "$PROTO" lock ;;
    10) xray-manager "$PROTO" unlock ;;
    11) xray-manager "$PROTO" limit-ip ;;
    12) xray-manager "$PROTO" limit-bw ;;
    13) xray-manager "$PROTO" recovery ;;
    14) xray-manager "$PROTO" api-enable ;;
    15) xray-manager "$PROTO" limit-reset ;;
    x|X) exec /usr/bin/menu ;;
    *) echo "Pilihan tidak valid."; sleep 1 ;;
  esac
  read -rp "Tekan Enter untuk kembali ke menu protokol..." _ || true
done
