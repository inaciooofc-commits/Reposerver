#!/bin/bash

clear
echo "🔥 CL TECH OS ULTRA REFINED 🔥"

# =========================
# LOADING
# =========================
for i in {1..50}; do
 echo -ne "\r🟢 Inicializando [$i/50]..."
 sleep 0.05
done

# =========================
# BASE
# =========================
apt update -y > /dev/null 2>&1
apt install -y openbox xinit chromium unclutter nodejs npm git wget curl qrencode > /dev/null 2>&1

npm install -g pm2 > /dev/null 2>&1

# =========================
# CLOUDFLARE
# =========================
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb > /dev/null 2>&1

# =========================
# STRUCTURE
# =========================
mkdir -p /opt/cltech/{public,users,data,downloads,logs}
cd /opt/cltech

echo "[]" > users/users.json

# =========================
# SERVER
# =========================
cat << 'EOF' > server.js
const express = require('express')
const fs = require('fs')
const os = require('os')
const { exec } = require('child_process')

const app = express()
app.use(express.json())
app.use(express.static('public'))

// USERS
const USERS_FILE = 'users/users.json'
let users = JSON.parse(fs.readFileSync(USERS_FILE))

// SESSION (simples)
let session = {}

// LOGIN
app.post('/login',(req,res)=>{
 const {user,pass} = req.body
 const found = users.find(u=>u.user===user && u.pass===pass)
 if(found){
   session.logged = true
   return res.send({ok:true})
 }
 res.status(401).send({ok:false})
})

// REGISTER
app.post('/register',(req,res)=>{
 const {user,pass} = req.body
 users.push({user,pass})
 fs.writeFileSync(USERS_FILE, JSON.stringify(users,null,2))
 res.send({ok:true})
})

// AUTH
app.use((req,res,next)=>{
 if(req.path === '/' || req.path === '/login' || req.path === '/register') return next()
 if(!session.logged) return res.redirect('/')
 next()
})

// MONITOR
app.get('/monitor',(req,res)=>{
 res.json({
  cpu:(Math.random()*100).toFixed(2),
  ram:((os.totalmem()-os.freemem())/os.totalmem()*100).toFixed(2),
  uptime: os.uptime()
 })
})

// FILES
app.get('/files',(req,res)=>{
 res.json(fs.readdirSync('data'))
})

app.post('/delete',(req,res)=>{
 fs.unlinkSync('data/'+req.body.name)
 res.send("ok")
})

// TERMINAL
app.post('/cmd',(req,res)=>{
 exec(req.body.cmd,(e,out)=>res.send(out))
})

// ROOT
app.get('/',(req,res)=>res.sendFile(__dirname+'/public/login.html'))
app.get('/app',(req,res)=>res.sendFile(__dirname+'/public/app.html'))

app.listen(3000,()=>console.log("🔥 CL TECH OS RUNNING"))
EOF

npm init -y > /dev/null 2>&1
npm install express > /dev/null 2>&1

# =========================
# LOGIN UI
# =========================
cat << 'EOF' > public/login.html
<!DOCTYPE html>
<html>
<body style="background:black;color:#0f0;font-family:monospace;text-align:center;padding-top:100px">

<h1>CL TECH OS</h1>

<input id="user" placeholder="user"><br><br>
<input id="pass" type="password" placeholder="pass"><br><br>

<button onclick="login()">LOGIN</button>
<button onclick="register()">REGISTER</button>

<script>
async function login(){
 let user=document.getElementById('user').value
 let pass=document.getElementById('pass').value

 let r=await fetch('/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({user,pass})})
 if(r.ok) location='/app'
 else alert("ERRO")
}

async function register(){
 let user=document.getElementById('user').value
 let pass=document.getElementById('pass').value

 await fetch('/register',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({user,pass})})
 alert("CRIADO")
}
</script>

</body>
</html>
EOF

# =========================
# APP UI
# =========================
cat << 'EOF' > public/app.html
<!DOCTYPE html>
<html>
<body style="background:black;color:#0f0;font-family:monospace">

<h2>🟢 CL TECH OS</h2>

<div id="status"></div>

<h3>📁 Arquivos</h3>
<div id="files"></div>

<h3>💻 Terminal</h3>
<input id="cmd">
<button onclick="run()">Run</button>
<pre id="out"></pre>

<script>

async function load(){
 let r=await fetch('/monitor')
 let d=await r.json()
 status.innerHTML="CPU:"+d.cpu+"% RAM:"+d.ram+"%"
}

async function files(){
 let r=await fetch('/files')
 let d=await r.json()
 files.innerHTML=d.join("<br>")
}

async function run(){
 let c=document.getElementById('cmd').value
 let r=await fetch('/cmd',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({cmd:c})})
 out.innerText=await r.text()
}

setInterval(load,2000)
setInterval(files,3000)

</script>

</body>
</html>
EOF

# =========================
# COMANDOS
# =========================
cat << 'EOF' > /usr/bin/clonline
#!/bin/bash

cd /opt/cltech

pkill node
pkill cloudflared

node server.js &
sleep 3

cloudflared tunnel --url http://localhost:3000 > cf.log 2>&1 &
sleep 5

LINK=$(grep -o 'https://[-a-zA-Z0-9]*\.trycloudflare\.com' cf.log)

clear
echo "🚀 ONLINE:"
echo "$LINK"

qrencode -t ANSIUTF8 "$LINK"

chromium --kiosk $LINK
EOF

chmod +x /usr/bin/clonline

# =========================
# AUTO BOOT
# =========================
cat << 'EOF' > ~/.xinitrc
#!/bin/bash
unclutter &
clonline
EOF

chmod +x ~/.xinitrc

cat << 'EOF' >> ~/.bashrc

if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
 startx
fi
EOF

# =========================
# FINAL
# =========================
clear
echo "🔥 INSTALAÇÃO FINALIZADA"
echo ""
echo "▶ reinicie:"
echo "reboot"
