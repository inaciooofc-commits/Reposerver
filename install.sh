#!/bin/bash
# ================================================
# CL TECH OS v4.3 - Instalador Completo
# antiX Panel + Sasuke Background + YouTube API
# Google Search + Terminal Hacker + Admin Panel
# ================================================

set -e

echo "🔥 Iniciando instalação do CL TECH OS v4.3 COMPLETO..."

if [[ $EUID -ne 0 ]]; then
   echo "❌ Execute como root (sudo)"
   exit 1
fi

# ==================== PACOTES ====================
apt-get update -qq
apt-get install -y curl wget git ffmpeg mpv yt-dlp whiptail build-essential ufw

# Node.js + PM2
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi
npm install -g pm2 --silent

# Cloudflared
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb || apt-get install -f -y
    rm -f cloudflared-linux-amd64.deb
fi

# ==================== DIRETÓRIOS ====================
mkdir -p /opt/cltech/{public,logs,downloads}
cd /opt/cltech

touch logs/cltech.log logs/cf.log

# ==================== CONFIG ====================
cat > config.json << EOF
{
  "port": 3000,
  "pixKey": "566.019.878.32",
  "pixName": "Pedro Inácio dos Santos de Menezes",
  "adminUser": "admin",
  "adminPass": "admin2026",
  "youtubeApiKey": "AIzaSyBkqc97R1Xztd71hnl4BaWzPtNpLjaMZJc"
}
EOF

# ==================== FIREWALL ====================
echo "🔒 Configurando Firewall..."
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

# ==================== FRONTEND ====================
# Fundo Sasuke
wget -q -O public/background.jpg "https://images.unsplash.com/photo-1618331837616-9e2f8c3e0c7e" || true

cat > public/index.html << 'HTML'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>antiX Control Panel</title>
    <style>
        body {
            font-family: 'Segoe UI', sans-serif;
            background: linear-gradient(rgba(0,0,0,0.75), rgba(0,0,0,0.9)), url('/background.jpg');
            background-size: cover;
            background-position: center;
            color: white;
            height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }
        .card {
            background: rgba(15,23,42,0.95);
            padding: 40px;
            border-radius: 16px;
            width: 420px;
            box-shadow: 0 20px 40px rgba(0,0,0,0.6);
        }
        input, button { width: 100%; padding: 14px; margin: 10px 0; border-radius: 8px; }
        button { background: #3b82f6; font-weight: 600; cursor: pointer; }
        button:hover { background: #2563eb; }
    </style>
</head>
<body>
    <div class="card">
        <h2 style="text-align:center;">antiX Control Panel</h2>
        <input type="text" id="username" value="admin" placeholder="Usuário">
        <input type="password" id="password" value="admin2026" placeholder="Senha">
        <button onclick="login()">ENTRAR NO SISTEMA</button>
        <button onclick="window.location.href='/dashboard.html'" style="background:#7c3aed">Dashboard</button>
        <button onclick="window.location.href='/admin.html'" style="background:#6b21a8">🔧 Painel Admin</button>
    </div>

    <script>
        async function login() {
            const res = await fetch('/api/login', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({
                    username: document.getElementById('username').value,
                    password: document.getElementById('password').value
                })
            });
            const data = await res.json();
            if (data.success) window.location.href = '/dashboard.html';
            else alert("Credenciais inválidas");
        }
    </script>
</body>
</html>
HTML

# Dashboard com YouTube + Google
cat > public/dashboard.html << 'DASH'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - antiX</title>
    <style>
        body { background: linear-gradient(rgba(0,0,0,0.85), rgba(0,0,0,0.95)), url('/background.jpg'); background-size: cover; color:white; font-family:Segoe UI; padding:30px; }
        .result { background:rgba(255,255,255,0.1); padding:12px; margin:10px 0; border-radius:8px; }
    </style>
</head>
<body>
    <h1>🔍 CL TECH OS - Buscador</h1>
    <input type="text" id="query" placeholder="Buscar música ou qualquer coisa" style="width:65%; padding:12px;">
    <button onclick="searchYouTube()">🎵 YouTube</button>
    <button onclick="searchGoogle()">🌐 Google</button>

    <div id="results"></div>

    <script>
        async function searchYouTube() {
            const q = document.getElementById('query').value;
            const res = await fetch('/api/search-youtube?q=' + encodeURIComponent(q));
            const data = await res.json();
            let html = '';
            data.forEach(item => {
                html += `<div class="result"><strong>\( {item.title}</strong><br><button onclick="download(' \){item.videoId}')">⬇️ Baixar MP3</button></div>`;
            });
            document.getElementById('results').innerHTML = html;
        }

        function searchGoogle() {
            const q = document.getElementById('query').value;
            if(q) window.open('https://www.google.com/search?q=' + encodeURIComponent(q), '_blank');
        }

        async function download(videoId) {
            await fetch('/api/download-music', {
                method: 'POST',
                headers: {'Content-Type': 'application/json'},
                body: JSON.stringify({query: videoId})
            });
            alert('✅ Download iniciado!');
        }
    </script>
</body>
</html>
DASH

# Painel Admin
cat > public/admin.html << 'ADMIN'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <title>Painel Admin</title>
    <style>body{background:rgba(0,0,0,0.95);color:white;padding:40px;font-family:Segoe UI;}</style>
</head>
<body>
    <h1>🔧 Painel do Administrador</h1>
    <input type="text" id="bgUrl" placeholder="URL da nova imagem de fundo" style="width:100%;padding:12px;">
    <button onclick="changeBackground()" style="padding:12px;margin-top:10px;">Aplicar Fundo</button>

    <script>
        async function changeBackground() {
            const url = document.getElementById('bgUrl').value;
            if(url) {
                await fetch('/api/change-background', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({url})});
                alert('Fundo alterado com sucesso!');
                location.reload();
            }
        }
    </script>
