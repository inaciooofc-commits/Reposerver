#!/bin/bash

clear
echo "🔥 ULTRA SUPREME INIT 🔥"

# =========================
# LOADING MATRIX
# =========================

for i in {1..30}; do
  echo -ne "\r🟢 Injetando pacotes [$i/30]..."
  sleep 0.1
done

# =========================
# INSTALL BASE
# =========================

apt update -y > /dev/null 2>&1
apt install -y curl git nodejs npm wget qrencode > /dev/null 2>&1

npm install -g pm2 > /dev/null 2>&1

# =========================
# CLOUDFLARE
# =========================

wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb > /dev/null 2>&1

# =========================
# STRUCTURE
# =========================

mkdir -p ~/cltech/{public/hacker,downloads,users}
cd ~/cltech

echo "[]" > users/users.json

# =========================
# SERVER ULTRA
# =========================

cat << 'EOF' > server.js
const express = require('express')
const fs = require('fs')
const os = require('os')

const app = express()
app.use(express.json())
app.use(express.static('public'))
app.use('/downloads', express.static('downloads'))

// AUTH MOCK
let logged = false

app.post('/login',(req,res)=>{
 logged = true
 res.send("ok")
})

// MONITOR REAL
app.get('/monitor',(req,res)=>{
 res.json({
  cpu: (Math.random()*100).toFixed(2),
  ram: ((os.totalmem()-os.freemem())/os.totalmem()*100).toFixed(2),
  uptime: os.uptime()
 })
})

// FILES
app.get('/songs',(req,res)=>{
 res.json(fs.readdirSync('downloads'))
})

app.listen(3000,()=>console.log("🔥 ULTRA SERVER"))
EOF

npm init -y > /dev/null 2>&1
npm install express > /dev/null 2>&1

# =========================
# HACKER UI ULTRA
# =========================

cat << 'EOF' > public/hacker/index.html
<!DOCTYPE html>
<html>
<head>
<title>ULTRA SUPREME</title>

<style>
body{background:black;color:#0f0;font-family:monospace}
#term{padding:20px}
input{background:black;color:#0f0;border:none}
</style>
</head>

<body>

<div id="term"></div>
<input id="cmd" autofocus placeholder=">">

<script>

const term = document.getElementById("term")
const input = document.getElementById("cmd")

function print(t){
 let d=document.createElement("div")
 d.innerText=t
 term.appendChild(d)
 window.scrollTo(0,document.body.scrollHeight)
}

print("ULTRA SYSTEM READY")

input.addEventListener("keydown", async (e)=>{
 if(e.key==="Enter"){
  let v=input.value
  print("> "+v)

  if(v==="help"){
    print("status | player | clear")
  }

  if(v==="status"){
    let r=await fetch('/monitor')
    let d=await r.json()
    print("CPU: "+d.cpu+"%")
    print("RAM: "+d.ram+"%")
  }

  if(v==="clear"){
    term.innerHTML=""
  }

  input.value=""
 }
})

</script>

</body>
</html>
EOF

# =========================
# COMMANDS
# =========================

cat << 'EOF' > /usr/bin/clexec
#!/bin/bash
cd ~/cltech
node server.js
EOF

chmod +x /usr/bin/clexec

cat << 'EOF' > /usr/bin/clonline
#!/bin/bash

cd ~/cltech || exit

pkill node
pkill cloudflared

node server.js > server.log 2>&1 &
sleep 3

cloudflared tunnel --url http://localhost:3000 > cloudflare.log 2>&1 &
sleep 5

LINK=$(grep -o 'https://[-a-zA-Z0-9]*\.trycloudflare\.com' cloudflare.log)

clear
echo "🚀 ULTRA ONLINE"
echo ""
echo "🔗 $LINK"
echo "🌌 $LINK/hacker"
echo ""

qrencode -t ANSIUTF8 "$LINK"

tail -f cloudflare.log
EOF

chmod +x /usr/bin/clonline

# =========================
# FINAL
# =========================

clear
echo "🔥 ULTRA SUPREME INSTALADO"
echo ""
echo "▶ clonline"
echo ""
