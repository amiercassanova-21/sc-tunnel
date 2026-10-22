
#!/bin/bash
NC='\e[0m'; BLUE='\e[1;34m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'; RED='\e[1;31m'
clear
echo -e " ${BLUE}┌──────────────────────────────────────────────────┐${NC}"
echo -e " ${BLUE}│${NC}             ${GREEN}DAFTAR USER AKTIF VLESS${NC}              ${BLUE}│${NC}"
echo -e " ${BLUE}└──────────────────────────────────────────────────┘${NC}"
echo -e " NO   USER           EXPIRED DATE       STATUS"
echo -e " ${BLUE}──────────────────────────────────────────────────${NC}"
i=1
while read -r line; do
    [[ -z "$line" ]] && continue
    USER=$(echo "$line" | awk '{print $2}')
    EXP=$(echo "$line" | awk '{print $3}')
    EXP_SEC=$(date -d "$EXP" +%s 2>/dev/null || echo "0")
    NOW_SEC=$(date +%s)
    if [[ "$NOW_SEC" -gt "$EXP_SEC" ]]; then
        STATUS="${RED}EXPIRED${NC}"
    else
        STATUS="${GREEN}ACTIVE${NC}"
    fi
    printf " %-4s %-14s %-18s %b\n" "$i.)" "$USER" "$EXP" "$STATUS"
    ((i++))
done < <(grep -E "^### " /etc/xray/vless.db 2>/dev/null)
echo -e " ${BLUE}──────────────────────────────────────────────────${NC}"
echo ""
read -n 1 -s -r -p "Tekan tombol apa saja untuk kembali..."
m-vless
