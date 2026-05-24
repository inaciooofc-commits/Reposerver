#!/bin/bash

echo "🔥 CL TECH SERVER - ALL IN ONE"

# Atualização
apt update -y
apt install -y curl git nodejs npm

# PM2
npm install -g pm2

# Code Server
curl -fsSL https://code-server.dev/install.sh | sh

mkdir -p ~/.config/code-server

cat <<EOF > ~/.config/code-server/config.yaml
bind-addr: 0.0.0.0:8080
auth: password
password: 123456
cert: false
EOF

# Criar painel
mkdir -p ~/cltech
cd ~/cltech

cat <<'EOF' > server.js
const express = require('express')
const { exec } = require('child_process')
const app = express()

app.use(express.static(__dirname))

app.get('/start', (req,res)=>{
 exec('pm2 start app.js', ()=> res.send('started'))
})

app.get('/stop', (req,res)=>{
 exec('pm2 stop app.js', ()=> res.send('stopped'))
})

app.get('/restart', (req,res)=>{
 exec('pm2 restart app.js', ()=> res.send('restarted'))
})

app.get('/git', (req,res)=>{
 exec('git pull', ()=> res.send('git updated'))
})

app.get('/files', (req,res)=>{
 exec('ls', (e, out)=> res.send(out))
})

app.listen(3000, ()=> console.log('Painel rodando'))
EOF

cat <<'EOF' > index.html
<!DOCTYPE html>
<html>
<head>
<title>CL TECH</title>
<style>
body{background:#0f172a;color:white;font-family:Arial;text-align:center}
button{padding:15px;margin:10px;border-radius:10px;border:none;background:#22c55e}
</style>
</head>
<body>

<h1>⚡ CL TECH SERVER</h1>

<button onclick="req('start')">▶️ Start</button>
<button onclick="req('stop')">⏹️ Stop</button>
<button onclick="req('restart')">🔄 Restart</button>
<button onclick="req('git')">🔗 Git Pull</button>
<button onclick="editor()">💻 Editor</button>

<script>
function req(r){fetch('/'+r).then(r=>r.text()).then(alert)}
function editor(){location='http://'+location.hostname+':8080'}
</script>

</body>
</html>
EOF

# Dependência
npm init -y
npm install express

# Rodar painel
pm2 start server.js
pm2 save

echo ""
echo "=============================="
echo "✅ PRONTO"
echo "Painel: http://SEU_IP:3000"
echo "Editor: http://SEU_IP:8080"
echo "Senha: 123456"
echo "=============================="
