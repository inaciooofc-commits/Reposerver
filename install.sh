#!/bin/bash
# ================================================
# CL TECH OS - Instalador v3.0
# Admin Dashboard + Gestão de Usuários + Créditos + Listening Live
# ================================================

set -e

echo "🔥 Iniciando instalação do CL TECH OS v3.0..."

if [[ $EUID -ne 0 ]]; then
   echo "❌ Execute como root"
   exit 1
fi

apt-get update -qq && apt-get upgrade -y -qq
apt-get install -y curl wget git ffmpeg

if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
    apt-get install -y nodejs
fi
npm install -g pm2 --silent

if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    dpkg -i cloudflared-linux-amd64.deb && rm -f cloudflared-linux-amd64.deb
fi

mkdir -p /opt/cltech/{public,users,logs,downloads,stickers,comprovantes}
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

# ==================== FRONTEND - index.html ====================
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

    <!-- LOGIN NORMAL -->
    <div id="loginScreen" class="screen active">
      <h1>CL TECH OS</h1>
      <div class="card">
        <h2>Login</h2>
        <input type="text" id="loginUser" placeholder="Usuário">
        <input type="password" id="loginPass" placeholder="Senha">
        <button onclick="login()">Entrar</button>
        <p onclick="showScreen('registerScreen')">Criar conta</p>
      </div>
    </div>

    <!-- REGISTER -->
    <div id="registerScreen" class="screen hidden">
      <h1>Criar Conta</h1>
      <div class="card">
        <input type="text" id="regUser" placeholder="Usuário">
        <input type="password" id="regPass" placeholder="Senha">
        <button onclick="register()">Cadastrar</button>
        <p onclick="showScreen('loginScreen')">Voltar</p>
      </div>
    </div>

    <!-- PAYMENT -->
    <div id="paymentScreen" class="screen hidden">
      <h1>Pagamento Pix</h1>
      <div class="card">
        <p><strong>Valor:</strong> R$ <span id="paymentValue">1</span></p>
        <p>Chave: 566.019.878.32 (Nubank - Pedro Inácio)</p>
        <input type="file" id="comprovante" accept="image/*,.pdf">
        <button onclick="uploadComprovante()">Enviar Comprovante</button>
      </div>
    </div>

    <!-- USER DASHBOARD -->
    <div id="dashboardScreen" class="screen hidden">
      <header>
        <h1>CL TECH OS</h1>
        <button onclick="logout()">Sair</button>
      </header>
      <input type="text" id="searchInput" placeholder="Buscar música..." onkeyup="if(event.key==='Enter') searchMusic()">
      <button onclick="searchMusic()">🔎 Buscar</button>
      <div id="results"></div>
    </div>

    <!-- ADMIN DASHBOARD -->
    <div id="adminScreen" class="screen hidden">
      <header>
        <h1>ADMIN DASHBOARD</h1>
        <button onclick="logout()">Sair</button>
      </header>
      <h2>Usuários Ativos</h2>
      <div id="usersList"></div>
      
      <h2>Listening em Tempo Real</h2>
      <div id="listeningLive"></div>
    </div>
  </div>

  <div class="player">
    <div id="nowPlaying">Nenhuma música</div>
    <iframe id="ytPlayer" width="100%" height="120" frameborder="0" allow="autoplay"></iframe>
  </div>

  <script src="app.js"></script>
</body>
</html>
EOF

# ==================== CSS (simplificado) ====================
cat > public/style.css << 'EOF'
* { margin: 0; padding: 0; box-sizing: border-box; }
body { background: #0a0a0a; color: #fff; font-family: 'Segoe UI', sans-serif; }
.container { padding: 20px; max-width: 1200px; margin: auto; }
header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 20px; }
h1 { color: #ff69b4; font-size: 2.5em; }
h2 { color: #ff69b4; margin-top: 20px; margin-bottom: 10px; }

.card { 
  background: rgba(255, 255, 255, 0.06); 
  border: 1px solid #ff69b4; 
  border-radius: 16px; 
  padding: 25px; 
  margin: 20px auto; 
  max-width: 500px; 
}

input, button { 
  padding: 12px; 
  border-radius: 8px; 
  width: 100%; 
  margin: 8px 0; 
  border: 1px solid #ff69b4;
}

input { 
  background: rgba(255, 255, 255, 0.06); 
  color: #fff;
}

button { 
  background: #ff69b4; 
  color: black; 
  border: none; 
  cursor: pointer; 
  font-weight: bold;
  transition: 0.3s;
}

button:hover { background: #ff1493; transform: scale(1.02); }

.user-card { 
  background: #111; 
  padding: 15px; 
  margin: 10px 0; 
  border-radius: 8px; 
  border-left: 4px solid #ff69b4;
}

.user-card button { width: 48%; display: inline-block; margin: 4px 2%; }

.screen { display: none; }
.screen.active { display: block; }
.hidden { display: none; }

.player {
  position: fixed;
  bottom: 0; left: 0; right: 0;
  background: #111;
  border-top: 3px solid #ff69b4;
  padding: 12px;
  z-index: 1000;
}

p { cursor: pointer; color: #ff69b4; text-align: center; margin-top: 10px; }
p:hover { text-decoration: underline; }
EOF

# ==================== APP.JS (Principal) ====================
cat > public/app.js << 'EOF'
let isAdmin = false;
let currentUser = null;

async function login() {
  const username = document.getElementById('loginUser').value;
  const password = document.getElementById('loginPass').value;
  
  const res = await fetch('/login', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ username, password })
  });
  const data = await res.json();
  
  if (data.success) {
    currentUser = username;
    isAdmin = data.isAdmin;
    if (isAdmin) {
      showScreen('adminScreen');
      loadAdminData();
      setInterval(loadAdminData, 2000);
    } else {
      showScreen('dashboardScreen');
    }
  } else {
    alert(data.message || 'Erro no login');
  }
}

async function register() {
  const username = document.getElementById('regUser').value;
  const password = document.getElementById('regPass').value;
  
  const res = await fetch('/register', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ username, password })
  });
  const data = await res.json();
  
  if (data.success) {
    alert('Conta criada! Faça login');
    showScreen('loginScreen');
  } else {
    alert(data.message || 'Erro no registro');
  }
}

