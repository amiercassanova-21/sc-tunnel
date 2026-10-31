cat << 'PATCH_EOF' > /root/update-semua-menu.sh
#!/bin/bash
NC='\e[0m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'

echo -e "${YELLOW}[1/4] Memperbarui Modul m-ssh (Fungsional Penuh)...${NC}"
cat << 'SSH_EOF' > /usr/bin/m-ssh
#!/bin/bash
trap 'echo ""; /usr/bin/menu; exit 0' SIGINT
printf "\033[2J\033[H\033[3J"
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; CYAN='\e[1;36m'; MAGENTA='\e[1;35m'
DB_SSH="/etc/ssh/.ssh.db"
mkdir -p /etc/ssh; touch "$DB_SSH"
sed -i -E 's/^(### [^ ]+ [^ ]+ [^ ]+)$/\1 unlocked/g' "$DB_SSH"

print_ssh() {
    local u="$1"; local p="$2"; local e="$3"
    local dom=$(cat /etc/xray/domain.txt 2>/dev/null)
    local ip=$(curl -sS --max-time 3 https://ipv4.icanhazip.com || echo "127.0.0.1")
    clear
    echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e "            ${GREEN}DETAIL AKUN SSH & WEBSOCKET${NC}"
    echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
    echo -e " Username       : ${CYAN}${u}${NC}"
    echo -e " Password       : ${YELLOW}${p}${NC}"
    echo -e " Domain         : ${GREEN}${dom}${NC}"
    echo -e " IP Server      : ${GREEN}${ip}${NC}"
    echo -e " OpenSSH        : 22"
    echo -e " Dropbear       : 109, 143"
    echo -e " SSH WS TLS     : 443"
    echo -e " SSH WS Non-TLS : 80, 8080, 8880"
    echo -e " Expired Date   : ${RED}${e}${NC}"
    echo -e " ${BLUE}──────────────────────────────────────────────────${NC}"
    echo -e " ${YELLOW}PAYLOAD WS:${NC}"
    echo -e " ${CYAN}GET / HTTP/1.1[crlf]Host: ${dom}[crlf]Upgrade: websocket[crlf][crlf]${NC}"
    echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
}

clear
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "             ${MAGENTA}SSH-Dropbear-WebSocket${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}1.)${NC}  Create              ${GREEN}6.)${NC}  Check Users Login"
echo -e "  ${GREEN}2.)${NC}  Trial               ${GREEN}7.)${NC}  List Users"
echo -e "  ${GREEN}3.)${NC}  Delete              ${GREEN}8.)${NC}  Lock User"
echo -e "  ${GREEN}4.)${NC}  Renew               ${GREEN}9.)${NC}  Unlock User"
echo -e "  ${GREEN}5.)${NC}  Modify Password     ${GREEN}10.)${NC} Check Config"
echo -e " ${BLUE}──────────────────────────────────────────────────${NC}"
echo -e "  ${GREEN}11.)${NC} Recovery            ${RED}x.)${NC}  Back to Menu"
echo ""
read -rp " Pilih [1-11 atau x] : " OPT_SSH
trap 'echo ""; /usr/bin/m-ssh; exit 0' SIGINT
case $OPT_SSH in
    1)
        read -rp " Username : " U; U=$(echo "$U"|tr -d '[:space:]'); [[ -z "$U" ]] && exit 0
        grep -E -q "^### ${U} " "$DB_SSH" && { echo -e "${RED}User ada!${NC}"; sleep 2; m-ssh; exit 0; }
        read -rp " Password : " P; [[ -z "$P" ]] && P="123"
        read -rp " Hari     : " D; [[ ! "$D" =~ ^[0-9]+$ ]] && D=30
        E=$(date -d "+${D} days" +"%Y-%m-%d")
        useradd -e "$E" -s /bin/false -M "$U" 2>/dev/null
        echo "$U:$P" | chpasswd
        echo "### $U $E $P unlocked" >> "$DB_SSH"
        print_ssh "$U" "$P" "$E"; read -n 1 -srp "Enter..." ;;
    2)
        U="trial-$(head /dev/urandom | tr -dc 0-9 | head -c 3)"; P="1"; E=$(date -d "+1 days" +"%Y-%m-%d")
        useradd -e "$E" -s /bin/false -M "$U" 2>/dev/null; echo "$U:$P" | chpasswd
        echo "### $U $E $P unlocked" >> "$DB_SSH"
        print_ssh "$U" "$P" "$E"; read -n 1 -srp "Enter..." ;;
    3)
        grep -E "^### " "$DB_SSH" | awk '{print $2, $3}' | nl -s ') '
        read -rp " Hapus Username/No: " IN_U
        [[ "$IN_U" =~ ^[0-9]+$ ]] && U=$(grep -E "^### " "$DB_SSH" | sed -n "${IN_U}p" | awk '{print $2}') || U="$IN_U"
        if grep -E -q "^### ${U} " "$DB_SSH"; then
            userdel -f "$U" 2>/dev/null; sed -i "/^### ${U} /d" "$DB_SSH"; echo -e "${GREEN}Dihapus!${NC}"
        fi; sleep 1 ;;
    4)
        grep -E "^### " "$DB_SSH" | awk '{print $2, $3}' | nl -s ') '
        read -rp " Renew Username/No: " IN_U
        [[ "$IN_U" =~ ^[0-9]+$ ]] && U=$(grep -E "^### " "$DB_SSH" | sed -n "${IN_U}p" | awk '{print $2}') || U="$IN_U"
        DATA=$(grep -E "^### ${U} " "$DB_SSH"); [[ -z "$DATA" ]] && exit 0
        read -rp " Tambah Hari: " D; [[ ! "$D" =~ ^[0-9]+$ ]] && D=30
        E=$(echo "$DATA" | awk '{print $3}'); P=$(echo "$DATA" | awk '{print $4}')
        NOW=$(date +%s); EXP=$(date -d "$E" +%s 2>/dev/null || echo "$NOW"); [[ "$NOW" -gt "$EXP" ]] && BASE=$NOW || BASE=$EXP
        NEW_E=$(date -d "@$((BASE + D * 86400))" +"%Y-%m-%d")
        chage -E "$NEW_E" "$U" 2>/dev/null; sed -i "/^### ${U} /d" "$DB_SSH"; echo "### $U $NEW_E $P unlocked" >> "$DB_SSH"
        echo -e "${GREEN}Renewed!${NC}"; sleep 1 ;;
    5)
        grep -E "^### " "$DB_SSH" | awk '{print $2}' | nl -s ') '
        read -rp " Edit Username/No: " IN_U
        [[ "$IN_U" =~ ^[0-9]+$ ]] && U=$(grep -E "^### " "$DB_SSH" | sed -n "${IN_U}p" | awk '{print $2}') || U="$IN_U"
        DATA=$(grep -E "^### ${U} " "$DB_SSH"); [[ -z "$DATA" ]] && exit 0
        read -rp " Password Baru: " P; echo "$U:$P" | chpasswd
        E=$(echo "$DATA" | awk '{print $3}'); sed -i "/^### ${U} /d" "$DB_SSH"; echo "### $U $E $P unlocked" >> "$DB_SSH"
        echo -e "${GREEN}Modified!${NC}"; sleep 1 ;;
    6)
        ps aux | grep -E "sshd: |dropbear" | grep -v root | grep -v grep || echo -e "${YELLOW}Tidak ada user login.${NC}"
        read -n 1 -srp "Enter..." ;;
    7)
        printf "  %-4s %-15s %-12s %-12s %-10s\n" "NO" "USERNAME" "PASSWORD" "EXPIRED" "STATUS"
        i=1; while read -r line; do
            U=$(echo "$line" | awk '{print $2}'); E=$(echo "$line" | awk '{print $3}'); P=$(echo "$line" | awk '{print $4}'); S=$(echo "$line" | awk '{print $5}')
            printf "  %-4s %-15s %-12s %-12s %-10s\n" "${i})" "$U" "$P" "$E" "${S:-unlocked}"
            i=$((i+1))
        done < <(grep -E "^### " "$DB_SSH")
        read -n 1 -srp "Enter..." ;;
    8|9)
        [[ "$OPT_SSH" == "8" ]] && T="unlocked" || T="locked"
        grep -E "^### .* $T$" "$DB_SSH" | awk '{print $2}' | nl -s ') '
        read -rp " Input Username/No: " IN_U
        [[ "$IN_U" =~ ^[0-9]+$ ]] && U=$(grep -E "^### .* $T$" "$DB_SSH" | sed -n "${IN_U}p" | awk '{print $2}') || U="$IN_U"
        DATA=$(grep -E "^### ${U} " "$DB_SSH"); [[ -z "$DATA" ]] && exit 0
        E=$(echo "$DATA" | awk '{print $3}'); P=$(echo "$DATA" | awk '{print $4}'); sed -i "/^### ${U} /d" "$DB_SSH"
        if [[ "$OPT_SSH" == "8" ]]; then passwd -l "$U" >/dev/null 2>&1; echo "### $U $E $P locked" >> "$DB_SSH"; echo -e "${RED}Locked!${NC}"
        else passwd -u "$U" >/dev/null 2>&1; echo "### $U $E $P unlocked" >> "$DB_SSH"; echo -e "${GREEN}Unlocked!${NC}"; fi
        sleep 1 ;;
    10)
        grep -E "^### " "$DB_SSH" | awk '{print $2}' | nl -s ') '
        read -rp " Check Username/No: " IN_U
        [[ "$IN_U" =~ ^[0-9]+$ ]] && U=$(grep -E "^### " "$DB_SSH" | sed -n "${IN_U}p" | awk '{print $2}') || U="$IN_U"
        DATA=$(grep -E "^### ${U} " "$DB_SSH"); [[ -n "$DATA" ]] && print_ssh "$U" "$(echo "$DATA" | awk '{print $4}')" "$(echo "$DATA" | awk '{print $3}')"
        read -n 1 -srp "Enter..." ;;
    11) systemctl restart ssh sshd dropbear ws-ssh 2>/dev/null; echo -e "${GREEN}Recovery Selesai!${NC}"; sleep 1 ;;
    x|X) menu ;; *) m-ssh ;;
