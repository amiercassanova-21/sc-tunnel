
#!/bin/bash
printf "\033[2J\033[H\033[3J"
clear
echo -e " \e[1;34m┌──────────────────────────────────────────────────┐\e[0m"
echo -e " \e[1;34m│\e[0m   \e[41;97m                SETTINGS & FEATURES           \e[0m   \e[1;34m│\e[0m"
echo -e " \e[1;34m└──────────────────────────────────────────────────┘\e[0m"
echo -e "  \e[1;32m1.)\e[0m Check Bandwidth"
echo -e "  \e[1;32m2.)\e[0m Reboot VPS"
echo -e "  \e[1;32m3.)\e[0m Speedtest VPS"
echo -e "  \e[1;32m4.)\e[0m Check All Services"
echo -e "  \e[1;32m5.)\e[0m Restart Xray & Nginx"
echo -e "  \e[1;31mx.)\e[0m Kembali ke Menu Utama"
read -rp " Pilih opsi [1-5 / x]: " OPT
case $OPT in
    1) vnstat ;;
    2) reboot ;;
    3) curl -s https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 - ;;
    4) systemctl status xray nginx ;;
    5) systemctl restart xray nginx && echo "Service restarted!"; sleep 1; m-feature ;;
    x|X) menu ;;
    *) echo "Pilihan salah!"; sleep 1; m-feature ;;
esac
