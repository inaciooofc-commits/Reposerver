#!/bin/bash

clear
echo -e "\e[95m🔥 CL TECH OS — CONTROLE TOTAL 🔥\e[0m"

# =========================
# MENSAGENS SAFADAS (GRANDES E ROSA)
# =========================
msgs=(
"Mia está molhadinha e querendo..."
"Mai tem peitos grandes né? 🍒"
"Malena está mastigando a calcinha..."
"Vitória tá rebolando gostoso no seu colo..."
"Clara tá sem calcinha te esperando..."
"Sophia gemeu seu nome agora..."
"Juliana tá se tocando pensando em você..."
"Beatriz tá toda suada e nua na cama..."
"Luana tá abrindo as pernas devagar..."
"Isabela tá pingando de tesão..."
"Manuela quer sentar gostoso em você..."
"Larissa tá chupando o dedo imaginando..."
"Camila tá rebolando a bunda na sua frente..."
"Gabriela tá de quatro te chamando..."
"Ana Clara tá toda melada e safada..."
"Maria Eduarda tá gemendo alto..."
"Letícia tá se masturbando no banheiro..."
"Raquel tá com a bucetinha inchada de tesão..."
"Sofia tá pedindo pra você meter forte..."
"Marina tá toda molhada e safada..."
)

random_msg() {
  echo -e "\e[95m${msgs[$RANDOM % ${#msgs[@]}]}\e[0m"
}

# Animação de arquivos sendo transferidos
transfer_animation() {
  local frames=("⬇️📁 [===>     ]" "⬇️📂 [====>    ]" "⬇️📁 [=====>   ]" 
                "⬇️📂 [=======> ]" "⬇️📁 [========>]")
  for i in {1..25}; do
    random_msg
    echo -e "\e[96m${frames[$((i % 5))]}\e[0m"
    sleep 0.18
  done
}

# =========================
# VERIFICAÇÕES INICIAIS
# =========================
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[91m❌ Execute como root: sudo bash install.sh\e[0m"
  exit 1
fi

# =========================
# VARIÁVEIS
# =========================
BASE_DIR="/opt/cltech"
mkdir -p $BASE_DIR/{logs,data,users,public}

cd $BASE_DIR

# =========================
# INSTALAÇÃO
# =========================
echo -e "\e[95m🔄 Atualizando sistema...\e[0m"
transfer_animation
apt update -y && apt upgrade -y

echo -e "\e[95m📦 Instalando dependências...\e[0m"
transfer_animation
apt install -y curl git nodejs npm wget qrencode build-essential python3

npm install -g pm2

# Cloudflared
echo -e "\e[95m🌐 Instalando Cloudflared...\e[0m"
transfer_animation
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -O /tmp/cloudflared.deb
dpkg -i /tmp/cloudflared.deb || apt install -f -y
rm -f /tmp/cloudflared.deb

# =========================
# BACKEND
# =========================
echo -e "\e[95m🧠 Criando backend...\e[0m"
transfer_animation

cat << 'EOF' > server.js
const express = require('express');
const fs = require('fs');
const bcrypt = require('bcrypt');
const os = require('os');

const app = express();
app.use(express.json());
app.use(express.static('public'));

const USERS_FILE = './users/users.json';

function loadUsers() {
  try { return JSON.parse(fs.readFileSync(USERS_FILE, 'utf8')); } 
  catch { return []; }
}
function saveUsers(users) { 
  fs.writeFileSync(USERS_FILE, JSON.stringify(users, null, 2)); 
}

app.post('/register', async (req, res) => {
  const { user, pass } = req.body;
  let users = loadUsers();
  const hash = await bcrypt.hash(pass, 10);
  users.push({ user, pass: hash });
  saveUsers(users);
  res.json({ ok: true });
});

app.post('/login', async (req, res) => {
  const { user, pass } = req.body;
  let users = loadUsers();
  const found = users.find(u => u.user === user);
  if (!found || !(await bcrypt.compare(pass, found.pass))) {
    return res.status(401).json({ ok: false });
  }
  res.json({ ok: true });
});

app.listen(3000, () => console.log("🔥 CL TECH SERVER ONLINE"));
EOF

echo "[]" > users/users.json
npm init -y > /dev/null 2>&1
npm install express bcrypt

# =========================
# FRONTEND REFINADO
# =========================
echo -e "\e[95m🎨 Criando Gerenciador de Rede...\e[0m"
transfer_animation

cat << 'EOF' > public/index.html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body { 
      background: #000; 
      color: #ff69b4; 
      font-family: monospace; 
      text-align: center; 
      padding: 30px; 
    }
    h1 { font-size: 2.8em; text-shadow: 0 0 10px #ff69b4; }
    input, button { 
      margin: 12px; 
      padding: 15px; 
      background: #111; 
      color: #ff69b4; 
      border: 2px solid #ff69b4; 
      font-size: 1.1em;
      width: 320px;
    }
    button { cursor: pointer; font-weight: bold; }
    button:hover { background: #ff69b4; color: black; }
    #status { margin-top: 20px; font-size: 1.3em; min-height: 80px; }
  </style>
</head>
<body>
  <h1>🔥 CL TECH OS</h1>
  <h2>GERENCIADOR DE REDE</h2>
  
  <input id="user" placeholder="Usuário"><br>
  <input id="pass" type="password" placeholder="Senha"><br>
  <button onclick="login()">ENTRAR NO SISTEMA</button>
  
  <br><br>
  <button onclick="startTunnel()">🚀 ABRIR CLOUDFLARE TUNNEL</button>
  
  <pre id="status"></pre>

  <script>
  async function login(){
    const r = await fetch('/login', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({user: user.value, pass: pass.value})
    });
    const data = await r.json();
    document.getElementById('status').innerHTML = data.ok ? 
      "✅ <span style='color:#0f0'>ACESSO LIBERADO</span>" : 
      "❌ <span style='color:#f00'>LOGIN FALHOU</span>";
  }

  function startTunnel(){
    document.getElementById('status').innerHTML = "🌐 Iniciando túnel... Aguarde...";
    fetch('/start-tunnel', {method:'POST'});
    setTimeout(() => {
      window.open('https://your-tunnel.trycloudflare.com', '_blank');
    }, 1500);
  }
  </script>
</body>
</html>
EOF

# =========================
# PM2 + SERVICES
# =========================
pm2 start server.js --name cltech
pm2 save

cat << 'EOF' > cloudflare.sh
#!/bin/bash
cd /opt/cltech
while true; do
  echo "[$(date)] Iniciando Cloudflare Tunnel..." >> logs/cf.log
  cloudflared tunnel --url http://localhost:3000 --no-tls-verify >> logs/cf.log 2>&1
  sleep 8
done
EOF

chmod +x cloudflare.sh

# Systemd
cat << EOF > /etc/systemd/system/cltech.service
[Unit]
Description=CL TECH OS - Server + Tunnel
After=network.target

[Service]
User=root
WorkingDirectory=$BASE_DIR
ExecStart=/usr/bin/pm2 resurrect
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cltech
systemctl start cltech

# =========================
# FINAL
# =========================
clear
echo -e "\e[95m✅ INSTALAÇÃO CONCLUÍDA COM SUCESSO!\e[0m"
echo ""
echo -e "\e[96m🌐 Acesse o Gerenciador: http://localhost:3000\e[0m"
echo -e "\e[96m🚀 Iniciar túnel: bash /opt/cltech/cloudflare.sh\e[0m"
echo ""
echo -e "\e[95m💖 Aproveite o sistema...\e[0m"
