#!/usr/bin/env bash
# ==============================================================================
# Setup Script for IVRE on Kali Linux
# ==============================================================================
set -e

echo "[+] Updating package repositories..."
sudo apt update

echo "[+] Installing IVRE, MongoDB, Nmap, and Web Dependencies..."
sudo apt install -y ivre ivre-doc mongodb-server nmap masscan apache2 libapache2-mod-wsgi-py3

echo "[+] Ensuring MongoDB service is running..."
sudo systemctl enable --now mongodb

echo "[+] Initializing IVRE Databases..."
# Force initialization (-y / yes)
yes | ivre ipinfo --init
yes | ivre scancli --init
yes | ivre view --init
yes | ivre flowcli --init

echo "[+] Downloading IP data and web data (GEOIP / AS information)..."
sudo ivre ipdata --download
sudo ivre getwebdata

echo "[+] Configuring Apache Web UI..."
# Enable required Apache modules
sudo a2enmod rewrite wsgi

# Symlink IVRE static files into Web Root if not already present
if [ ! -d "/var/www/html/static" ]; then
    sudo ln -s /usr/share/ivre/web/static/* /var/www/html/
fi

# Restart Apache
sudo systemctl restart apache2

echo "=============================================================================="
echo "[+] IVRE Installation Completed Successfully!"
echo "[+] Access Web Interface at: http://localhost/"
echo "=============================================================================="
