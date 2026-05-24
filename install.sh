#!/bin/bash

set -e

echo "🔥 CL TECH OS INSTALLER"

# =========================
# ROOT CHECK
# =========================
if [ "$EUID" -ne 0 ]; then
  echo "Execute como root: sudo bash install.sh"
  exit 1
fi

# =========================
# UPDATE SYSTEM
# =========================
apt update -y && apt upgrade -y

# =========================
# DEPENDENCIES
# =========================
apt install -y curl wget git jq build-essential python3

curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs

npm install -g pm2

# =========================
# CLOUDFLARED
# =========================
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb -O cf.deb
dpkg -i cf.deb || apt -f install -y
rm cf.deb

# =========================
# STRUCTURE
# =========================
BASE=/opt/cltech
mkdir -p $BASE/{music,logs,users,system,public}
cd $BASE

echo "[]" > users/users.json

# =========================
# PACKAGE JSON
# =========================
cat > package.json <<EOF
{
  "name": "cltech",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "ws": "^8.17.0",
    "bcrypt": "^5.1.1",
    "ytsr": "^3.8.4",
    "cors": "^2.8.5"
  }
}
EOF

npm install

# =========================
# SERVER (BACKEND)
# =========================
cat > server.js <<'EOF'
const express = require("express");
const fs = require("fs");
const os = require("os");
const bcrypt = require("bcrypt");
const cors = require("cors");
const ytsr = require("ytsr");
const { WebSocketServer } = require("ws");

const app = express();
app.use(cors());
app.use(express.json());
app.use(express.static("public"));

const USERS_FILE = "./users/users.json";

function loadUsers() {
  try { return JSON.parse(fs.readFileSync(USERS_FILE)); }
  catch { return []; }
}
function saveUsers(u) {
  fs.writeFileSync(USERS_FILE, JSON.stringify(u, null, 2));
}

// =========================
// MONITOR ÚNICO
// =========================
function getSystemStatus() {
  const cpus = os.loadavg()[0];
  const mem = {
    total: os.totalmem(),
    free: os.freemem()
  };

  return {
    cpu: cpus,
    ram: ((mem.free / mem.total) * 100).toFixed(2),
    uptime: os.uptime(),
    platform: os.platform()
  };
}

// =========================
// DEFAULT USER
// =========================
(async () => {
  let users = loadUsers();
  if (!users.find(u => u.user === "clzin")) {
    users.push({
      user: "clzin",
      pass: await bcrypt.hash("clzin", 10)
    });
    saveUsers(users);
  }
})();

// =========================
// AUTH
// =========================
app.post("/login", async (req,res)=>{
  const {user,pass}=req.body;
  let users=loadUsers();
  let u=users.find(x=>x.user===user);
  if(!u) return res.status(401).send({ok:false});
  if(!await bcrypt.compare(pass,u.pass)) return res.status(401).send({ok:false});
  res.send({ok:true});
});

app.post("/register", async (req,res)=>{
  let users=loadUsers();
  users.push({user:req.body.user, pass:await bcrypt.hash(req.body.pass,10)});
  saveUsers(users);
  res.send({ok:true});
});

// =========================
// MUSIC SEARCH
// =========================
app.get("/search-music", async (req,res)=>{
  const r = await ytsr(req.query.q || "", {limit:5});
  res.json(r.items.filter(i=>i.type==="video"));
});

// =========================
// LOCAL MUSIC
// =========================
app.get("/music/local",(req,res)=>{
  const files = fs.readdirSync("./music");
  res.json(files);
});

// =========================
// STATUS (MESMO DO clmonit)
// =========================
app.get("/status",(req,res)=>{
  res.json(getSystemStatus());
});

// =========================
// WS CHAT
// =========================
const server = app.listen(3000);
const wss = new WebSocketServer({ server });

let clients = [];

wss.on("connection",(ws)=>{
  clients.push(ws);

  ws.on("message",(msg)=>{
    clients.forEach(c=>{
      if(c.readyState===1) c.send(msg.toString());
    });
  });
});

console.log("CL TECH OS ONLINE");
EOF

# =========================
# FRONTEND
# =========================
cat > public/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<link rel="manifest" href="/manifest.json">
<style>
body{background:#000;color:#ff69b4;font-family:monospace}
#app{display:flex}
#chat{width:40%;border-right:1px solid #333}
#music{width:60%;padding:10px}
</style>
</head>
<body>

<div id="login">
<input id="u" placeholder="user">
<input id="p" type="password">
<button onclick="login()">LOGIN</button>
</div>

<div id="app" style="display:none">
<div id="chat">
<h3>CHAT</h3>
<div id="msgs"></div>
<input id="msg"><button onclick="send()">Send</button>
</div>

<div id="music">
<h3>MUSIC</h3>
<input id="q"><button onclick="search()">Buscar</button>
<div id="list"></div>
<iframe id="player" width="300" height="200"></iframe>

<h3>STATUS</h3>
<pre id="status"></pre>
</div>
</div>

<script>
let ws;

async function login(){
let r=await fetch("/login",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({user:u.value,pass:p.value})});
let d=await r.json();
if(d.ok){
document.getElementById("login").style.display="none";
document.getElementById("app").style.display="flex";
startWS();
loadStatus();
}
}

function startWS(){
ws=new WebSocket("ws://"+location.host);
ws.onmessage=e=>{
let div=document.getElementById("msgs");
div.innerHTML+="<p>"+e.data+"</p>";
}
}

function send(){
ws.send(msg.value);
}

async function search(){
let r=await fetch("/search-music?q="+q.value);
let d=await r.json();
list.innerHTML="";
d.forEach(v=>{
let div=document.createElement("div");
div.innerHTML=v.title;
div.onclick=()=>{
player.src="https://www.youtube.com/embed/"+v.id.videoId;
};
list.appendChild(div);
});
}

async function loadStatus(){
let r=await fetch("/status");
status.innerText=JSON.stringify(await r.json(),null,2);
setTimeout(loadStatus,3000);
}
</script>

</body>
</html>
EOF

# =========================
# PWA
# =========================
cat > public/manifest.json <<EOF
{
"name":"CL TECH OS",
"short_name":"CLTECH",
"start_url":"/",
"display":"standalone",
"background_color":"#000",
"theme_color":"#ff69b4"
}
EOF

cat > public/service-worker.js <<EOF
self.addEventListener("fetch",e=>{});
EOF

# =========================
# CLOUDFLARE
# =========================
cat > cloudflare.sh <<EOF
#!/bin/bash
while true; do
cloudflared tunnel --url http://localhost:3000
sleep 3
done
EOF

chmod +x cloudflare.sh

# =========================
# CLMONIT
# =========================
cat > /usr/local/bin/clmonit <<'EOF'
#!/bin/bash
echo "🔥 CL TECH MONITOR"
curl -s http://localhost:3000/status | jq
pm2 status
EOF

chmod +x /usr/local/bin/clmonit

# =========================
# PM2
# =========================
pm2 start server.js --name cltech
pm2 save

# =========================
# SYSTEMD
# =========================
cat > /etc/systemd/system/cltech.service <<EOF
[Unit]
Description=CL TECH OS
After=network.target

[Service]
WorkingDirectory=/opt/cltech
ExecStart=/usr/bin/pm2 resurrect
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cltech
systemctl start cltech

# =========================
# FINAL
# =========================
echo "🔥 CL TECH OS INSTALADO"
echo "http://localhost:3000"
echo "clmonit disponível"
echo "Cloudflare: execute bash cloudflare.sh"