#!/bin/bash
set -e

TARGET_USER=${SUDO_USER:-$(whoami)}
TARGET_DIR=/opt/reposerver
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔥 Instalando Reposerver completo no antiX..."

sudo apt update -y
sudo apt upgrade -y
sudo apt install -y python3 python3-venv python3-pip curl rsync mpv ffmpeg

sudo mkdir -p "$TARGET_DIR"
sudo rsync -a --exclude='.git' "$SRC_DIR/" "$TARGET_DIR/"
sudo chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_DIR"

cd "$TARGET_DIR"
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

if [ ! -f "config.json" ]; then
  cat > config.json <<'JSON'
{
  "background_music": "https://cdn.pixabay.com/download/audio/2021/10/19/audio_4a93807111.mp3?filename=anime-ambience-9832.mp3",
  "panel_title": "Anime Pulse Server",
  "secret_key": "reposerver_anime_secret_2026",
  "theme_accent": "#7c4dff",
  "theme_second": "#ff6cd7",
  "theme_bg": "#090b1f"
}
JSON
fi

if [ ! -f "users.json" ]; then
  echo "{}" > users.json
fi

if [ ! -f "payments.json" ]; then
  echo "[]" > payments.json
fi

if [ ! -f "ip_log.json" ]; then
  echo "[]" > ip_log.json
fi

if [ ! -f "status.json" ]; then
  cat > status.json <<'JSON'
{
  "current": null,
  "queue": [],
  "active_users": [],
  "recent_events": [],
  "last_update": null,
  "monitor_message": "Repositório pronto para anime streaming"
}
JSON
fi

if [ ! -f "server.log" ]; then
  touch server.log
fi

chmod +x "$TARGET_DIR/start.sh"
chmod +x "$TARGET_DIR/monitor.sh"

IP=$(hostname -I | awk '{print $1}')

echo "===================================="
echo "✅ Instalação concluída no antiX"
echo "Use: sudo bash $TARGET_DIR/start.sh"
echo "Painel de monitor: sudo bash $TARGET_DIR/monitor.sh"
echo "Acesse: http://$IP:5000"
echo "Login padrão: admin / admin123"
echo "===================================="
