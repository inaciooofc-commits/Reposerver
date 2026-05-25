#!/bin/bash

echo "🔥 INSTALANDO SERVIDOR CL-CONNECT NO antiX..."

# Atualizar sistema
sudo apt update -y
sudo apt upgrade -y

# Instalar SSH e ferramentas básicas
sudo apt install openssh-server -y

# Ativar SSH
sudo systemctl enable ssh
sudo systemctl restart ssh

# Instalar utilitários úteis
sudo apt install net-tools curl -y

# Criar pasta do sistema
sudo mkdir -p /opt/clconnect

# Script de status do servidor
cat <<EOF | sudo tee /opt/clconnect/status.sh
#!/bin/bash
echo "=== CL-CONNECT SERVER ==="
echo "IP LOCAL:"
hostname -I | awk '{print \$1}'
echo "STATUS SSH:"
systemctl status ssh | head -n 5
EOF

sudo chmod +x /opt/clconnect/status.sh

# Mostrar IP
IP=$(hostname -I | awk '{print $1}')

echo "=================================="
echo "✅ SERVIDOR PRONTO NO antiX"
echo "📡 IP: $IP"
echo "🔑 Porta: 22"
echo "=================================="

echo $IP > ~/clconnect-ip.txt

echo "💾 IP salvo em ~/clconnect-ip.txt"