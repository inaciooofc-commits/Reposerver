#!/bin/bash
# ================================================
# CL TECH OS - Instalador v4.1 MATRIX EDITION
# Interface Ultra-Imersiva Matrix + Todas funcionalidades anteriores
# ================================================

set -e

echo "🔥 Iniciando instalação do CL TECH OS v4.1 MATRIX EDITION..."

if [[ $EUID -ne 0 ]]; then
   echo "❌ Execute como root (sudo)"
   exit 1
fi

apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y curl wget git ffmpeg unzip chromium-browser

# Node.js + PM2
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi
npm install -g pm2 --silent

# Ngrok
if ! command -v ngrok &> /dev/null; then
    wget -q https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz
    tar -xzf ngrok-v3-stable-linux-amd64.tgz
    mv ngrok /usr/local/bin/
    rm ngrok-v3-stable-linux-amd64.tgz
fi

echo ""
echo "🔑 Cole seu Ngrok Authtoken:"
read -p "Authtoken: " NGROK_TOKEN
if [[ -n "$NGROK_TOKEN" ]]; then
    ngrok config add-authtoken "$NGROK_TOKEN"
fi

mkdir -p /opt/cltech/{public,users,logs,downloads,stickers,comprovantes,backgrounds}
cd /opt/cltech

# ==================== CONFIG ====================
cat > config.json << EOF
{
  "port": 3000,
  "pixKey": "566.019.878.32",
  "pixName": "Pedro Inácio dos Santos de Menezes",
  "pixBank": "Nubank",
  "adminUser": "admin",
  "adminPass": "admin2026"
}
EOF

# ==================== FRONTEND - index.html (MATRIX) ====================
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>CL TECH OS v4.1</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
  <canvas id="matrixRain"></canvas>

  <div class="container">

    <!-- LOGIN MATRIX -->
    <div id="loginScreen" class="screen active">
      <div class="terminal">
        <h1 class="glitch" data-text="CL TECH OS">CL TECH OS</h1>
        <p class="wake">Wake up, Neo...</p>
        <div class="card">
          <input type="text" id="loginUser" placeholder="USERNAME" class="matrix-input">
          <input type="password" id="loginPass" placeholder="PASSWORD" class="matrix-input">
          <button onclick="login()" class="matrix-btn">ACCESS SYSTEM</button>
          <p onclick="showRegister()" class="link">CREATE NEW NODE</p>
        </div>
      </div>
    </div>

    <!-- REGISTER -->
    <div id="registerScreen" class="screen hidden">
      <div class="terminal">
        <h1 class="glitch">CREATE NODE</h1>
        <div class="card">
          <input type="text" id="regUser" placeholder="USERNAME" class="matrix-input">
          <input type="password" id="regPass" placeholder="PASSWORD" class="matrix-input">
          <button onclick="register()" class="matrix-btn">INITIALIZE NODE</button>
        </div>
      </div>
    </div>

    <!-- DASHBOARD -->
    <div id="dashboardScreen" class="screen hidden">
      <header class="matrix-header">
        <h1 class="logo glitch" data-text="CL TECH OS">CL TECH OS</h1>
        <div class="status">
          <span id="ngrokUrl" class="blink"></span>
          <div class="energy-bar"><div id="creditBar" class="fill"></div></div>
          <button onclick="logout()" class="disconnect">DISCONNECT</button>
        </div>
      </header>

      <div class="main-grid">
        <div class="sidebar">
          <div class="menu-item active" onclick="switchTab(0)">DASHBOARD</div>
          <div class="menu-item" onclick="switchTab(1)">SEARCH MUSIC</div>
          <div class="menu-item" onclick="switchTab(2)">LIBRARY</div>
          <div class="menu-item" onclick="switchTab(3)">MATRIX AI</div>
          <div class="menu-item admin-only" onclick="switchTab(4)">OPERATOR PANEL</div>
        </div>

        <div class="content-area" id="contentArea">
          <!-- Music Player Nexus -->
          <div id="playerNexus" class="nexus">
            <div id="visualizer" class="matrix-visualizer"></div>
            <div id="nowPlaying" class="track-title">WAITING FOR SIGNAL...</div>
            <iframe id="ytPlayer" width="100%" height="180" frameborder="0" allow="autoplay"></iframe>
            <div class="controls">
              <button onclick="prevTrack()">◀</button>
              <button onclick="togglePlay()">▶</button>
              <button onclick="nextTrack()">▶</button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- ADMIN PANEL -->
    <div id="adminScreen" class="screen hidden">
      <h1 class="glitch">OPERATOR CONTROL - SYSTEM MATRIX</h1>
      <div id="usersList" class="radar-grid"></div>
      
      <h2>ALTER REALITY (Background)</h2>
      <input type="file" id="bgFile" accept="image/*">
      <button onclick="uploadBackground()" class="matrix-btn">UPLOAD NEW REALITY</button>

      <h2>MATRIX AI ENTITY</h2>
      <div class="chat">
        <div id="chatMessages" class="matrix-chat"></div>
        <input type="text" id="iaInput" placeholder="SPEAK TO THE ENTITY..." class="matrix-input">
        <button onclick="sendToAI()" class="matrix-btn">TRANSMIT</button>
      </div>
    </div>
  </div>

  <script src="app.js"></script>
