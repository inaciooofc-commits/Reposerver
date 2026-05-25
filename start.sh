#!/bin/bash

echo "===================================="
echo "🔥 CL-CONNECT START SYSTEM (antiX)"
echo "===================================="

# Atualizar sistema básico
sudo apt update -y

# Instalar SSH
sudo apt install openssh-server -y

# Garantir SSH ativo
sudo systemctl enable ssh
sudo systemctl restart ssh

# Garantir login por senha ativo
SSH_CONFIG="/etc/ssh/sshd_config"

sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/g' $SSH_CONFIG
sudo sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/g' $SSH_CONFIG

sudo systemctl restart ssh

# Mostrar usuário correto
USER=$(whoami)
IP=$(hostname -I | awk '{print $1}')

echo "===================================="
echo "✅ SERVIDOR PRONTO"
echo "👤 Usuário: $USER"
echo "📡 IP: $IP"
echo "🔑 Porta: 22"
echo "===================================="

# Salvar infos para Termux
mkdir -p ~/clconnect
echo $USER > ~/clconnect/user.txt
echo $IP > ~/clconnect/ip.txt

echo "💾 Dados salvos em ~/clconnect/"
echo "===================================="
echo "🚀 Agora conecte via Termux:"
echo "ssh $USER@$IP"
echo "===================================="