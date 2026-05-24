#!/bin/bash
# ================================================
# CL TECH OS - Instalador v4.3 MATRIX + CLOUDFLARE
# Systemd Service para Cloudflare Tunnel
# ================================================

set -e

echo "🔥 Iniciando instalação do CL TECH OS v4.3 MATRIX + CLOUDFLARE..."

if [[ $EUID -ne 0 ]]; then
   echo "❌ Execute como root (sudo)"
   exit 1
fi

apt-get update -qq
apt-get install -y curl wget git ffmpeg mpv yt-dlp whiptail build-essential

# Node.js + PM2
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi
npm install -g pm2 --silent

# Cloudflared
echo "📦 Instalando Cloudflared..."
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb || apt-get install -f -y
    rm -f cloudflared-linux-amd64.deb
fi

mkdir -p /opt/cltech/{public,users,logs,downloads,monitor,backgrounds}
cd /opt/cltech

# ==================== CONFIG ====================
cat > config.json << EOF
{
  "port": 3000,
  "pixKey": "566.019.878.32",
  "pixName": "Pedro Inácio dos Santos de Menezes",
  "adminUser": "admin",
  "adminPass": "admin2026"
}
EOF

# ==================== CLOUDFLARE SYSTEMD SERVICE ====================
cat > /etc/systemd/system/cloudflare.service << EOF
[Unit]
Description=Cloudflare Tunnel for CL TECH OS
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/cltech
ExecStart=/usr/local/bin/cloudflared tunnel --url http://localhost:3000
Restart=always
RestartSec=5
StandardOutput=append:/opt/cltech/logs/cf.log
StandardError=append:/opt/cltech/logs/cf.log

[Install]
WantedBy=multi-user.target
EOF

# ==================== FRONTEND MATRIX (simplificado) ====================
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CL TECH OS v4.3</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <canvas id="matrixRain"></canvas>
  <div class="container">
    <div id="loginScreen" class="screen active">
      <h1 class="glitch">CL TECH OS</h1>
      <input type="text" id="loginUser" placeholder="USERNAME" class="matrix-input">
      <input type="password" id="loginPass" placeholder="PASSWORD" class="matrix-input">
      <button onclick="login()" class="matrix-btn">ACCESS SYSTEM</button>
    </div>
  </div>
  <script src="app.js"></script>
</body>
</html>
EOF

cat > public/style.css << 'EOF'
body { background:#000; color:#00ff41; font-family:'VT323',monospace; margin:0; overflow:hidden; }
#matrixRain { position:fixed; top:0; left:0; width:100%; height:100%; z-index:-1; opacity:0.3; }
.glitch { animation: glitch 1s infinite; }
.matrix-input, .matrix-btn { background:transparent; border:2px solid #00ff41; color:#00ff41; padding:12px; width:100%; margin:8px 0; font-size:1.3rem; }
.matrix-btn:hover { background:#00ff41; color:#000; }
EOF

cat > public/app.js << 'EOF'
const canvas = document.getElementById('matrixRain');
const ctx = canvas.getContext('2d');
canvas.width = window.innerWidth; canvas.height = window.innerHeight;
const chars = "01アイウエオ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ";
const fontSize = 14;
const columns = canvas.width / fontSize;
const drops = Array(Math.floor(columns)).fill(1);

function draw() {
  ctx.fillStyle = 'rgba(0,0,0,0.05)';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = '#00ff41';
  ctx.font = fontSize + 'px monospace';
  for (let i = 0; i < drops.length; i++) {
    ctx.fillText(chars[Math.floor(Math.random()*chars.length)], i*fontSize, drops[i]*fontSize);
    if (drops[i]*fontSize > canvas.height && Math.random() > 0.975) drops[i] = 0;
    drops[i]++;
  }
}
setInterval(draw, 35);
EOF

# ==================== BACKEND ====================
cat > server.js << 'EOF'
const express = require('express');
const app = express();
const PORT = 3000;

app.use(express.static('public'));
app.listen(PORT, () => console.log(`🚀 CL TECH OS MATRIX v4.3 rodando em http://localhost:${PORT}`));
EOF

npm init -y --silent
npm install express --silent

# ==================== MONITOR TERMINAL ====================
cat > monitor.sh << 'MONITOR'
#!/bin/bash
while true; do
  CHOICE=$(whiptail --title "CL TECH OS MATRIX" --menu "Menu Principal:" 20 75 10 \
    "1" "Reproduzir Música no Terminal" \
    "2" "Status do Sistema" \
    "3" "Logs Cloudflare" \
    "4" "Reiniciar Serviços" \
    "5" "Sair" 3>&1 1>&2 2>&3)
  case $CHOICE in
    1) read -p "🎵 Música: " m; mpv --no-video "$(yt-dlp -g "ytsearch1:$m")" ;;
    2) uptime && free -h ;;
    3) tail -n 30 logs/cf.log 2>/dev/null || echo "Sem logs" ;;
    4) systemctl restart cltech cloudflare ;;
    5) exit ;;
  esac
done
MONITOR

chmod +x monitor.sh
echo 'alias cltech="cd /opt/cltech && ./monitor.sh"' >> /root/.bashrc

# ==================== INICIALIZAÇÃO ====================
pm2 start server.js --name cltech
pm2 save

systemctl daemon-reload
systemctl enable --now cltech.service
systemctl enable --now cloudflare.service

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "✅ CL TECH OS v4.3 MATRIX + CLOUDFLARE INSTALADO!"
echo "══════════════════════════════════════════════════════════════"
echo "✅ Cloudflare Tunnel configurado como serviço systemd"
echo ""
echo "Comandos úteis:"
echo "   cltech                    → Abrir monitor"
echo "   systemctl status cloudflare → Ver status do túnel"
echo "   source /root/.bashrc"
echo "══════════════════════════════════════════════════════════════"