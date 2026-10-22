#!/bin/bash
# ==========================================
# TAMPILAN MENU CLI (ALA POTATO)
# ==========================================

# Indikator warna terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Deteksi Data Sistem
MY_IP=$(curl -sS ipv4.icanhazip.com)
RAM_USED=$(free -m | awk 'NR==2{print $3}')
RAM_TOTAL=$(free -m | awk 'NR==2{print $2}')
OS_NAME=$(grep -w PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')

clear
echo -e "${CYAN}====================================================${NC}"
echo -e "${GREEN}             AUTOSCRIPT TUNNELING PANEL             ${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e " OS Server   : ${YELLOW}${OS_NAME}${NC}"
echo -e " IP Publik   : ${YELLOW}${MY_IP}${NC}"
echo -e " Penggunaan  : ${YELLOW}${RAM_USED} MB / ${RAM_TOTAL} MB${NC}"
echo -e "${CYAN}====================================================${NC}"
echo -e " [1] Tambah Akun VLESS"
echo -e " [2] Hapus Akun VLESS"
echo -e " [3] Cek Layanan Service (Xray & Nginx)"
echo -e " [4] Reboot Server"
echo -e " [x] Keluar"
echo -e "${CYAN}====================================================${NC}"
read -rp " Masukkan pilihan [1-4 / x]: " MENU_OPTION

case $MENU_OPTION in
    1)
        clear
        echo -e "${YELLOW}--- FITUR TAMBAH VLESS ---${NC}"
        read -rp "Masukkan Nama User: " USER_NAME
        read -rp "Masa Aktif (Hari): " EXP_DAYS
        
        # Buat UUID baru
        UUID=$(cat /proc/sys/kernel/random/uuid)
        DOMAIN=$(cat /etc/xray/domain.txt 2>/dev/null || echo "domain.anda.com")
        
        # Simpan ke config Xray (placeholder logic)
        echo "User: $USER_NAME, UUID: $UUID berhasil dibuat!"
        echo "Link: vless://${UUID}@${DOMAIN}:443?path=%2Fvless&security=tls&encryption=none&type=ws#${USER_NAME}"
        read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
        menu
        ;;
    2)
        echo "Fungsi hapus akun..."
        ;;
    3)
        clear
        echo -e "${GREEN}Status Nginx:${NC}"
        systemctl is-active nginx
        echo -e "${GREEN}Status Xray:${NC}"
        systemctl is-active xray
        read -n 1 -s -r -p "Tekan sembarang tombol untuk kembali..."
        menu
        ;;
    4)
        reboot
        ;;
    x|X)
        exit 0
        ;;
    *)
        echo -e "${RED}Pilihan salah!${NC}"
        sleep 1
        menu
        ;;
esac
