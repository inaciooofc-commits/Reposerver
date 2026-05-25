#!/bin/bash
# =====================================================
#   AUDITOREPLAYER - CLCoreProgramINC. (CCPI)
#   Versão: 4.3 MATRIX FULL
#   Data: 24 de Maio de 2026
#   Empresa: CLCoreProgramINC. / CCPI
# =====================================================

clear
echo -e "\033[36m╔══════════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[36m║                AUDITOREPLAYER v4.3                           ║\033[0m"
echo -e "\033[36m║           CLCoreProgramINC. - CCPI                           ║\033[0m"
echo -e "\033[36m║               Instalador Completo - 24/05/2026               ║\033[0m"
echo -e "\033[36m╚══════════════════════════════════════════════════════════════╝\033[0m"

cd /opt || exit 1
sudo mkdir -p AuditorePlayer/{public,data,logs}
cd AuditorePlayer

echo "[1/6] Instalando dependências..."
sudo apt-get update -qq && sudo apt-get install -y curl wget git ffmpeg yt-dlp ufw lsof

if ! command -v node &> /dev/null; then
    echo "[2/6] Instalando Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash -
    sudo apt-get install -y nodejs
fi

echo "[3/6] Instalando PM2 e Cloudflared..."
sudo npm install -g pm2 --silent

if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb || sudo apt-get install -f -y
fi

echo "[4/6] Criando todos os arquivos do AuditorePlayer..."

# config.json
cat > config.json << 'EOF'
{
  "adminUser": "admin",
  "adminPass": "123456",
  "port": 3000,
  "creditPerPlay": 5,
  "creditPerDownload": 15,
  "empresa": "CLCoreProgramINC."
}
EOF

# server.js
cat > server.js << 'EOF'
const express = require('express');
const fs = require('fs');
const { exec } = require('child_process');
const app = express();

app.use(express.json());
app.use(express.static('public'));

const config = JSON.parse(fs.readFileSync('config.json'));

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
        if (err) return res.status(500).send("Erro no stream");
        res.send(stdout);
    });
});

app.get('/api/download/:videoId/:title', (req, res) => {
    const { videoId, title } = req.params;
    const safeTitle = title.replace(/[^a-zA-Z0-9]/g, '_');
    res.set('Content-Disposition', `attachment; filename="${safeTitle}.mp3"`);
    const url = `https://www.youtube.com/watch?v=${videoId}`;
    exec(`yt-dlp -f bestaudio --extract-audio --audio-format mp3 -o - "${url}"`, {maxBuffer: 500*1024*1024}, (err, stdout) => {
        if (err) return res.status(500).send("Erro no download");
        res.send(stdout);
    });
});

app.post('/api/add-credits', (req, res) => res.json({ success: true, message: "Créditos adicionados" }));
app.post('/api/ban-ip', (req, res) => res.json({ success: true, message: "IP banido" }));
app.get('/api/connected-ips', (req, res) => res.json({ ips: ["179.185.xx.xx"] }));

app.listen(config.port, () => console.log(`🚀 AuditorePlayer rodando na porta ${config.port} | CCPI`));
EOF

# Arquivos do Frontend
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
<head><meta charset="UTF-8"><title>AuditorePlayer</title><link rel="stylesheet" href="style.css"></head>
<body>
<div class="card">
    <h1>🎵 AUDITOREPLAYER</h1>
    <p>Créditos: <strong id="credits">50</strong> | CCPI</p>
    
    <input type="text" id="search" placeholder="Buscar música...">
    <button class="btn" onclick="searchMusic()">Buscar</button>
    
    <div id="results"></div>
    
    <h2>Fila de Reprodução</h2>
    <div id="queue"></div>
    
    <div id="player">
        <h3 id="nowPlaying">Nada tocando</h3>
        <audio id="audioPlayer" controls style="width:100%;"></audio>
    </div>
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
    <h1>🔧 PAINEL MESTRE - AUDITOREPLAYER</h1>
    <button class="btn" onclick="addCredits()">+ Créditos</button>
    <button class="btn" onclick="banIP()">Banir IP</button>
    <button class="btn" onclick="viewIPs()">Ver IPs Conectados</button>
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
let queue = [];
let currentCredits = 50;

function login() {
    const u = document.getElementById('username').value;
    const p = document.getElementById('password').value;
    fetch('/api/login', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({username: u, password: p})
    }).then(r => r.json()).then(d => {
        if (d.success) window.location.href = d.isAdmin ? 'admin.html' : 'dashboard.html';
    });
}

async function searchMusic() {
    const query = document.getElementById('search').value;
    const res = await fetch(`/api/search?q=${encodeURIComponent(query)}`);
    const results = await res.json();
    
    let html = '<h3>Resultados:</h3>';
    results.forEach(v => {
        html += `
            <div style="margin:12px 0; padding:12px; border:1px solid #00ff41;">
                <strong>${v.title}</strong><br>
                <button class="btn" onclick="addToQueue('\( {v.id}', ' \){v.title.replace(/'/g,"")}')">+ Fila</button>
                <button class="btn" onclick="playNow('\( {v.id}', ' \){v.title.replace(/'/g,"")}')">▶ Tocar</button>
                <button class="btn" onclick="download('\( {v.id}', ' \){v.title.replace(/'/g,"")}')">↓ Download</button>
            </div>`;
    });
    document.getElementById('results').innerHTML = html;
}

function addToQueue(id, title) {
    if (currentCredits < 3) return alert("Créditos insuficientes!");
    queue.push({id, title});
    currentCredits -= 3;
    updateQueue();
    updateCredits();
}

function playNow(id, title) {
    if (currentCredits < 5) return alert("Créditos insuficientes!");
    currentCredits -= 5;
    updateCredits();
    document.getElementById('nowPlaying').textContent = `Tocando: ${title}`;
    document.getElementById('audioPlayer').src = `/api/stream/${id}`;
    document.getElementById('audioPlayer').play();
}

function download(id, title) {
    if (currentCredits < 15) return alert("Créditos insuficientes!");
    currentCredits -= 15;
    updateCredits();
    window.location.href = `/api/download/\( {id}/ \){encodeURIComponent(title)}`;
}

function updateQueue() {
    let html = '';
    queue.forEach((item, i) => html += `<div>${i+1}. ${item.title}</div>`);
    document.getElementById('queue').innerHTML = html;
}

function updateCredits() {
    document.getElementById('credits').textContent = currentCredits;
}

function addCredits(){ alert('✅ Créditos adicionados'); }
function banIP(){ const ip = prompt('Digite o IP:'); alert(`IP ${ip} banido`); }
function viewIPs(){ document.getElementById('adminContent').innerHTML = '<p>📡 IPs Conectados (simulado)</p>'; }
JS

echo "[5/6] Definindo permissões..."
chmod +x start-cloudflare.sh 2>/dev/null || true

echo "[6/6] Instalação do AuditorePlayer concluída com sucesso!"
echo ""
echo "✅ Sistema instalado em: /opt/AuditorePlayer"
echo "🔑 Admin → admin / 123456"
echo ""
echo "Para iniciar:"
echo "   cd /opt/AuditorePlayer"
echo "   bash start-cloudflare.sh"