esac
m-ssh
SSH_EOF
chmod +x /usr/bin/m-ssh

echo -e "${YELLOW}[2/4] Memperbarui Modul m-feature (Fungsional Penuh)...${NC}"
cat << 'FEAT_EOF' > /usr/bin/m-feature
#!/bin/bash
trap 'echo ""; /usr/bin/menu; exit 0' SIGINT
printf "\033[2J\033[H\033[3J"
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; CYAN='\e[1;36m'; MAGENTA='\e[1;35m'
clear
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "                    ${MAGENTA}FEATURES${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "  ${GREEN}1.)${NC}  Check Bandwidth        ${GREEN}12.)${NC} Outbounds Routing"
echo -e "  ${GREEN}2.)${NC}  Set Auto Reboot        ${GREEN}13.)${NC} Rules Routing"
echo -e "  ${GREEN}3.)${NC}  Reboot VPS             ${GREEN}14.)${NC} Check Config Routing"
echo -e "  ${GREEN}4.)${NC}  Speed VPS              ${GREEN}15.)${NC} Restart All Service"
echo -e "  ${GREEN}5.)${NC}  Restart Dropbear       ${GREEN}16.)${NC} Security BBR & SYN"
echo -e "  ${GREEN}6.)${NC}  Check All Service      ${GREEN}17.)${NC} Change Domain VPS"
echo -e "  ${GREEN}7.)${NC}  Setup BOT Telegram     ${GREEN}18.)${NC} Change Brand Name"
echo -e "  ${GREEN}8.)${NC}  Backup Config VPS      ${GREEN}19.)${NC} Clean Expired Now"
echo -e "  ${GREEN}9.)${NC}  Restore Config VPS     ${GREEN}20.)${NC} Set Auto-Clean Cron"
echo -e "  ${GREEN}10.)${NC} Manages Domain & SNI   ${GREEN}21.)${NC} Information System"
echo -e "  ${GREEN}11.)${NC} WARP Cloudflare        ${RED}x.)${NC}  Back to Menu"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
read -rp " Pilih [1-21 atau x] : " OPT_F
trap 'echo ""; /usr/bin/m-feature; exit 0' SIGINT
case $OPT_F in
    1) clear; vnstat; read -n1 -srp "Enter..." ;;
    2) 
       clear; echo -e "  1.) Jam 00:00\n  2.) Jam 03:00\n  3.) 12 Jam Sekali\n  4.) Matikan"
       read -rp " Pilih: " T
       if [[ "$T" == "1" ]]; then (crontab -l 2>/dev/null | grep -v "/sbin/reboot"; echo "0 0 * * * /sbin/reboot") | crontab -; echo -e "${GREEN}Aktif Jam 00:00${NC}"
       elif [[ "$T" == "2" ]]; then (crontab -l 2>/dev/null | grep -v "/sbin/reboot"; echo "0 3 * * * /sbin/reboot") | crontab -; echo -e "${GREEN}Aktif Jam 03:00${NC}"
       elif [[ "$T" == "4" ]]; then (crontab -l 2>/dev/null | grep -v "/sbin/reboot") | crontab -; echo -e "${RED}Dimatikan${NC}"; fi
       sleep 1 ;;
    3) read -rp " Reboot sekarang? [y/n]: " Y; [[ "$Y" == "y" ]] && reboot ;;
    4) clear; curl -sL https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py | python3 -; read -n1 -srp "Enter..." ;;
    5) systemctl restart dropbear; echo -e "${GREEN}Dropbear Restarted!${NC}"; sleep 1 ;;
    6) 
       clear; for s in xray nginx ws-ssh dropbear fail2ban vnstat; do
       systemctl is-active --quiet "$s" && echo -e " $s : ${GREEN}RUNNING${NC}" || echo -e " $s : ${RED}STOPPED${NC}"
       done; read -n1 -srp "Enter..." ;;
    7) m-bot ;;
    8) tar -czf /root/Backup-VPS-$(date +%Y%m%d).tar.gz /etc/xray /etc/ssh /etc/nginx/conf.d 2>/dev/null; echo -e "${GREEN}Tersimpan di /root/${NC}"; sleep 1 ;;
    9) 
       read -rp " Nama file backup (/root/...): " F
       [[ -f "$F" ]] && tar -xzf "$F" -C / && systemctl restart xray nginx && echo -e "${GREEN}Direstore!${NC}" || echo -e "${RED}Gagal${NC}"; sleep 1 ;;
    10) 
       read -rp " Domain Utama (Enter=Tetap): " D; [[ -n "$D" ]] && echo "$D" > /etc/xray/domain.txt
       read -rp " Custom Bug SNI (Enter=Sama): " S; [[ -n "$S" ]] && echo "$S" > /etc/xray/sni.txt || cp /etc/xray/domain.txt /etc/xray/sni.txt
       echo -e "${GREEN}Tersimpan!${NC}"; sleep 1 ;;
    11) curl -sS https://www.cloudflare.com/cdn-cgi/trace | grep "warp="; read -n1 -srp "Enter..." ;;
    12|13) jq '.outbounds' /usr/local/etc/xray/config.json; read -n1 -srp "Enter..." ;;
    14) xray run -test -config /usr/local/etc/xray/config.json; read -n1 -srp "Enter..." ;;
    15) systemctl restart xray nginx ws-ssh dropbear fail2ban; echo -e "${GREEN}Semua direstart!${NC}"; sleep 1 ;;
    16) sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null; sysctl -w net.ipv4.tcp_syncookies=1 >/dev/null; echo -e "${GREEN}Keamanan Aktif!${NC}"; sleep 1 ;;
    17) 
       read -rp " Domain Baru: " ND; [[ -z "$ND" ]] && exit 0
       echo "$ND" > /etc/xray/domain.txt; echo "$ND" > /etc/xray/sni.txt
       systemctl stop nginx; certbot certonly --standalone --agree-tos --register-unsafely-without-email -d "$ND" --non-interactive 2>/dev/null
       cp "/etc/letsencrypt/live/${ND}/fullchain.pem" /etc/xray/xray.crt 2>/dev/null
       cp "/etc/letsencrypt/live/${ND}/privkey.pem" /etc/xray/xray.key 2>/dev/null
       systemctl restart nginx xray; echo -e "${GREEN}Domain diubah!${NC}"; sleep 1 ;;
    18) read -rp " Brand Baru: " B; [[ -n "$B" ]] && echo "$B" > /etc/xray/brand.txt; echo -e "${GREEN}Tersimpan!${NC}"; sleep 1 ;;
    19) /usr/bin/auto-exp 2>/dev/null; echo -e "${GREEN}Dibersihkan!${NC}"; sleep 1 ;;
    20) (crontab -l 2>/dev/null | grep -v "auto-exp"; echo "0 0 * * * /usr/bin/auto-exp") | crontab -; echo -e "${GREEN}Cron aktif!${NC}"; sleep 1 ;;
    21) free -m; df -h /; uptime; read -n1 -srp "Enter..." ;;
    x|X) menu ;;
    *) m-feature ;;
