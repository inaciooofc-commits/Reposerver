#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$BASE_DIR"
LOG_DIR="$TARGET_DIR"

if ! command -v apt-get >/dev/null 2>&1; then
  echo "Este instalador requer apt-get e é compatível com Debian/Ubuntu/antiX." >&2
  exit 1
fi

echo "🔧 Instalando dependências do sistema..."
sudo apt-get update -y
sudo apt-get install -y git python3 python3-venv python3-pip curl nodejs npm build-essential mpv ffmpeg

cd "$TARGET_DIR"

if [ ! -d "venv" ]; then
  echo "🐍 Criando venv Python..."
  python3 -m venv venv
fi

. "$TARGET_DIR/venv/bin/activate"
python3 -m pip install --upgrade pip
python3 -m pip install -r requirements.txt
python3 -m pip install gunicorn

if [ -f "$TARGET_DIR/whatsapp/package.json" ]; then
  echo "📦 Instalando dependências Node.js..."
  cd "$TARGET_DIR/whatsapp"
  npm install --no-audit --no-fund
  cd "$TARGET_DIR"
fi

# Ensure default data files exist
if [ ! -f "config.json" ]; then
  cat > config.json <<'JSON'
{
  "background_music": "https://cdn.pixabay.com/download/audio/2021/10/19/audio_4a93807111.mp3?filename=anime-ambience-9832.mp3",
  "panel_title": "Anime Pulse Server",
  "secret_key": "reposerver_anime_secret_2026",
  "theme_accent": "#7c4dff",
  "theme_second": "#ff6cd7",
  "theme_bg": "#090b1f",
  "youtube_api_key": "",
  "google_client_id": "",
  "google_client_secret": "",
  "google_redirect_uri": "",
  "enable_google_login": false,
  "auto_update_on_start": false,
  "background_image": "",
  "cloudflare_api_token": "",
  "cloudflare_zone_id": ""
}
JSON
fi

for file in users.json payments.json ip_log.json status.json server.log central.log game.log updater.log; do
  if [ ! -f "$file" ]; then
    case "$file" in
      users.json)
        cat > "$file" <<'JSON'
{
  "admin": {"password": "admin123", "role": "admin", "credits": 100, "banned": false}
}
JSON
        ;;
      payments.json)
        echo '[]' > "$file"
        ;;
      ip_log.json)
        echo '[]' > "$file"
        ;;
      status.json)
        cat > "$file" <<'JSON'
{
  "current": null,
  "queue": [],
  "active_users": [],
  "recent_events": [],
  "last_update": null,
  "monitor_message": "Repositório pronto para anime streaming"
}
JSON
        ;;
      server.log|central.log|game.log|updater.log)
        touch "$file"
        ;;
      *)
        touch "$file"
        ;;
    esac
  fi
done

chmod +x "$TARGET_DIR/server.py" "$TARGET_DIR/zarco_bot.py" "$TARGET_DIR/updater.py"
chmod +x "$TARGET_DIR/monitor.sh" "$TARGET_DIR/start.sh"

# Start services in background
cd "$TARGET_DIR"

function ensure_port_free() {
  local port="$1"
  if command -v lsof >/dev/null 2>&1; then
    local pids
    pids=$(lsof -ti tcp:$port || true)
    if [ -n "$pids" ]; then
      echo "🧹 Liberando porta $port (processos: $pids)"
      kill -9 $pids >/dev/null 2>&1 || true
    fi
  fi
}

function start_background() {
  local label="$1"
  local cmd="$2"
  local logfile="$3"
  local grep_cmd="$4"

  if pgrep -f "$grep_cmd" >/dev/null 2>&1; then
    echo "⚠️  $label já está rodando"
  else
    echo "▶️  Iniciando $label..."
    nohup bash -lc "$cmd" > "$logfile" 2>&1 &
    sleep 1
  fi
}

ensure_port_free 5000
ensure_port_free 6000

start_background "Servidor Flask" "source '$TARGET_DIR/venv/bin/activate' && '$TARGET_DIR/venv/bin/gunicorn' -w 2 --bind 0.0.0.0:5000 server:app" "${TARGET_DIR}/server.log" "gunicorn.*server:app"
start_background "ZarcoBOT RPG" "source '$TARGET_DIR/venv/bin/activate' && python3 '$TARGET_DIR/zarco_bot.py'" "${TARGET_DIR}/game.log" "zarco_bot.py"
start_background "Auto-updater" "source '$TARGET_DIR/venv/bin/activate' && python3 '$TARGET_DIR/updater.py'" "${TARGET_DIR}/updater.log" "updater.py"

PUBLIC_IP="$(curl -s ifconfig.me || true)"
LOCAL_IP="$(hostname -I | awk '{print $1}' || true)"

cat <<EOF
============================================
✅ Reposerver instalado e rodando!

Acesse o servidor:
  http://0.0.0.0:5000
  http://$LOCAL_IP:5000
EOF
if [ -n "$PUBLIC_IP" ]; then
  cat <<EOF
Acesso público (se a porta 5000 estiver liberada):
  http://$PUBLIC_IP:5000
EOF
fi
cat <<'EOF'

Para ver o monitor de prompt:
  ./monitor.sh
Para ver comandos no monitor:
  ./monitor.sh --commands

Se você estiver atrás de firewall/NAT, abra a porta 5000 ou use um túnel reverso (Cloudflare Tunnel / SSH reverse).

Login padrão do painel:
  admin / admin123
============================================
EOF
