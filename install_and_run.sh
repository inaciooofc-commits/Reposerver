#!/usr/bin/env bash
set -e

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
USER_NAME="$(id -un)"

echo "Instalando dependências básicas (apt). Pode pedir senha sudo..."
if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y python3-venv python3-pip nodejs npm git curl build-essential
fi

# Python venv
python3 -m venv venv
. venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# Node deps for WhatsApp
cd "$BASE_DIR/whatsapp"
if [ -f package.json ]; then
  npm install --no-audit --no-fund
fi
cd "$BASE_DIR"

# Ensure scripts executable
chmod +x zarco_bot.py updater.py server.py

# Create central log files
touch central.log game.log updater.log server.log

# Install systemd services (requires sudo)
if [ "$EUID" -ne 0 ]; then
  echo "Para registrar serviços systemd, será necessário sudo. Tentando com sudo..."
fi
SYSTEMCTL_CMD="$(command -v systemctl || true)"
sudo cp deploy/zarco.service /etc/systemd/system/zarco@.service || true
sudo cp deploy/updater.service /etc/systemd/system/updater@.service || true
# Add server service
sudo tee /etc/systemd/system/reposerver.service >/dev/null <<'EOF'
[Unit]
Description=Reposerver Flask App
After=network.target

[Service]
User=${USER_NAME}
WorkingDirectory=${BASE_DIR}
ExecStart=${BASE_DIR}/venv/bin/python ${BASE_DIR}/server.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# Whatsapp service
sudo tee /etc/systemd/system/whatsapp.service >/dev/null <<'EOF'
[Unit]
Description=Reposerver WhatsApp (Baileys)
After=network.target

[Service]
User=${USER_NAME}
WorkingDirectory=${BASE_DIR}/whatsapp
ExecStart=/usr/bin/env node index.js
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

if [ -n "$SYSTEMCTL_CMD" ]; then
  sudo systemctl daemon-reload || true
  sudo systemctl enable --now reposerver.service || true
  sudo systemctl enable --now updater@${USER_NAME}.service || true
  sudo systemctl enable --now zarco@${USER_NAME}.service || true
  sudo systemctl enable --now whatsapp.service || true
else
  echo "systemctl não encontrado; pule a habilitação de serviços systemd neste ambiente."
fi

echo "Instalação concluída. Serviços iniciados (quando possível)."

echo "Logs: $BASE_DIR/central.log, $BASE_DIR/game.log, $BASE_DIR/updater.log"
