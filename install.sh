#!/bin/bash
# ================================================
# CL TECH OS - Instalador Automático v2.0
# Com Logs em Tempo Real + Download + Stickers WA
# ================================================

set -e

echo "🔥 Iniciando instalação do CL TECH OS v2.0..."

if [[ $EUID -ne 0 ]]; then
   echo "❌ Execute como root (sudo)"
   exit 1
fi

# Atualização e dependências
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y curl wget git build-essential python3 jq ffmpeg

# Node.js
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi

npm install -g pm2 --silent

# Cloudflared
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb && rm cloudflared-linux-amd64.deb
fi

# Diretórios
mkdir -p /opt/cltech/{public,users,logs,downloads,stickers}
cd /opt/cltech

# ==================== CONFIG ====================
cat > config.json << EOF
{
  "port": 3000,
  "downloadPath": "/downloads",
  "stickerPath": "/stickers"
}
EOF

# ==================== FRONTEND ====================
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CL TECH OS</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <div class="container">
    <header>
      <h1>CL TECH OS <span style="color:#ff69b4">v2.0</span></h1>
      <div class="tabs">
        <button onclick="showTab(0)" class="active">Músicas</button>
        <button onclick="showTab(1)">Logs em Tempo Real</button>
        <button onclick="logout()">Sair</button>
      </div>
    </header>

    <!-- TAB 1: MUSIC -->
    <div id="tab0" class="tab active">
      <input type="text" id="searchInput" placeholder="Buscar no YouTube..." onkeyup="if(event.key==='Enter') searchMusic()">
      <button onclick="searchMusic()">🔎 Buscar</button>
      
      <div id="results" class="results"></div>
    </div>

    <!-- TAB 2: LOGS -->
    <div id="tab1" class="tab hidden">
      <div id="logContainer" class="log-window"></div>
      <button onclick="clearLogs()">Limpar Logs</button>
    </div>
  </div>

  <!-- PLAYER FIXO -->
  <div class="player">
    <div id="nowPlaying">Nenhuma música tocando</div>
    <iframe id="ytPlayer" width="100%" height="120" frameborder="0" allow="autoplay"></iframe>
  </div>

  <script src="app.js"></script>
</body>
</html>
EOF

