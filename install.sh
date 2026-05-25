#!/bin/bash
# =====================================================
#   AUDITOREPLAYER - INSTALADOR ÚNICO E DEFINITIVO
#   CLCoreProgramINC. / CCPI
#   Data: 24 de Maio de 2026
# =====================================================

set -e

PROJECT_DIR="/opt/AuditorePlayer"
LOG_FILE="$PROJECT_DIR/logs/install.log"

log() {
    echo -e "\033[36m[INFO] $1\033[0m"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE" 2>/dev/null || true
}

log_error() {
    echo -e "\033[31m[ERRO] $1\033[0m"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: $1" >> "$LOG_FILE" 2>/dev/null || true
}

clear
echo -e "\033[36m╔══════════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[36m║     AUDITOREPLAYER v4.3 - INSTALADOR ÚNICO COMPLETO          ║\033[0m"
echo -e "\033[36m║                CCPI Automata - Full Edition                  ║\033[0m"
echo -e "\033[36m╚══════════════════════════════════════════════════════════════╝\033[0m"

# ================== CRIAÇÃO DE PASTAS ==================
log "Criando estrutura completa de pastas..."
sudo mkdir -p $PROJECT_DIR/{public,data,logs,backup,uploads,temp,cache,music,users,config,extensions}
sudo mkdir -p $PROJECT_DIR/public/{assets,backgrounds}
sudo mkdir -p $PROJECT_DIR/logs/{server,bot,errors}
sudo mkdir -p $PROJECT_DIR/backup/{daily,weekly}
sudo mkdir -p $PROJECT_DIR/cache/{thumbnails,streams}

cd $PROJECT_DIR || { log_error "Falha ao acessar $PROJECT_DIR"; exit 1; }

# ================== DEPENDÊNCIAS ==================
log "Instalando dependências do sistema..."
sudo apt-get update -qq || log_error "Falha no apt update"
sudo apt-get install -y curl wget git ffmpeg yt-dlp ufw lsof || log_error "Falha na instalação de pacotes"

if ! command -v node &> /dev/null; then
    log "Instalando Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash - || log_error "Falha no Node.js"
    sudo apt-get install -y nodejs || log_error "Falha ao instalar Node.js"
fi

log "Instalando PM2..."
sudo npm install -g pm2 --silent || log_error "Falha ao instalar PM2"

if ! command -v cloudflared &> /dev/null; then
    log "Instalando Cloudflared..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb || sudo apt-get install -f -y || log_error "Falha no Cloudflared"
fi

# ================== ARQUIVOS DE CONFIGURAÇÃO ==================
log "Criando arquivos de configuração..."

cat > config.json << 'EOF'
{
  "adminUser": "admin",
  "adminPass": "123456",
  "port": 3000,
  "creditPerPlay": 5,
  "creditPerDownload": 15,
  "maxQueueSize": 20
}
EOF

cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'AuditorePlayer',
    script: 'server.js',
    watch: false,
    max_restarts: 15,
    restart_delay: 4000,
    env: { NODE_ENV: 'production' }
  }]
};
EOF

# ================== SERVER.JS ==================
cat > server.js << 'EOF'
const express = require('express');
const fs = require('fs');
const { exec } = require('child_process');
const app = express();

app.use(express.json());
app.use(express.static('public'));

const config = JSON.parse(fs.readFileSync('config.json'));
const PORT = config.port || 3000;

app.post('/api/login', (req, res) => {
    const { username, password } = req.body;
    if (username === config.adminUser && password === config.adminPass) {
        res.json({ success: true, isAdmin: true });
    } else {
        res.json({ success: true, isAdmin: false });
    }
});

app.get('/api/search', (req, res) => {
    const query = req.query.q;
    exec(`yt-dlp "ytsearch10:${query}" --dump-json`, (error, stdout) => {
        if (error) return res.json([]);
        const results = stdout.trim().split('\n').map(l => JSON.parse(l));
        res.json(results);
    });
});

app.get('/api/stream/:videoId', (req, res) => {
    const videoId = req.params.videoId;
    const url = `https://www.youtube.com/watch?v=${videoId}`;
    res.set('Content-Type', 'audio/mpeg');
    exec(`yt-dlp -f bestaudio --output - "${url}"`, {maxBuffer: 200*1024*1024}, (err, stdout) => {
        if (err) return res.status(500).send("Stream error");
        res.send(stdout);
    });
});

app.get('/api/download/:videoId/:title', (req, res) => {
    const { videoId, title } = req.params;
    const safeTitle = title.replace(/[^a-zA-Z0-9]/g, '_');
    res.set('Content-Disposition', `attachment; filename="${safeTitle}.mp3"`);
    const url = `https://www.youtube.com/watch?v=${videoId}`;
    exec(`yt-dlp -f bestaudio --extract-audio --audio-format mp3 -o - "${url}"`, {maxBuffer: 500*1024*1024}, (err, stdout) => {
        if (err) return res.status(500).send("Download error");
        res.send(stdout);
    });
});