esac
m-feature
FEAT_EOF
chmod +x /usr/bin/m-feature

echo -e "${YELLOW}[3/4] Memperbarui Modul m-bot (Fungsional Penuh)...${NC}"
cat << 'BOT_EOF' > /usr/bin/m-bot
#!/bin/bash
trap 'echo ""; /usr/bin/menu; exit 0' SIGINT
clear
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; CYAN='\e[1;36m'
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "               ${CYAN}TELEGRAM BOT MANAGER${NC}"
echo -e " ${BLUE}══════════════════════════════════════════════════${NC}"
echo -e "  Status Bot : $(systemctl is-active bot-tele 2>/dev/null || echo 'inactive')"
echo -e " ${BLUE}──────────────────────────────────────────────────${NC}"
echo -e "  ${GREEN}1.)${NC} Setup / Ganti Token & Admin ID Bot"
echo -e "  ${GREEN}2.)${NC} Restart Bot Telegram"
echo -e "  ${GREEN}3.)${NC} Stop Bot Telegram"
echo -e "  ${GREEN}4.)${NC} Test Notifikasi ke Admin"
echo -e "  ${RED}x.)${NC} Kembali ke Menu"
read -rp " Pilih [1-4 atau x] : " B_OPT
trap 'echo ""; /usr/bin/m-bot; exit 0' SIGINT
case $B_OPT in
    1)
        mkdir -p /etc/bot
        read -rp " Bot Token (@BotFather) : " TKN
        read -rp " Admin Chat ID : " AID
        echo "TOKEN=$TKN" > /etc/bot/bot.conf
        echo "ADMIN=$AID" >> /etc/bot/bot.conf
        systemctl restart bot-tele 2>/dev/null
        curl -s -X POST "https://api.telegram.org/bot${TKN}/sendMessage" -d chat_id="${AID}" -d text="✅ Bot Cassanova Terhubung!" >/dev/null 2>&1
        echo -e " ${GREEN}Berhasil diatur!${NC}"; sleep 1 ;;
    2) systemctl restart bot-tele; echo -e " ${GREEN}Di-restart!${NC}"; sleep 1 ;;
    3) systemctl stop bot-tele; echo -e " ${RED}Dihentikan!${NC}"; sleep 1 ;;
    4)
        source /etc/bot/bot.conf 2>/dev/null
        if [[ -n "$TOKEN" && -n "$ADMIN" ]]; then
            curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" -d chat_id="${ADMIN}" -d text="🔔 Tes Notifikasi Berhasil!" >/dev/null
            echo -e " ${GREEN}Terkirim!${NC}"
        else
            echo -e " ${RED}Token belum diatur!${NC}"
        fi
        sleep 1 ;;
    x|X) menu ;;
    *) m-bot ;;