# ==================== CSS ====================
cat > public/style.css << 'EOF'
* { margin:0; padding:0; box-sizing:border-box; }
body { font-family: 'Segoe UI', sans-serif; background:#0a0a0a; color:#fff; }

.container { padding: 20px; max-width: 1200px; margin: auto; }
header { display:flex; justify-content:space-between; align-items:center; margin-bottom:20px; }
h1 { color: #ff69b4; }

.tabs button {
  padding: 10px 20px;
  background: #111;
  border: 1px solid #ff69b4;
  color: #ff69b4;
  margin-right: 8px;
  border-radius: 8px;
  cursor: pointer;
}
.tabs button.active { background: #ff69b4; color: black; }

.tab { display: none; }
.tab.active { display: block; }

.result-item {
  background: rgba(255,255,255,0.06);
  margin: 10px 0;
  padding: 15px;
  border-radius: 12px;
  cursor: pointer;
  transition: 0.3s;
}
.result-item:hover { background: rgba(255,105,180,0.2); transform: scale(1.02); }

.log-window {
  background: #000;
  border: 1px solid #ff69b4;
  height: 70vh;
  overflow-y: auto;
  padding: 15px;
  font-family: monospace;
  white-space: pre-wrap;
  color: #0f0;
}

.player {
  position: fixed;
  bottom: 0; left: 0; right: 0;
  background: #111;
  border-top: 3px solid #ff69b4;
  padding: 12px;
}
EOF

# ==================== APP.JS (Frontend) ====================
cat > public/app.js << 'EOF'
let currentUser = null;
let logEventSource = null;

function showTab(n) {
  document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
  document.getElementById(`tab${n}`).classList.add('active');
  
  if (n === 1 && !logEventSource) startLogs();
}

async function searchMusic() {
  const q = document.getElementById('searchInput').value.trim();
  if (!q) return;

  const res = await fetch(`/search-music?q=${encodeURIComponent(q)}`);
  const results = await res.json();

  const container = document.getElementById('results');
  container.innerHTML = '';

  results.forEach(song => {
    const div = document.createElement('div');
    div.className = 'result-item';
    div.innerHTML = `
      <strong>${song.title}</strong><br>
      <small>${song.channel} • ${song.duration}</small><br>
      <button onclick="playSong('${song.url}', '${song.title}'); event.stopImmediatePropagation()">▶ Play</button>
      <button onclick="downloadMusic('${song.url}', '${song.title}'); event.stopImmediatePropagation()">⬇️ Baixar MP3</button>
      <button onclick="createSticker('${song.thumbnail}', '${song.title}'); event.stopImmediatePropagation()">🖼️ Sticker</button>
      <button onclick="sendToWhatsApp('${song.url}', '${song.title}'); event.stopImmediatePropagation()">📱 WhatsApp</button>
    `;
    container.appendChild(div);
  });
}

function playSong(url, title) {
  document.getElementById('nowPlaying').textContent = title;
  const videoId = url.split('v=')[1] || url.split('/').pop();
  document.getElementById('ytPlayer').src = `https://www.youtube.com/embed/${videoId}?autoplay=1`;
}

async function downloadMusic(url, title) {
  const res = await fetch(`/download?url=${encodeURIComponent(url)}&title=${encodeURIComponent(title)}`);
  const data = await res.json();
  if (data.success) {
    alert(`✅ Música pronta! Baixando: ${data.filename}`);
    window.open(`/downloads/${data.filename}`, '_blank');
  } else {
    alert("Erro no download");
  }
}

async function createSticker(thumb, title) {
  const res = await fetch(`/create-sticker`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({image: thumb, title: title})
  });
  const data = await res.json();
  if (data.success) {
    alert(`✅ Figurinha criada!\nSalva em: ${data.path}`);
  }
}

function sendToWhatsApp(url, title) {
  const text = encodeURIComponent(`🎵 *${title}*\n${url}\n\nEnviado via CL TECH OS`);
  window.open(`https://wa.me/?text=${text}`, '_blank');
}

function startLogs() {
  logEventSource = new EventSource('/logs');
  logEventSource.onmessage = (e) => {
    const logDiv = document.getElementById('logContainer');
    logDiv.innerHTML += e.data + '\n';
    logDiv.scrollTop = logDiv.scrollHeight;
  };
}

function clearLogs() {
  document.getElementById('logContainer').innerHTML = '';
}

function logout() {
  localStorage.clear();
  location.reload();
}
EOF

# ==================== BACKEND server.js ====================
cat > server.js << 'EOF'
const express = require('express');
const bcrypt = require('bcrypt');
const fs = require('fs');
const path = require('path');
const ytsr = require('ytsr');
const ytdl = require('ytdl-core');
const sharp = require('sharp');
const cors = require('cors');
const fetch = require('node-fetch');

const app = express();
const PORT = 3000;
const DOWNLOADS_DIR = path.join(__dirname, 'downloads');
const STICKERS_DIR = path.join(__dirname, 'stickers');

fs.mkdirSync(DOWNLOADS_DIR, { recursive: true });
fs.mkdirSync(STICKERS_DIR, { recursive: true });

app.use(cors());
app.use(express.json());
app.use(express.static('public'));
app.use('/downloads', express.static(DOWNLOADS_DIR));
app.use('/stickers', express.static(STICKERS_DIR));

// Users
const USERS_FILE = path.join(__dirname, 'users/users.json');

function loadUsers() {
  try {
    return JSON.parse(fs.readFileSync(USERS_FILE, 'utf8'));
  } catch {
    return [];
  }
}

function saveUsers(users) {
  fs.mkdirSync(path.dirname(USERS_FILE), { recursive: true });
  fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2));
}