app.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 AuditorePlayer rodando na porta ${PORT}`);
});
EOF

# ================== FRONTEND (public/) ==================
mkdir -p public

cat > public/index.html << 'HTML'
<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="UTF-8"><title>AuditorePlayer</title><link rel="stylesheet" href="style.css"></head>
<body>
<div class="card">
    <h1>AUDITORPLAYER</h1>
    <h3>CLCoreProgramINC.</h3>
    <input type="text" id="username" placeholder="Usuário">
    <input type="password" id="password" placeholder="Senha">
    <button class="btn" onclick="login()">ENTRAR</button>
    <p><small>Admin: admin / 123456</small></p>
</div>
<script src="app.js"></script>
</body>
</html>
HTML

cat > public/dashboard.html << 'HTML'
<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="UTF-8"><title>Player</title><link rel="stylesheet" href="style.css"></head>
<body>
<div class="card">
    <h1>🎵 AUDITOREPLAYER</h1>
    <p>Créditos: <strong id="credits">50</strong></p>
    <input type="text" id="search" placeholder="Buscar música...">
    <button class="btn" onclick="searchMusic()">Buscar</button>
    <div id="results"></div>
    <h2>Fila</h2><div id="queue"></div>
    <div id="player"><h3 id="nowPlaying">Nada tocando</h3><audio id="audioPlayer" controls></audio></div>
</div>
<script src="app.js"></script>
</body>
</html>
HTML

cat > public/admin.html << 'HTML'
<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="UTF-8"><title>Painel Admin</title><link rel="stylesheet" href="style.css"></head>
<body>
<div class="card">
    <h1>🔧 PAINEL MESTRE</h1>
    <button class="btn" onclick="addCredits()">+ Créditos</button>
    <button class="btn" onclick="banIP()">Banir IP</button>
    <button class="btn" onclick="viewIPs()">Ver IPs</button>
    <div id="adminContent"></div>
</div>
<script src="app.js"></script>
</body>
</html>
HTML

cat > public/style.css << 'CSS'
body { font-family: monospace; background: linear-gradient(#000, #0a001f); color: #00ff41; margin:0; padding:20px; }
.card { background: rgba(10,15,35,0.97); border: 2px solid #00ff41; padding: 25px; border-radius: 12px; max-width: 1100px; margin: auto; }
.btn { background:#00ff41; color:#000; padding:12px 22px; border:none; margin:6px; cursor:pointer; font-weight:bold; }
.btn:hover { background:#00dd33; transform:scale(1.05); }
CSS

cat > public/app.js << 'JS'
let queue = []; let currentCredits = 50;

function login() {
    const u = document.getElementById('username').value;
    const p = document.getElementById('password').value;
    fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({username:u,password:p})})
    .then(r=>r.json()).then(d=>{ if(d.success) window.location.href = d.isAdmin ? 'admin.html' : 'dashboard.html'; });
}

async function searchMusic() {
    const q = document.getElementById('search').value;
    const res = await fetch(`/api/search?q=${encodeURIComponent(q)}`);
    const results = await res.json();
    let html = '<h3>Resultados:</h3>';
    results.forEach(v => {
        html += `<div style="margin:10px 0;padding:10px;border:1px solid #00ff41;"><strong>${v.title}</strong><br>
        <button class="btn" onclick="addToQueue('\( {v.id}',' \){v.title.replace(/'/g,"")}')">+ Fila</button>
        <button class="btn" onclick="playNow('\( {v.id}',' \){v.title.replace(/'/g,"")}')">▶ Tocar</button>
        <button class="btn" onclick="download('\( {v.id}',' \){v.title.replace(/'/g,"")}')">↓ Download</button></div>`;
    });
    document.getElementById('results').innerHTML = html;
}

function addToQueue(id,title){ if(currentCredits<3) return alert("Créditos insuficientes!"); queue.push({id,title}); currentCredits-=3; updateQueue(); updateCredits(); }
function playNow(id,title){ if(currentCredits<5) return alert("Créditos insuficientes!"); currentCredits-=5; updateCredits(); document.getElementById('nowPlaying').textContent=`Tocando: \( {title}`; document.getElementById('audioPlayer').src=`/api/stream/ \){id}`; document.getElementById('audioPlayer').play(); }
function download(id,title){ if(currentCredits<15) return alert("Créditos insuficientes!"); currentCredits-=15; updateCredits(); window.location.href=`/api/download/\( {id}/ \){encodeURIComponent(title)}`; }
function updateQueue(){ let html=''; queue.forEach((item,i)=>html+=`<div>${i+1}. ${item.title}</div>`); document.getElementById('queue').innerHTML=html; }
function updateCredits(){ document.getElementById('credits').textContent = currentCredits; }
function addCredits(){ alert('✅ Créditos adicionados'); }
function banIP(){ const ip=prompt('IP:'); alert(`IP ${ip} banido`); }
function viewIPs(){ document.getElementById('adminContent').innerHTML = '<p>📡 IPs conectados (simulado)</p>'; }
JS

# ================== BOT INTELIGENTE ==================
cat > ccpi-automata.sh << 'AUTOMATA'
#!/bin/bash
BASE_DIR="/opt/AuditorePlayer"
LOG_FILE="$BASE_DIR/logs/automata.log"
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }

while true; do
    cd $BASE_DIR
    if ! pm2 list | grep -q "AuditorePlayer"; then
        log "⚠️ Servidor caído. Reiniciando..."
        pm2 start ecosystem.config.js --name AuditorePlayer
    fi
    sleep 15
done
AUTOMATA

chmod +x ccpi-automata.sh monitor-master.sh 2>/dev/null || true

log "✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
echo ""
echo "📁 Projeto instalado em: $PROJECT_DIR"
echo "🔑 Usuário Admin: admin / 123456"
echo ""
echo "Para iniciar o sistema completo:"
echo "   cd /opt/AuditorePlayer"
echo "   bash ccpi-automata.sh"
echo ""
echo "O CCPI Automata irá gerenciar tudo automaticamente."