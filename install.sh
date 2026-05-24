#!/bin/bash

clear
echo "🔥 CL TECH OS — CONTROLE TOTAL 🔥"

# =========================
# MENSAGENS DINÂMICAS
# =========================
msgs=(
"Vitória foi detectada no sistema..."
"Malena acessou área restrita..."
"Mia está sendo monitorada..."
"Usuário desconhecido tentando acesso..."
"Interceptando dados externos..."
"Pacotes suspeitos analisados..."
"Firewall reagindo..."
"Conexão instável detectada..."
"Processo oculto identificado..."
"Executando protocolo secreto..."
"Atividade incomum registrada..."
"Alerta: acesso não autorizado..."
"Carregando módulos ocultos..."
"Sincronizando com servidor externo..."
"Reconfigurando núcleo do sistema..."
"Inicializando modo stealth..."
"Descriptografando dados..."
"Aplicando camadas de segurança..."
)

random_msg() {
  echo "⚡ ${msgs[$RANDOM % ${#msgs[@]}]}"
}

loading() {
  for i in {1..20}; do
    random_msg
    sleep 0.08
  done
}

# =========================
# VARIÁVEIS
# =========================
BASE_DIR="/opt/cltech"
LOG_DIR="$BASE_DIR/logs"
DATA_DIR="$BASE_DIR/data"
USER_DIR="$BASE_DIR/users"

# =========================
# UPDATE
# =========================
echo "🔄 Atualizando sistema..."
loading
apt update -y

# =========================
# DEPENDÊNCIAS
# =========================
echo "📦 Instalando dependências..."
loading
apt install -y curl git nodejs npm wget qrencode

npm install -g pm2

# =========================
# CLOUDFLARE
# =========================
echo "🌐 Instalando Cloudflare..."
loading
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb

# =========================
# ESTRUTURA
# =========================
echo "📁 Criando estrutura..."
loading
mkdir -p $BASE_DIR/{logs,data,users,public}
cd $BASE_DIR

echo "[]" > $USER_DIR/users.json

# =========================
# BACKEND
# =========================
echo "🧠 Criando backend..."
loading
cat << 'EOF' > server.js
const express = require('express')
const fs = require('fs')
const bcrypt = require('bcrypt')
const os = require('os')
const { exec } = require('child_process')

const app = express()
app.use(express.json())
app.use(express.static('public'))

const USERS_FILE = './users/users.json'

function loadUsers(){
 return JSON.parse(fs.readFileSync(USERS_FILE))
}

function saveUsers(users){
 fs.writeFileSync(USERS_FILE, JSON.stringify(users,null,2))
}

app.post('/register', async (req,res)=>{
 const {user,pass} = req.body
 let users = loadUsers()
 const hash = await bcrypt.hash(pass,10)
 users.push({user,pass:hash})
 saveUsers(users)
 res.send({ok:true})
})

app.post('/login', async (req,res)=>{
 const {user,pass} = req.body
 let users = loadUsers()
 const found = users.find(u=>u.user===user)
 if(!found) return res.status(401).send()
 const ok = await bcrypt.compare(pass, found.pass)
 if(ok) return res.send({ok:true})
 res.status(401).send()
})

app.get('/monitor',(req,res)=>{
 res.json({
  cpu:(Math.random()*100).toFixed(2),
  ram:((os.totalmem()-os.freemem())/os.totalmem()*100).toFixed(2),
  uptime: os.uptime()
 })
})

app.get('/pm2',(req,res)=>{
 exec('pm2 list',(e,out)=>res.send(out))
})

app.post('/cmd',(req,res)=>{
 exec(req.body.cmd,(e,out)=>res.send(out))
})

app.listen(3000,()=>console.log("🔥 SERVER ONLINE"))
EOF

npm init -y > /dev/null 2>&1
npm install express bcrypt

# =========================
# FRONTEND
# =========================
echo "🎨 Criando interface..."
loading
cat << 'EOF' > public/index.html
<!DOCTYPE html>
<html>
<body style="background:#000;color:#0f0;font-family:monospace">

<h2>CL TECH CONTROL</h2>

<input id="user" placeholder="user">
<input id="pass" type="password" placeholder="pass">
<button onclick="login()">Login</button>

<pre id="out"></pre>

<script>
async function login(){
 let r=await fetch('/login',{
  method:'POST',
  headers:{'Content-Type':'application/json'},
  body:JSON.stringify({
    user:user.value,
    pass:pass.value
  })
 })
 if(r.ok){
   alert("OK")
 }else{
   alert("FAIL")
 }
}
</script>

</body>
</html>
EOF

# =========================
# PM2 START
# =========================
echo "⚡ Iniciando serviços..."
loading
pm2 start server.js --name cltech
pm2 save

# =========================
# CLOUDFLARE SCRIPT
# =========================
echo "🌐 Configurando Cloudflare loop..."
loading
cat << 'EOF' > $BASE_DIR/cloudflare.sh
#!/bin/bash
while true; do
  cloudflared tunnel --url http://localhost:3000 >> logs/cf.log 2>&1
  sleep 5
done
EOF

chmod +x $BASE_DIR/cloudflare.sh

# =========================
# SYSTEMD SERVICE
# =========================
echo "⚙️ Configurando auto start..."
loading
cat << EOF > /etc/systemd/system/cltech.service
[Unit]
Description=CL TECH SERVER
After=network.target

[Service]
ExecStart=/usr/bin/pm2 resurrect
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cltech

# =========================
# FINAL
# =========================
clear
echo "🔥 INSTALAÇÃO FINALIZADA COM SUCESSO"
echo ""
echo "🚀 Sistema pronto!"
echo ""
echo "▶ iniciar manual:"
echo "pm2 start server.js"
echo ""
echo "▶ logs:"
echo "pm2 logs"
echo ""
echo "▶ cloudflare:"
echo "bash $BASE_DIR/cloudflare.sh"
echo ""