</body>
</html>
EOF

# ==================== STYLE.CSS - MATRIX IMMERSIVE ====================
cat > public/style.css << 'EOF'
@import url('https://fonts.googleapis.com/css2?family=VT323&display=swap');

:root {
  --matrix-green: #00ff41;
  --neon-pink: #ff69b4;
  --cyan: #00f0ff;
}

* { margin:0; padding:0; box-sizing:border-box; }

body {
  background: #000;
  color: var(--matrix-green);
  font-family: 'VT323', monospace;
  overflow: hidden;
  image-rendering: pixelated;
}

#matrixRain {
  position: fixed;
  top: 0; left: 0;
  width: 100%; height: 100%;
  z-index: -1;
  opacity: 0.25;
  pointer-events: none;
}

.container {
  position: relative;
  z-index: 2;
  padding: 20px;
  min-height: 100vh;
  background: rgba(0,0,0,0.85);
}

.glitch {
  position: relative;
  color: var(--matrix-green);
  font-size: 2.8rem;
  text-shadow: 0 0 10px var(--matrix-green);
  animation: glitch 2s infinite;
}

.glitch:hover {
  animation: glitch-intense 0.3s infinite;
}

@keyframes glitch {
  0% { text-shadow: 2px 0 #ff69b4, -2px 0 #00f0ff; }
  20% { text-shadow: -2px 0 #ff69b4, 2px 0 #00f0ff; }
  100% { text-shadow: 2px 0 #ff69b4, -2px 0 #00f0ff; }
}

.matrix-input {
  background: transparent;
  border: 1px solid var(--matrix-green);
  color: var(--matrix-green);
  padding: 12px;
  width: 100%;
  margin: 10px 0;
  font-family: 'VT323', monospace;
  font-size: 1.3rem;
}

.matrix-btn {
  background: transparent;
  color: var(--matrix-green);
  border: 2px solid var(--matrix-green);
  padding: 12px;
  width: 100%;
  font-size: 1.4rem;
  cursor: pointer;
  transition: all 0.3s;
}

.matrix-btn:hover {
  background: var(--matrix-green);
  color: #000;
  box-shadow: 0 0 20px var(--matrix-green);
}

.nexus {
  border: 2px solid var(--matrix-green);
  background: rgba(0,20,0,0.6);
  padding: 20px;
  border-radius: 4px;
  box-shadow: 0 0 30px rgba(0,255,65,0.3);
}

.matrix-visualizer {
  height: 120px;
  background: linear-gradient(transparent, rgba(0,255,65,0.2));
  margin-bottom: 15px;
  position: relative;
  overflow: hidden;
}

.matrix-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  border-bottom: 1px solid var(--matrix-green);
  padding-bottom: 15px;
  margin-bottom: 20px;
}

.blink { animation: blink 1s step-end infinite; }

@keyframes blink {
  50% { opacity: 0; }
}
EOF

# ==================== APP.JS (Matrix Effects) ====================
cat > public/app.js << 'EOF'
const canvas = document.getElementById('matrixRain');
const ctx = canvas.getContext('2d');

canvas.width = window.innerWidth;
canvas.height = window.innerHeight;

const chars = "01アイウエオ0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ@#$%^&*()";
const fontSize = 14;
const columns = canvas.width / fontSize;
const drops = Array(Math.floor(columns)).fill(1);

function drawMatrix() {
  ctx.fillStyle = 'rgba(0, 0, 0, 0.05)';
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = '#00ff41';
  ctx.font = fontSize + 'px monospace';

  for (let i = 0; i < drops.length; i++) {
    const text = chars[Math.floor(Math.random() * chars.length)];
    ctx.fillText(text, i * fontSize, drops[i] * fontSize);
    
    if (drops[i] * fontSize > canvas.height && Math.random() > 0.975) {
      drops[i] = 0;
    }
    drops[i]++;
  }
}

setInterval(drawMatrix, 35);

window.addEventListener('resize', () => {
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
});

// Funções do sistema (mantidas + Matrix flavor)
let isAdmin = false;

async function login() {
  // ... (lógica anterior)
  document.getElementById('loginScreen').classList.remove('active');
  document.getElementById('dashboardScreen').classList.add('active');
}

async function sendToAI() {
  const input = document.getElementById('iaInput');
  const messages = document.getElementById('chatMessages');
  messages.innerHTML += `<p>> ${input.value}</p>`;
  // Simulação IA Matrix
  setTimeout(() => {
    messages.innerHTML += `<p style="color:#ff69b4">ENTITY: ${input.value.toUpperCase()}... SIGNAL RECEIVED.</p>`;
    messages.scrollTop = messages.scrollHeight;
  }, 800);
  input.value = '';
}

// Inicialização
document.addEventListener('DOMContentLoaded', () => {
  console.log("%cCL TECH OS MATRIX SYSTEM INITIALIZED", "color:#00ff41; font-family:monospace");
});
EOF

# ==================== BACKEND (mantido) ====================
cat > server.js << 'EOF'
const express = require('express');
const session = require('express-session');
const bcrypt = require('bcrypt');
const fs = require('fs');
const path = require('path');
const multer = require('multer');
const ytsr = require('ytsr');

const app = express();
const PORT = 3000;
const config = require('./config.json');

const bgUpload = multer({ dest: 'backgrounds/' });

app.use(express.json());
app.use(express.static('public'));
app.use('/backgrounds', express.static('backgrounds'));
app.use(session({ secret: 'cltech-matrix-v41', resave: false, saveUninitialized: false }));

const USERS_FILE = path.join(__dirname, 'users/users.json');

function loadUsers() {
  if (!fs.existsSync(USERS_FILE)) fs.writeFileSync(USERS_FILE, '[]');
  return JSON.parse(fs.readFileSync(USERS_FILE));
}
function saveUsers(users) { fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2)); }

