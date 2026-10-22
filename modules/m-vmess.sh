
#!/bin/bash
printf "\033[2J\033[H\033[3J"
clear
echo -e " \e[1;34m┌──────────────────────────────────────────────────┐\e[0m"
echo -e " \e[1;34m│\e[0m   \e[41;97m                    VMESS PANEL               \e[0m   \e[1;34m│\e[0m"
echo -e " \e[1;34m└──────────────────────────────────────────────────┘\e[0m"
echo -e "  \e[1;32m1.)\e[0m Buat Akun VMess"
echo -e "  \e[1;32m2.)\e[0m Buat Trial VMess"
echo -e "  \e[1;32m3.)\e[0m Hapus Akun VMess"
echo -e "  \e[1;32m4.)\e[0m Perpanjang Masa Aktif"
echo -e "  \e[1;31mx.)\e[0m Kembali ke Menu Utama"
read -rp " Pilih opsi [1-4 / x]: " OPT
case $OPT in
    1) echo "Fungsi add-vmess dipanggil..."; sleep 1; m-vmess ;;
    x|X) menu ;;
    *) echo "Pilihan salah!"; sleep 1; m-vmess ;;
esac