function seedDefaultUser() {
  const users = loadUsers();
  if (users.length === 0) {
    const hash = bcrypt.hashSync('clzin', 10);
    users.push({ user: 'clzin', pass: hash });
    saveUsers(users);
  }
}

// Auth
app.post('/login', async (req, res) => {
  const { user, pass } = req.body;
  const users = loadUsers();
  const found = users.find(u => u.user === user);

  if (!found || !bcrypt.compareSync(pass, found.pass)) {
    return res.status(401).json({ ok: false });
  }
  res.json({ ok: true, token: Buffer.from(user).toString('base64') });
});

app.post('/register', async (req, res) => {
  const { user, pass } = req.body;
  let users = loadUsers();
  const hash = bcrypt.hashSync(pass, 10);
  users.push({ user, pass: hash });
  saveUsers(users);
  res.json({ ok: true });
});

// Logs em tempo real (SSE)
app.get('/logs', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  const logInterval = setInterval(() => {
    const log = `[${new Date().toISOString()}] Sistema ativo - CL TECH OS v2.0`;
    res.write(`data: ${log}\n\n`);
  }, 1500);

  req.on('close', () => clearInterval(logInterval));
});

// Search YouTube
app.get('/search-music', async (req, res) => {
  try {
    const { q } = req.query;
    const results = await ytsr(q, { limit: 10 });
    
    const videos = results.items.filter(item => item.type === 'video').map(v => ({
      title: v.title,
      url: v.url,
      thumbnail: v.thumbnail,
      channel: v.author.name,
      duration: v.duration
    }));

    res.json(videos);
  } catch (e) {
    res.status(500).json({ error: 'Erro na busca' });
  }
});

// Download MP3
app.get('/download', async (req, res) => {
  const { url, title } = req.query;
  try {
    const filename = `${title.replace(/[^a-zA-Z0-9]/g, '_')}.mp3`;
    const filePath = path.join(DOWNLOADS_DIR, filename);

    const stream = ytdl(url, { filter: 'audioonly', quality: 'highestaudio' });
    const writeStream = fs.createWriteStream(filePath);

    stream.pipe(writeStream);
    writeStream.on('finish', () => {
      res.json({ success: true, filename });
    });
  } catch (e) {
    res.status(500).json({ success: false });
  }
});

// Criar Figurinha WhatsApp
app.post('/create-sticker', async (req, res) => {
  try {
    const { image, title } = req.body;
    const filename = `${Date.now()}.webp`;
    const outputPath = path.join(STICKERS_DIR, filename);

    const response = await fetch(image);
    const buffer = await response.buffer();

    await sharp(buffer)
      .resize(512, 512, { fit: 'cover' })
      .webp({ quality: 90 })
      .toFile(outputPath);

    res.json({ success: true, path: `/stickers/${filename}` });
  } catch (e) {
    res.status(500).json({ success: false });
  }
});

seedDefaultUser();
app.listen(PORT, () => console.log(`🚀 CL TECH OS v2.0 rodando na porta ${PORT}`));
EOF

# ==================== DEPENDÊNCIAS ====================
npm init -y --silent
npm install express bcrypt ytsr ytdl-core sharp cors node-fetch --silent

# ==================== FINALIZAÇÃO ====================
pm2 start server.js --name "cltech" --no-autorestart
pm2 save

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "🔥 CL TECH OS v2.0 INSTALADO COM SUCESSO!"
echo "══════════════════════════════════════════════════════════════"
echo "🌐 Acesse: http://localhost:3000"
echo "👤 Usuário: clzin | Senha: clzin"
echo "📱 Funcionalidades: Download MP3, Stickers WhatsApp, Logs ao vivo"
echo "══════════════════════════════════════════════════════════════"
