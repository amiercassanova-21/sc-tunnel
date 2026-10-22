#!/bin/bash
# ==============================================================================
# SUB-MENU PROTOKOL: VLESS PANEL
# ==============================================================================

# Pembersih buffer layar
printf "\033[2J\033[H\033[3J"

# Definisi Warna
NC='\e[0m'
BLUE='\e[1;34m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
RED='\e[1;31m'
WHITE='\e[1;37m'
CYAN='\e[1;36m'
BG_RED='\e[41;97m'

clear
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}   ${BG_RED}               VLESS MANAGER PANEL            ${NC}   ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}1.)${NC} ⌨ Tambah Akun VLESS"
echo -e " ${BLUE}│${NC}  ${GREEN}2.)${NC} ⌨ Buat Akun Trial VLESS"
echo -e " ${BLUE}│${NC}  ${GREEN}3.)${NC} ⌨ Perpanjang Masa Aktif VLESS"
echo -e " ${BLUE}│${NC}  ${GREEN}4.)${NC} ⌨ Hapus Akun VLESS"
echo -e " ${BLUE}│${NC}  ${GREEN}5.)${NC} ⌨ Cek User Login VLESS"
echo -e " ${BLUE}│${NC}  ${GREEN}6.)${NC} ⌨ Cek Konfigurasi Client VLESS"
echo -e " ${BLUE}│${NC}  ${RED}x.)${NC} ⌨ Kembali ke Menu Utama"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo ""
read -rp "Select From Options [1-6 or x] : " VLESS_OPT

case $VLESS_OPT in
    1) add-vless ;;
    2) echo "Fitur Trial VLESS dipanggil..."; sleep 1; m-vless ;;
    3) echo "Fitur Renew VLESS dipanggil..."; sleep 1; m-vless ;;
    4) echo "Fitur Hapus VLESS dipanggil..."; sleep 1; m-vless ;;
    5) echo "Fitur Cek Login VLESS dipanggil..."; sleep 1; m-vless ;;
    6) echo "Fitur Detail Akun VLESS dipanggil..."; sleep 1; m-vless ;;
    x|X) menu ;;
    *) echo -e "${RED}Pilihan tidak valid!${NC}"; sleep 1; m-vless ;;
esac
