#!/bin/bash
# ==========================================
# LOADER UTAMA AUTOSCRIPT
# ==========================================

# Pastikan dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
  echo "Script ini wajib dijalankan sebagai user root!"
  exit 1
fi

# Update paket dan install alat download
apt update -y && apt install -y curl wget

# Ganti 'USERNAME_GITHUB' dengan username GitHub Anda
REPO_URL="https://raw.githubusercontent.com/USERNAME_GITHUB/sc-tunnel/main"

# Download dan jalankan setup.sh (mesin inti)
curl -sS "${REPO_URL}/setup.sh" | bash