async function uploadComprovante() {
  const file = document.getElementById('comprovante').files[0];
  const formData = new FormData();
  formData.append('comprovante', file);
  
  const res = await fetch('/upload-comprovante', {
    method: 'POST',
    body: formData
  });
  const data = await res.json();
  alert(data.success ? 'Comprovante enviado!' : 'Erro');
}

async function searchMusic() {
  const q = document.getElementById('searchInput').value.trim();
  if (!q) return;
  
  const res = await fetch(`/search-music?q=${encodeURIComponent(q)}`);
  const results = await res.json();
  
  let html = '';
  results.forEach(song => {
    html += `
      <div style="background:#111; padding:12px; margin:8px 0; border-radius:8px;">
        <strong>${song.title}</strong><br>
        <img src="${song.thumbnail}" width="100%" style="border-radius:4px; margin:8px 0">
        <button onclick="playSong('${song.url}', '${song.title}')">▶ Play</button>
      </div>
    `;
  });
  document.getElementById('results').innerHTML = html;
}

function playSong(url, title) {
  document.getElementById('nowPlaying').textContent = title;
  const videoId = url.split('v=')[1] || url.split('/').pop();
  document.getElementById('ytPlayer').src = `https://www.youtube.com/embed/${videoId}?autoplay=1`;
  
  fetch('/now-playing', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ title })
  });
}

async function loadAdminData() {
  const res = await fetch('/admin/users');
  const users = await res.json();
  
  let html = '';
  users.forEach(u => {
    html += `
      <div class="user-card">
        <strong>${u.username}</strong> | 📅 ${u.expiration || 'Nunca'} | 💰 ${u.credits}<br>
        IP: ${u.lastIP} | 🎵 ${u.currentSong || 'Parado'}<br>
        <button onclick="killUser('${u.username}')">❌ Kill</button>
        <button onclick="addCredit('${u.username}')">➕ +1</button>
        <button onclick="removeCredit('${u.username}')">➖ -1</button>
      </div>
    `;
  });
  document.getElementById('usersList').innerHTML = html;
}

async function killUser(username) {
  if (!confirm(`Desconectar ${username}?`)) return;
  await fetch('/admin/kill', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ username })
  });
  loadAdminData();
}

async function addCredit(username) {
  await fetch('/admin/credit', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ username, action: 'add' })
  });
  loadAdminData();
}

async function removeCredit(username) {
  await fetch('/admin/credit', {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({ username, action: 'remove' })
  });
  loadAdminData();
}

function showScreen(id) {
  document.querySelectorAll('.screen').forEach(s => s.classList.remove('active'));
  document.getElementById(id).classList.add('active');
}

function logout() {
  fetch('/logout', { method: 'POST' });
  location.reload();
}
EOF

# ==================== BACKEND server.js (v3.0) ====================
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

const upload = multer({ dest: 'comprovantes/' });

app.use(express.json());
app.use(express.static('public'));
app.use(session({ 
  secret: 'cltech-v3-secret-key', 
  resave: false, 
  saveUninitialized: false,
  cookie: { maxAge: 24 * 60 * 60 * 1000 }
}));

const USERS_FILE = path.join(__dirname, 'users/users.json');
let listeningMap = {};

function loadUsers() {
  if (!fs.existsSync(USERS_FILE)) {
    fs.mkdirSync(path.dirname(USERS_FILE), { recursive: true });
    fs.writeFileSync(USERS_FILE, '[]');
  }
  return JSON.parse(fs.readFileSync(USERS_FILE));
}

function saveUsers(users) { 
  fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2)); 
}

