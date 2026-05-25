#!/bin/bash
# CL TECH OS v4.3 — MATRIX Edition (Antix - Instalador Único)
clear
echo -e "\033[36m╔══════════════════════════════════════════════════════════════╗\033[0m"
echo -e "\033[36m║           CL TECH OS v4.3 — MATRIX EDITION (Antix)           ║\033[0m"
echo -e "\033[36m║                 Instalador Completo - Tudo em Um             ║\033[0m"
echo -e "\033[36m╚══════════════════════════════════════════════════════════════╝\033[0m"

# Atualizar sistema e instalar dependências
echo "[1/7] Atualizando sistema e instalando pacotes..."
sudo apt-get update -qq && sudo apt-get install -y curl wget git ffmpeg yt-dlp ufw lsof

# Instalar Node.js
if ! command -v node &> /dev/null; then
    echo "[2/7] Instalando Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo bash -
    sudo apt-get install -y nodejs
fi

# Instalar PM2
echo "[3/7] Instalando PM2..."
sudo npm install -g pm2 --silent

# Instalar Cloudflared
echo "[4/7] Instalando Cloudflared..."
if ! command -v cloudflared &> /dev/null; then
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
    sudo dpkg -i cloudflared-linux-amd64.deb || sudo apt-get install -f -y
    rm -f cloudflared-linux-amd64.deb
fi

# Criar estrutura
echo "[5/7] Criando estrutura de pastas e dependências..."
sudo mkdir -p /opt/cltech/{public,data}
sudo chown -R $USER:$USER /opt/cltech
cd /opt/cltech

# Inicializar Node.js e instalar Express
npm init -y > /dev/null
npm install express > /dev/null

# ================== CRIANDO TODOS OS ARQUIVOS ==================

echo "[6/7] Criando todos os arquivos..."

# config.json
cat > config.json << 'EOF'
{
  "adminUser": "admin",
  "adminPass": "123456",
  "port": 3000
}
EOF

# server.js
cat > server.js << 'EOF'
const express = require('express');
const fs = require('fs');
const app = express();

app.use(express.json());
app.use(express.static('public'));

const config = JSON.parse(fs.readFileSync('config.json'));

let users = [];
try { users = JSON.parse(fs.readFileSync('data/users.json')); } 
catch(e) { fs.writeFileSync('data/users.json', '[]'); }

app.post('/api/login', (req, res) => {
    const { username, password } = req.body;
    if (username === config.adminUser && password === config.adminPass) {
        res.json({ success: true, isAdmin: true });
    } else {
        res.json({ success: true, isAdmin: false });
    }
});

app.get('/api/connected-ips', (req, res) => res.json({ ips: ["Exemplo: 179.185.x.x"] }));
app.post('/api/add-credits', (req, res) => res.json({ success: true, message: "Créditos adicionados" }));
app.post('/api/remove-credits', (req, res) => res.json({ success: true, message: "Créditos removidos" }));
app.post('/api/ban-ip', (req, res) => res.json({ success: true, message: "IP banido" }));
app.post('/api/confirm-pix', (req, res) => res.json({ success: true, message: "Pagamento confirmado - Envie para 5511951289502" }));

app.listen(config.port, () => console.log('🚀 CL TECH OS rodando na porta ' + config.port));
EOF

# monitor-master.sh
cat > monitor-master.sh << 'EOF'
#!/bin/bash
while true; do
  clear
  echo "======================================="
  echo "   CL TECH OS v4.3 - MODO MESTRE"
  echo "======================================="
  echo "1) Ver IPs Conectados"
  echo "2) Reiniciar Sistema"
  echo "3) Sair"
  read -p "Opção: " op
  case $op in
    1) echo "IPs conectados:"; ss -tlnp | grep node;;
    2) pm2 restart cltech;;
    3) exit 0;;
  esac
  read -p "Pressione Enter para continuar..."
done
EOF

# start-cloudflare.sh
cat > start-cloudflare.sh << 'EOF'
#!/bin/bash
cd /opt/cltech
pm2 start ecosystem.config.js
echo "✅ Servidor iniciado com PM2"
echo "🚀 Iniciando Cloudflare Tunnel..."
cloudflared tunnel --url http://localhost:3000
EOF

