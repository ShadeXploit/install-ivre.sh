#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "[+] Updating system packages..."
sudo apt-get update && sudo apt-get upgrade -y

echo "[+] Installing prerequisites for Docker..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    git \
    lsb-release

echo "[+] Setting up Docker's official GPG key and Debian repository..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo rm -f /etc/apt/keyrings/docker.gpg /etc/apt/sources.list.d/docker.list

curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  bookworm stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[+] Installing Docker Engine and Docker Compose..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "[+] Enabling and starting Docker service..."
sudo systemctl enable --now docker

echo "[+] Adding current user to the docker group..."
sudo usermod -aG docker $USER || true

echo "[+] Cloning IVRE repository to get Docker configuration..."
cd ~
if [ -d "ivre" ]; then
    echo "Directory 'ivre' already exists. Pulling latest changes..."
    cd ivre
    git pull
    cd ..
else
    git clone https://github.com/ivre/ivre.git
fi

echo "[+] Moving into IVRE Docker directory..."
cd ivre/docker

echo "[+] Starting IVRE services with Docker Compose..."
sudo docker compose up -d

echo "------------------------------------------------------------------"
echo "Installation complete!"
echo "IVRE Web interface should now be running on port 80: http://localhost/"
echo "To interact with the IVRE CLI container, run:"
echo "  sudo docker attach ivreclient"
echo "(To detach from the container without stopping it, press Ctrl+P then Ctrl+Q)"
echo "------------------------------------------------------------------"