esac
m-bot
BOT_EOF
chmod +x /usr/bin/m-bot

echo -e "${YELLOW}[4/4] Memperbarui Struktur Menu Protokol (VLESS, VMESS, TROJAN)...${NC}"
for P in vless vmess trojan; do
    UP=$(echo "$P" | tr 'a-z' 'A-Z')
    cat << MENU_PROTO > "/usr/bin/m-${P}"
#!/bin/bash
trap 'echo ""; /usr/bin/menu; exit 0' SIGINT
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'; CYAN='\e[1;36m'; MAGENTA='\e[1;35m'
clear
echo -e " \${BLUE}══════════════════════════════════════════════════\${NC}\n                      \${MAGENTA}${UP}\${NC}\n \${BLUE}══════════════════════════════════════════════════\${NC}"
echo -e "  \${GREEN}1.)\${NC} Create             \${GREEN}6.)\${NC} Modify UUID\n  \${GREEN}2.)\${NC} Create Custom      \${GREEN}7.)\${NC} Check Login\n  \${GREEN}3.)\${NC} Delete             \${GREEN}8.)\${NC} List Users\n  \${GREEN}4.)\${NC} Renew              \${GREEN}9.)\${NC} Lock\n  \${GREEN}5.)\${NC} Check Config       \${GREEN}10.)\${NC} Unlock"
echo -e " \${BLUE}──────────────────────────────────────────────────\${NC}"
echo -e "  \${GREEN}11.)\${NC} Edit Limit IP     \${GREEN}12.)\${NC} Edit Limit BW\n  \${RED}x.)\${NC}  Back"
read -rp " Pilih: " OPT
trap 'echo ""; /usr/bin/m-${P}; exit 0' SIGINT
case \$OPT in
    1) xray-manager ${P} create ;; 2) xray-manager ${P} custom ;; 3) xray-manager ${P} delete ;;
    4) xray-manager ${P} renew ;; 5) xray-manager ${P} check-config ;; 6) xray-manager ${P} modify ;;
    7) xray-manager ${P} cek-login ;; 8) xray-manager ${P} list ;; 9) xray-manager ${P} lock ;;
    10) xray-manager ${P} unlock ;; 11) xray-manager ${P} limit-ip ;; 12) xray-manager ${P} limit-bw ;;
    x|X) menu ;; *) m-${P} ;;
esac
MENU_PROTO
    chmod +x "/usr/bin/m-${P}"
done

echo -e "${GREEN}Semua modul (m-ssh, m-feature, m-bot, protokol) berhasil diperbarui dan aktif!${NC}"
PATCH_EOF

bash /root/update-semua-menu.sh
rm -f /root/update-semua-menu.sh