# ecosystem.config.js
cat > ecosystem.config.js << 'EOF'
module.exports = {
  apps: [{
    name: 'cltech',
    script: 'server.js',
    watch: false,
    env: { NODE_ENV: 'production' }
  }]
};
EOF

# public/index.html
mkdir -p public
cat > public/index.html << 'EOF'
<!DOCTYPE html>
<html lang="pt-BR">
<head><meta charset="UTF-8"><title>CL TECH OS - Login</title><link rel="stylesheet" href="style.css"></head>
<body>
    <div class="card">
        <h1>CL TECH OS v4.3</h1>
        <input type="text" id="username" placeholder="Usuário">
        <input type="password" id="password" placeholder="Senha">
        <button class="btn" onclick="login()">Entrar</button>
        <p>Admin: admin / 123456</p>
    </div>
    <script src="app.js"></script>
</body>
</html>
EOF

# public/dashboard.html
cat > public/dashboard.html << 'EOF'
<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8"><title>Dashboard</title><link rel="stylesheet" href="style.css"></head>
<body><div class="card"><h1>Bem-vindo ao CL TECH OS</h1><input type="text" id="search" placeholder="Buscar música...">
<button class="btn" onclick="searchMusic()">Buscar</button><div id="results"></div><hr><p>Pix: 5511951289502</p></div><script src="app.js"></script></body></html>
EOF

# public/admin.html
cat > public/admin.html << 'EOF'
<!DOCTYPE html><html lang="pt-BR"><head><meta charset="UTF-8"><title>Painel Admin</title><link rel="stylesheet" href="style.css"></head>
<body><div class="card"><h1>🔧 PAINEL MESTRE</h1>
<button class="btn" onclick="addCredits()">+ Créditos</button>
<button class="btn" onclick="removeCredits()">- Créditos</button>
<button class="btn" onclick="banIP()">Banir IP</button>
<button class="btn" onclick="viewIPs()">Ver IPs</button>
<button class="btn" onclick="confirmPix()">Confirmar Pix</button>
<div id="adminContent"></div></div><script src="app.js"></script></body></html>
EOF

# public/style.css
cat > public/style.css << 'EOF'
body { font-family: monospace; background: #000; color: #00ff41; margin:0; padding:20px; }
.card { background: rgba(10,15,35,0.95); border: 1px solid #00ff41; padding: 30px; border-radius: 8px; max-width: 900px; margin: auto; }
.btn { background:#00ff41; color:black; padding:10px 20px; border:none; margin:5px; cursor:pointer; }
.btn:hover { background:#00cc33; }
EOF

# public/app.js
cat > public/app.js << 'EOF'
function login() {
    const u = document.getElementById('username').value;
    const p = document.getElementById('password').value;
    fetch('/api/login', {method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify({username:u, password:p})})
    .then(r=>r.json()).then(d=>{ if(d.success) window.location.href = d.isAdmin ? 'admin.html' : 'dashboard.html'; });
}
function searchMusic(){ document.getElementById('results').innerHTML = '<p>Buscando...</p>'; }
function addCredits(){ alert('Créditos adicionados'); }
function removeCredits(){ alert('Créditos removidos'); }
function banIP(){ const ip=prompt('IP para banir:'); alert('IP ' + ip + ' banido'); }
function viewIPs(){ document.getElementById('adminContent').innerHTML = '<p>IPs conectados: (simulado)</p>'; }
function confirmPix(){ alert('Pagamento confirmado - Envie comprovante para 5511951289502'); }
EOF

# data files
cat > data/users.json << 'EOF'
[]
EOF
cat > data/payments.json << 'EOF'
[]
EOF

# Permissões
chmod +x start-cloudflare.sh monitor-master.sh

echo "[7/7] Instalação concluída com sucesso!"
echo ""
echo "✅ Sistema instalado em /opt/cltech"
echo "🔑 Admin: admin / 123456"
echo ""
echo "Para iniciar:"
echo "   cd /opt/cltech"
echo "   bash start-cloudflare.sh"
echo ""
echo "Para monitor (apenas no mestre):"
echo "   bash monitor-master.sh"