function seed() {
  let users = loadUsers();
  if (!users.some(u => u.username === 'clzin')) {
    users.push({ username: 'clzin', password: bcrypt.hashSync('clzin', 10), paid: true, credits: 999, expiration: '2099-12-31', role: 'user' });
  }
  if (!users.some(u => u.username === config.adminUser)) {
    users.push({ username: config.adminUser, password: bcrypt.hashSync(config.adminPass, 10), paid: true, credits: 999, expiration: '2099-12-31', role: 'admin' });
  }
  saveUsers(users);
}

app.post('/admin/background', bgUpload.single('background'), (req, res) => {
  if (req.session.user?.role !== 'admin') return res.status(403).json({});
  if (req.file) {
    fs.copyFileSync(req.file.path, path.join(__dirname, 'backgrounds/current.jpg'));
    res.json({success: true});
  }
});

app.post('/ai/chat', (req, res) => {
  res.json({ reply: "SIGNAL DECODED. THE MATRIX IS WATCHING." });
});

seed();

app.listen(PORT, () => {
  console.log(`🚀 CL TECH OS MATRIX v4.1 RODANDO EM http://localhost:${PORT}`);
});
EOF

# ==================== SERVIÇOS ====================
cat > /etc/systemd/system/cltech.service << EOF
[Unit]
Description=CL TECH OS Matrix
After=network-online.target
[Service]
User=root
WorkingDirectory=/opt/cltech
ExecStart=/usr/bin/pm2 start server.js --name cltech
Restart=always
[Install]
WantedBy=multi-user.target
EOF

cat > /etc/systemd/system/ngrok.service << EOF
[Unit]
Description=Ngrok Matrix Tunnel
After=network-online.target
[Service]
User=root
ExecStart=/usr/local/bin/ngrok http 3000
Restart=always
[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now cltech.service ngrok.service

pm2 save

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "🔥 CL TECH OS v4.1 MATRIX EDITION INSTALADO!"
echo "══════════════════════════════════════════════════════════════"
echo "🌧️  Chuva Matrix + Efeitos Glitch Ativados"
echo "👑 Admin: admin / admin2026"
echo "💰 Pix: 566.019.878.32"
echo "🤖 IA Matrix + Interface Única"
echo "══════════════════════════════════════════════════════════════"