</body>
</html>
ADMIN

# ==================== BACKEND ====================
cat > server.js << 'EOF'
const express = require('express');
const fs = require('fs');
const { execSync } = require('child_process');
const app = express();
const PORT = 3000;

app.use(express.json());
app.use(express.static('public'));

const config = JSON.parse(fs.readFileSync('config.json', 'utf8'));

app.post('/api/login', (req, res) => {
  const { username, password } = req.body;
  if (username === config.adminUser && password === config.adminPass) {
    res.json({ success: true });
  } else {
    res.status(401).json({ success: false, message: "Credenciais inválidas" });
  }
});

app.get('/api/search-youtube', async (req, res) => {
  const query = req.query.q;
  try {
    const response = await fetch(`https://www.googleapis.com/youtube/v3/search?part=snippet&q=\( {encodeURIComponent(query)}&type=video&maxResults=8&key= \){config.youtubeApiKey}`);
    const data = await response.json();
    const results = data.items.map(item => ({
      videoId: item.id.videoId,
      title: item.snippet.title
    }));
    res.json(results);
  } catch (e) {
    res.json([]);
  }
});

app.post('/api/download-music', (req, res) => {
  const { query } = req.body;
  try {
    execSync(`yt-dlp -x --audio-format mp3 -o "downloads/%(title)s.%(ext)s" "ytsearch1:${query}"`, {stdio: 'ignore'});
    res.json({success: true});
  } catch(e) {
    res.status(500).json({success: false});
  }
});

app.post('/api/change-background', (req, res) => {
  const { url } = req.body;
  try {
    execSync(`wget -q -O public/background.jpg "${url}"`, {stdio: 'ignore'});
    res.json({success: true});
  } catch(e) { res.status(500).json({success: false}); }
});

app.listen(PORT, () => console.log(`🚀 CL TECH OS v4.3 rodando em http://localhost:${PORT}`));
EOF

npm init -y --silent
npm install express --silent

# ==================== MONITOR TERMINAL HACKER ====================
cat > monitor.sh << 'MONITOR'
#!/bin/bash
clear
echo "=============================================================="
echo "          CL TECH OS v4.3 - MATRIX TERMINAL"
echo "               Pedro Inácio - São Paulo"
echo "=============================================================="
echo ""

while true; do
  echo "1) Buscar e Reproduzir Música"
  echo "2) Busca Rápida no Google"
  echo "3) Status Completo do Servidor"
  echo "4) Ver Logs"
  echo "5) Reiniciar Serviços"
  echo "6) Trocar Fundo do Painel"
  echo "7) Sair"
  echo ""
  read -p "→ Escolha: " choice

  case $choice in
    1) read -p "🎵 Música: " m; mpv --no-video "$(yt-dlp -g "ytsearch1:$m")" ;;
    2) read -p "🔍 Buscar: " g; xdg-open "https://google.com/search?q=$g" 2>/dev/null || echo "https://google.com/search?q=$g" ;;
    3) uptime; free -h; pm2 list; df -h ;;
    4) tail -n 30 logs/cltech.log ;;
    5) systemctl restart cltech ;;
    6) read -p "URL da imagem: " url; wget -q -O public/background.jpg "$url" && echo "Fundo alterado!" ;;
    7) echo "Saindo..."; exit 0 ;;
    *) echo "Opção inválida!" ;;
  esac
  echo ""
  read -p "Pressione ENTER para continuar..."
  clear
done
MONITOR

chmod +x monitor.sh
echo 'alias cltech="cd /opt/cltech && ./monitor.sh"' >> /root/.bashrc

# ==================== SERVIÇOS ====================
pm2 start server.js --name cltech
pm2 save

cat > /etc/systemd/system/cltech.service << EOF
[Unit]
Description=CL TECH OS Server
After=network.target
[Service]
Type=simple
WorkingDirectory=/opt/cltech
ExecStart=/usr/bin/pm2-runtime start server.js --name cltech
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now cltech.service

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "✅ CL TECH OS v4.3 INSTALADO COM SUCESSO!"
echo "══════════════════════════════════════════════════════════════"
echo "🌐 Painel: http://localhost:3000"
echo "🔧 Admin: http://localhost:3000/admin.html"
echo "💻 Terminal: cltech"
echo "══════════════════════════════════════════════════════════════"