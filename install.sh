#!/bin/bash

echo "🔥 CL TECH PLAYER PRO"

apt update -y
apt install -y curl git nodejs npm wget

npm install -g pm2

# ========================
# COMANDO clexec
# ========================
cat <<'EOF' > /usr/bin/clexec
#!/bin/bash
cd ~/cltech || exit
node server.js
EOF

chmod +x /usr/bin/clexec

# ========================
# CLOUDFLARE
# ========================
wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
dpkg -i cloudflared-linux-amd64.deb

# ========================
# ESTRUTURA
# ========================
mkdir -p ~/cltech/{data,users,downloads}
cd ~/cltech

echo "[]" > users/users.json

# ========================
# SERVER
# ========================
cat <<'EOF' > server.js
const express = require('express')
const fs = require('fs')
const bcrypt = require('bcrypt')
const session = require('express-session')
const axios = require('axios')

const app = express()

app.use(express.json())
app.use(express.static('public'))
app.use('/downloads', express.static('downloads'))

app.use(session({
 secret:'cltech',
 resave:false,
 saveUninitialized:true
}))

const usersFile = 'users/users.json'

function load(){ return JSON.parse(fs.readFileSync(usersFile)) }
function save(d){ fs.writeFileSync(usersFile, JSON.stringify(d,null,2)) }

function auth(req,res,next){
 if(req.session.user) next()
 else res.status(401).send("login required")
}

app.post('/register', async (req,res)=>{
 let u = load()
 const hash = await bcrypt.hash(req.body.pass,10)
 u.push({user:req.body.user,pass:hash})
 save(u)
 res.send("ok")
})

app.post('/login', async (req,res)=>{
 let u = load()
 let user = u.find(x=>x.user==req.body.user)
 if(!user) return res.send("no user")

 const ok = await bcrypt.compare(req.body.pass,user.pass)
 if(!ok) return res.send("wrong")

 req.session.user = user.user
 res.send("ok")
})

// downloads
app.post('/download', auth, async (req,res)=>{
 try{
  const url = req.body.url
  const name = Date.now()+".mp3"

  const file = fs.createWriteStream('downloads/'+name)

  const r = await axios({
    url,
    method:'GET',
    responseType:'stream'
  })

  r.data.pipe(file)

  file.on('finish',()=>res.send("ok"))

 }catch(e){
  res.send("erro")
 }
})

app.get('/songs', auth, (req,res)=>{
 res.json(fs.readdirSync('downloads'))
})

// youtube search
const API_KEY = "SUA_API_AQUI"

