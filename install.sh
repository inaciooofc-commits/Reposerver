#!/bin/bash

echo "🔥 CL TECH MATRIX - FULL INSTALL + CYBER START SYSTEM 🔥"

PROJECT="cltech-matrix-cyber"

mkdir -p "$PROJECT"
cd "$PROJECT" || exit 1

echo "📦 Inicializando Node.js..."
npm init -y

echo "📦 Instalando dependências..."
npm install express socket.io sqlite3 bcrypt dotenv googleapis @google/generative-ai blessed blessed-contrib

mkdir -p public

# =========================
# .env
# =========================
cat << 'EOF' > .env
YOUTUBE_API_KEY=AIzaSyCgg_E2mDf2ohaUxSauqXf6lJZvjcxEJE
GEMINI_API_KEY=AIzaSyBkqc97R1Xztd71hnl4BaWzPtNpLjaMZJc
PORT=3000
EOF

# =========================
# database.js
# =========================
cat << 'EOF' > database.js
const sqlite3 = require('sqlite3').verbose();
const db = new sqlite3.Database('./database.db');

db.serialize(() => {
  db.run(`CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE,
    password TEXT,
    ip TEXT
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS messages (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user TEXT,
    message TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    ip TEXT,
    action TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);
});

module.exports = db;
EOF

# =========================
# server.js
# =========================
cat << 'EOF' > server.js
require('dotenv').config();
const express = require('express');
const http = require('http');
const bcrypt = require('bcrypt');
const { Server } = require('socket.io');
const db = require('./database');

const { GoogleGenerativeAI } = require("@google/generative-ai");

const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(express.json());
app.use(express.static('public'));

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

async function oraculo(msg) {
  const model = genAI.getGenerativeModel({ model: "gemini-pro" });
  const result = await model.generateContent(msg);
  return (await result.response).text();
}

app.post('/register', async (req, res) => {
  const { username, password } = req.body;
  const hash = await bcrypt.hash(password, 10);

  db.run("INSERT INTO users (username, password, ip) VALUES (?,?,?)",
    [username, hash, req.ip],
    err => {
      if (err) return res.status(500).send(err.message);
      res.send("OK");
    }
  );
});

app.post('/login', (req, res) => {
  const { username, password } = req.body;

  db.get("SELECT * FROM users WHERE username = ?", [username], async (err, user) => {
    if (!user) return res.status(404).send("NOT FOUND");

    const ok = await bcrypt.compare(password, user.password);
    if (!ok) return res.status(401).send("INVALID");

    res.send("LOGGED");
  });
});

io.on('connection', (socket) => {
  const ip = socket.handshake.address;
  db.run("INSERT INTO logs (ip, action) VALUES (?,?)", [ip, "connect"]);

  socket.on('chat', async (data) => {
    db.run("INSERT INTO messages (user,message) VALUES (?,?)", [data.user, data.message]);

    if (data.message.startsWith("@oraculo")) {
      const r = await oraculo(data.message.replace("@oraculo", ""));
      io.emit("chat", { user: "ORACULO", message: r });
    } else {
      io.emit("chat", data);
    }
  });
});

server.listen(process.env.PORT || 3000, () =>
  console.log("SERVER ONLINE")
);
EOF

# =========================
# admin-cli.js
# =========================
cat << 'EOF' > admin-cli.js
const blessed = require('blessed');
const contrib = require('blessed-contrib');
const db = require('./database');

const screen = blessed.screen();
const grid = new contrib.grid({ rows: 12, cols: 12, screen });

const log = grid.set(0, 0, 6, 12, contrib.log, { label: 'CYBER LOG' });

const table = grid.set(6, 0, 6, 12, contrib.table, {
  label: 'USERS ONLINE',
  columnWidth: [20, 20]
});

log.log("CYBER ADMIN ONLINE");

setInterval(() => {
  db.all("SELECT username, ip FROM users", (err, rows) => {
    if (rows) {
      table.setData({
        headers: ["USER", "IP"],
        data: rows.map(r => [r.username, r.ip])
      });
      screen.render();
    }
  });
}, 2000);

screen.key(['escape','q','C-c'], () => process.exit(0));
screen.render();
EOF

# =========================
# FRONTEND
# =========================
cat << 'EOF' > public/index.html
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>CL TECH CYBER</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<div id="chat"></div>
<input id="msg">
<button onclick="send()">SEND</button>

<script src="/socket.io/socket.io.js"></script>
<script src="app.js"></script>
</body>
</html>
EOF

cat << 'EOF' > public/style.css
body {
  background:black;
  color:#00ff41;
  font-family: monospace;
}
#chat { height:80vh; overflow:auto; }
input, button {
  background:black;
  color:#00ff41;
  border:1px solid #00ff41;
}
EOF

cat << 'EOF' > public/app.js
const socket = io();

function send(){
  const msg=document.getElementById("msg").value;
  socket.emit("chat",{user:"guest",message:msg});
}

socket.on("chat",(d)=>{
  document.getElementById("chat").innerHTML += `<p><b>${d.user}:</b> ${d.message}</p>`;
});
EOF

# =========================
# START.SH (CYBER MODE LINK)
# =========================
cat << 'EOF' > start.sh
#!/bin/bash

chmod +x start.sh

bash start.sh
EOF

# =========================
# FINAL INSTRUCTIONS
# =========================
echo ""
echo "=============================="
echo "🔥 INSTALL COMPLETO FINALIZADO"
echo "=============================="
echo ""
echo "▶ Entrar no projeto:"
echo "   cd $PROJECT"
echo ""
echo "▶ Dar permissão:"
echo "   chmod +x start.sh"
echo ""
echo "▶ Rodar sistema cyber:"
echo "   ./start.sh"
echo ""
echo "⚡ CYBER SYSTEM READY ⚡"