#!/bin/bash
printf "\033[2J\033[H\033[3J"
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; RED='\e[1;31m'; BG_RED='\e[41;97m'
clear
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}   ${BG_RED}               VLESS MANAGER PANEL            ${NC}   ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}  ${GREEN}1.)${NC} ⌨ Tambah Akun VLESS"
echo -e " ${BLUE}│${NC}  ${GREEN}2.)${NC} ⌨ Hapus Akun VLESS"
echo -e " ${BLUE}│${NC}  ${GREEN}3.)${NC} ⌨ Cek User VLESS"
echo -e " ${BLUE}│${NC}  ${RED}x.)${NC} ⌨ Kembali ke Menu Utama"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo ""
read -rp "Select From Options [1-3 or x] : " OPT
case $OPT in
    1) add-vless ;;
    2) del-vless ;;
    3) cek-vless ;;
    x|X) menu ;;
    *) echo -e "${RED}Pilihan salah!${NC}"; sleep 1; m-vless ;;
esac