app.get('/yt', auth, async (req,res)=>{
 const q = req.query.q

 const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&type=video&q=${q}&key=${API_KEY}`

 const r = await axios.get(url)

 res.json(r.data.items.map(v=>({
   title:v.snippet.title,
   id:v.id.videoId,
   thumb:v.snippet.thumbnails.medium.url
 })))
})

app.listen(3000,()=>console.log("🔥 server on"))
EOF

# ========================
# FRONTEND
# ========================
mkdir public

cat <<'EOF' > public/index.html
<!DOCTYPE html>
<html>
<head>
<title>CL TECH PLAYER</title>

<style>
*{margin:0;padding:0;box-sizing:border-box}

body{
 background:#0f172a;
 color:white;
 font-family:sans-serif;
 padding:20px
}

.header-box{
 border:3px solid #22c55e;
 border-radius:20px;
 padding:30px;
 text-align:center;
 margin-bottom:30px;
 background:rgba(34,197,94,0.1);
 box-shadow:0 0 20px rgba(34,197,94,0.3)
}

.header-box h1{
 font-size:48px;
 font-weight:bold;
 letter-spacing:3px;
 text-shadow:0 0 10px rgba(34,197,94,0.5)
}

.container{
 max-width:500px;
 margin:auto
}

.section{
 background:#111827;
 padding:20px;
 margin:15px 0;
 border-radius:15px;
 border-left:4px solid #22c55e
}

.section-title{
 font-size:16px;
 font-weight:bold;
 margin-bottom:10px;
 color:#22c55e
}

input{
 width:100%;
 padding:10px;
 margin:5px 0;
 border:1px solid #22c55e;
 border-radius:8px;
 background:#0f172a;
 color:white;
 font-size:14px
}

input::placeholder{
 color:#666
}

input:focus{
 outline:none;
 border-color:#84cc16;
 box-shadow:0 0 10px rgba(34,197,94,0.3)
}

button{
 width:100%;
 padding:10px;
 margin:5px 0;
 border:none;
 border-radius:8px;
 background:#22c55e;
 color:#000;
 font-weight:bold;
 cursor:pointer;
 transition:all 0.3s
}

button:hover{
 background:#16a34a;
 transform:scale(1.02)
}

.card{
 background:#1f2937;
 padding:12px;
 margin:8px 0;
 border-radius:10px;
 border-left:3px solid #22c55e
}

.card p{
 margin:8px 0;
 font-size:14px
}

.card img{
 width:100%;
 border-radius:8px;
 margin:8px 0
}

.player{
 position:fixed;
 bottom:0;
 left:0;
 width:100%;
 background:#000;
 padding:15px 20px;
 border-top:2px solid #22c55e;
 z-index:1000
}

.player audio{
 width:100%;
 height:40px
}

hr{
 border:none;
 border-top:1px solid #22c55e;
 margin:15px 0;
 opacity:0.3
}

#songs, #yt{
 margin-top:15px
}
</style>

</head>

<body>

<div class="header-box">
<h1>⚡ CL TECH SERVER ⚡</h1>
</div>

<div class="container">

<div class="section">
 <p class="section-title">🔐 Autenticação</p>
 <input id="u" placeholder="Usuário">
 <input id="p" placeholder="Senha" type="password">
 <button onclick="reg()">📝 Registrar</button>
 <button onclick="login()">🔓 Login</button>
</div>

<hr>

<div class="section">
 <p class="section-title">⬇️ Download de Áudio</p>
 <input id="url" placeholder="Cole o link da música (MP3)">
 <button onclick="down()">⬇️ Baixar</button>
</div>

<div class="section">
 <p class="section-title">📂 Sua Biblioteca</p>
 <button onclick="load()">📂 Carregar Biblioteca</button>
 <div id="songs"></div>
</div>

<hr>

<div class="section">
 <p class="section-title">🔍 Buscar no YouTube</p>
 <input id="q" placeholder="Digite o nome da música">
 <button onclick="search()">🔍 Buscar</button>
 <div id="yt"></div>
</div>

</div>

<div class="player">
<audio id="audio" controls></audio>
</div>

<script>

function req(u,d){
 return fetch(u,{
  method:d?'POST':'GET',
  headers:{'Content-Type':'application/json'},
  body:d?JSON.stringify(d):null
 }).then(r=>r.text())
}

function reg(){
 if(!u.value || !p.value) return alert("Preencha user e pass")
 req('/register',{user:u.value,pass:p.value}).then(r=>alert(r))
}

function login(){
 if(!u.value || !p.value) return alert("Preencha user e pass")
 req('/login',{user:u.value,pass:p.value}).then(r=>alert(r))
}

function down(){
 if(!url.value) return alert("Cole um link")
 req('/download',{url:url.value}).then(r=>alert(r))
}

async function load(){
 let r = await fetch('/songs')
 let d = await r.json()

 songs.innerHTML=''

 if(d.length==0) return songs.innerHTML = '<p style="color:#666">Nenhuma música baixada</p>'

 d.forEach(s=>{
  songs.innerHTML += `
    <div class="card">
      <p>🎵 ${s}</p>
      <button onclick="play('/downloads/${s}')">▶️ Tocar</button>
    </div>
  `
 })
}

function play(src){
 audio.src = src
 audio.play()
}

async function search(){
 if(!q.value) return alert("Digite algo para buscar")
 let r = await fetch('/yt?q='+encodeURIComponent(q.value))
 let d = await r.json()

 yt.innerHTML=''

 d.forEach(v=>{
  yt.innerHTML += `
    <div class="card">
      <img src="${v.thumb}" alt="${v.title}">
      <p>${v.title.substring(0,50)}...</p>
      <button onclick="playYT('${v.id}')">▶️ Tocar</button>
    </div>
  `
 })
}

function playYT(id){
 audio.src = "https://www.youtube.com/embed/"+id
}

</script>

</body>
</html>
EOF

npm init -y
npm install express bcrypt express-session axios

echo ""
echo "======================================"
echo "✅ INSTALAÇÃO CONCLUÍDA"
echo "======================================"
echo ""
echo "▶️  Para iniciar: clexec"
echo ""
echo "🌐 Acesso externo com Cloudflare:"
echo "   cloudflared tunnel --url http://localhost:3000"
echo ""
echo "======================================"
