#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo; exec /usr/bin/menu' INT
while true; do
  clear
  echo '════════════════════════════════════════════════════════'
  echo '              HYSTERIA2 ACCOUNT MANAGER'
  echo '════════════════════════════════════════════════════════'
  systemctl is-active --quiet sing-box && echo 'Service : ACTIVE' || echo 'Service : INACTIVE'
  echo "UDP Port: 443"
  echo
  echo ' 1) Create Account'
  echo ' 2) Create Custom Account'
  echo ' 3) Delete Account'
  echo ' 4) Renew Account'
  echo ' 5) Modify Password'
  echo ' 6) Lock Account'
  echo ' 7) Unlock Account'
  echo ' 8) List Accounts'
  echo ' 9) Check Config / Service'
  echo '10) Recovery / rebuild config'
  echo ' x) Back'
  echo
  read -rp 'Pilih: ' OPT
  case "$OPT" in
    1) hy2-manager create ;;
    2) hy2-manager custom ;;
    3) hy2-manager delete ;;
    4) hy2-manager renew ;;
    5) hy2-manager modify ;;
    6) hy2-manager lock ;;
    7) hy2-manager unlock ;;
    8) hy2-manager list ;;
    9) hy2-manager check ;;
    10) hy2-manager recover ;;
    x|X) exec /usr/bin/menu ;;
    *) echo 'Pilihan tidak valid.' ;;
  esac
  read -rp 'Tekan Enter untuk kembali...' _ || true
done