function seed() {
  let users = loadUsers();
  if (!users.some(u => u.username === 'clzin')) {
    users.push({ 
      username: 'clzin', 
      password: bcrypt.hashSync('clzin', 10), 
      paid: true, 
      credits: 999, 
      expiration: '2099-12-31', 
      role: 'user',
      lastIP: 'localhost'
    });
  }
  if (!users.some(u => u.username === config.adminUser)) {
    users.push({ 
      username: config.adminUser, 
      password: bcrypt.hashSync(config.adminPass, 10), 
      paid: true, 
      credits: 999, 
      expiration: '2099-12-31', 
      role: 'admin',
      lastIP: 'localhost'
    });
  }
  saveUsers(users);
}

app.post('/register', (req, res) => {
  const { username, password } = req.body;
  let users = loadUsers();
  
  if (users.some(u => u.username === username)) {
    return res.json({ success: false, message: "Usuário já existe" });
  }

  const hash = bcrypt.hashSync(password, 10);
  users.push({
    username,
    password: hash,
    paid: false,
    credits: 0,
    expiration: null,
    lastIP: req.ip,
    currentSong: null,
    role: 'user'
  });
  saveUsers(users);
  res.json({ success: true });
});

app.post('/login', (req, res) => {
  const { username, password } = req.body;
  const users = loadUsers();
  const user = users.find(u => u.username === username);

  if (user && bcrypt.compareSync(password, user.password)) {
    if (!user.paid && user.credits <= 0) {
      return res.json({ success: false, message: "Pagamento pendente" });
    }
    
    req.session.user = { username, role: user.role };
    user.lastIP = req.ip;
    saveUsers(users);
    
    res.json({ success: true, isAdmin: user.role === 'admin' });
  } else {
    res.json({ success: false, message: "Credenciais inválidas" });
  }
});

app.post('/logout', (req, res) => {
  req.session.destroy();
  res.json({ success: true });
});

app.post('/upload-comprovante', upload.single('comprovante'), (req, res) => {
  const users = loadUsers();
  const user = users.find(u => !u.paid && u.credits < 1);
  
  if (user) {
    const months = Math.min(user.credits + 1, 5);
    user.paid = true;
    user.credits += 1;
    user.expiration = new Date(Date.now() + months * 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    saveUsers(users);
    res.json({ success: true });
  } else {
    res.json({ success: false });
  }
});

app.get('/admin/users', (req, res) => {
  if (!req.session.user || req.session.user.role !== 'admin') {
    return res.status(403).json([]);
  }
  const users = loadUsers();
  res.json(users.map(u => ({
    username: u.username,
    credits: u.credits,
    expiration: u.expiration,
    lastIP: u.lastIP,
    currentSong: listeningMap[u.username] || 'Parado'
  })));
});

app.post('/admin/kill', (req, res) => {
  if (!req.session.user || req.session.user.role !== 'admin') {
    return res.status(403).json({ success: false });
  }
  delete listeningMap[req.body.username];
  res.json({ success: true });
});

app.post('/admin/credit', (req, res) => {
  if (!req.session.user || req.session.user.role !== 'admin') {
    return res.status(403).json({ success: false });
  }
  
  const { username, action } = req.body;
  let users = loadUsers();
  const user = users.find(u => u.username === username);
  
  if (user) {
    if (action === 'add') user.credits = Math.min(user.credits + 1, 5);
    if (action === 'remove') user.credits = Math.max(user.credits - 1, 0);
    saveUsers(users);
  }
  res.json({ success: true });
});

app.get('/search-music', async (req, res) => {
  if (!req.session.user) return res.status(401).json([]);
  
  const query = req.query.q;
  try {
    const search = await ytsr(query, { limit: 12 });
    const videos = search.items.filter(i => i.type === 'video').map(i => ({
      title: i.title,
      url: i.url,
      thumbnail: i.bestThumbnail?.url || 'https://via.placeholder.com/320x180'
    }));
    res.json(videos);
  } catch(e) {
    res.json([]);
  }
});

app.post('/now-playing', (req, res) => {
  if (req.session.user) {
    listeningMap[req.session.user.username] = req.body.title;
  }
  res.json({ ok: true });
});

seed();

app.listen(PORT, () => {
  console.log(`🚀 CL TECH OS v3.0 rodando em http://localhost:${PORT}`);
  console.log(`👑 Admin: ${config.adminUser} / ${config.adminPass}`);
  console.log(`💰 Sistema de créditos ativo`);
});
EOF

# ==================== DEPENDÊNCIAS ====================
echo "📦 Instalando dependências npm..."
npm init -y --silent
npm install express express-session bcrypt ytsr multer --silent

pm2 restart cltech || pm2 start server.js --name "cltech"
pm2 save

echo ""
echo "══════════════════════════════════════════════════════════════"
echo "🔥 CL TECH OS v3.0 INSTALADO COM SUCESSO!"
echo "══════════════════════════════════════════════════════════════"
echo "👑 Admin Login → admin / admin2026"
echo "👤 Usuário Demo → clzin / clzin"
echo "💰 Sistema de créditos: 1 real = 1 mês (máx 5 meses)"
echo "📡 Listening em tempo real ativado"
echo "🌐 http://localhost:3000"
echo "══════════════════════════════════════════════════════════════"
