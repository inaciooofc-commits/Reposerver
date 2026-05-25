#!/bin/bash

echo "===================================="
echo "🔥 CL-CONNECT START (SSH KEY MODE)"
echo "===================================="

# Instalar SSH
sudo apt update -y
sudo apt install openssh-server -y

# Ativar SSH
sudo systemctl enable ssh
sudo systemctl restart ssh

# Criar pasta SSH se não existir
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Garantir configuração segura
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config

sudo sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/g' /etc/ssh/sshd_config

sudo systemctl restart ssh

# Mostrar infos
USER=$(whoami)
IP=$(hostname -I | awk '{print $1}')

echo "===================================="
echo "✅ SERVIDOR PRONTO (SEM SENHA)"
echo "👤 Usuário: $USER"
echo "📡 IP: $IP"
echo "🔑 MODO: SSH KEY ONLY"
echo "===================================="

echo $USER > ~/clconnect_user.txt
echo $IP > ~/clconnect_ip.txt