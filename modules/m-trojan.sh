
#!/bin/bash
printf "\033[2J\033[H\033[3J"
clear
echo -e " \e[1;34m┌──────────────────────────────────────────────────┐\e[0m"
echo -e " \e[1;34m│\e[0m   \e[41;97m                    TROJAN PANEL              \e[0m   \e[1;34m│\e[0m"
echo -e " \e[1;34m└──────────────────────────────────────────────────┘\e[0m"
echo -e "  \e[1;32m1.)\e[0m Buat Akun Trojan"
echo -e "  \e[1;32m2.)\e[0m Buat Trial Trojan"
echo -e "  \e[1;32m3.)\e[0m Hapus Akun Trojan"
echo -e "  \e[1;31mx.)\e[0m Kembali ke Menu Utama"
read -rp " Pilih opsi [1-3 / x]: " OPT
case $OPT in
    1) echo "Fungsi add-trojan dipanggil..."; sleep 1; m-trojan ;;
    x|X) menu ;;
    *) echo "Pilihan salah!"; sleep 1; m-trojan ;;
esac
