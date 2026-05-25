#!/bin/bash

set -e

echo "🔥 CL TECH MATRIX SAAS INSTALLER 🔥"

PROJECT="cltech-matrix"
mkdir -p $PROJECT
cd $PROJECT

echo "📦 Inicializando projeto Node.js..."
npm init -y

echo "📦 Instalando dependências..."
npm install express socket.io sqlite3 bcrypt dotenv googleapis @google/generative-ai blessed blessed-contrib

echo "📁 Criando estrutura..."

mkdir -p public

########################
# .env
########################
cat << 'EOF' > .env
YOUTUBE_API_KEY=AIzaSyCgg_E2mDf2ohaUxSauxqfX6lJZvjcxEJE
GEMINI_API_KEY=AIzaSyBkqc97R1Xztd71hnl4BaWzPtNpLjaMZJc
PORT=3000
EOF

########################
# database.js
########################
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

########################
# server.js
########################
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

async function askOraculo(msg) {
  const model = genAI.getGenerativeModel({ model: "gemini-pro" });
  const result = await model.generateContent(msg);
  const response = await result.response;
  return response.text();
}

app.post('/register', async (req, res) => {
  const { username, password } = req.body;
  const ip = req.ip;

  const hash = await bcrypt.hash(password, 10);

  db.run("INSERT INTO users (username, password, ip) VALUES (?, ?, ?)",
    [username, hash, ip],
    (err) => {
      if (err) return res.status(500).send(err.message);
      res.send("User created");
    }
  );
});

app.post('/login', (req, res) => {
  const { username, password } = req.body;

  db.get("SELECT * FROM users WHERE username = ?", [username], async (err, user) => {
    if (!user) return res.status(404).send("Not found");

    const ok = await bcrypt.compare(password, user.password);
    if (!ok) return res.status(401).send("Invalid");

    res.send("Logged in");
  });
});

app.get('/youtube', (req, res) => {
  res.json({ apiKey: process.env.YOUTUBE_API_KEY });
});

io.on('connection', (socket) => {
  const ip = socket.handshake.address;

  db.run("INSERT INTO logs (ip, action) VALUES (?, ?)", [ip, "connect"]);

  socket.on('chat', async (data) => {
    let msg = data.message;

    db.run("INSERT INTO messages (user, message) VALUES (?, ?)", [data.user, msg]);

    if (msg.startsWith("@oraculo")) {
      const response = await askOraculo(msg.replace("@oraculo", ""));
      io.emit('chat', { user: "ORACULO", message: response });
    } else {
      io.emit('chat', data);
    }
  });
});

server.listen(3000, () => console.log("Server running on 3000"));
EOF

########################
# admin-cli.js
########################
cat << 'EOF' > admin-cli.js
const blessed = require('blessed');
const contrib = require('blessed-contrib');
const db = require('./database');

const screen = blessed.screen();

const grid = new contrib.grid({ rows: 12, cols: 12, screen: screen });

const log = grid.set(0, 0, 6, 12, contrib.log, { label: 'Logs' });

const table = grid.set(6, 0, 6, 6, contrib.table, {
  keys: true,
  label: 'Users',
  columnWidth: [20, 20]
});

log.log("Admin CLI iniciado");

setInterval(() => {
  db.all("SELECT username, ip FROM users", (err, rows) => {
    if (rows) {
      table.setData({
        headers: ["User", "IP"],
        data: rows.map(r => [r.username, r.ip])
      });
      screen.render();
    }
  });
}, 2000);

screen.key(['escape', 'q', 'C-c'], () => process.exit(0));
screen.render();
EOF

########################
# index.html
########################
cat << 'EOF' > public/index.html
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>CL TECH MATRIX</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<div id="chat"></div>
<input id="msg" placeholder="Digite..." />
<button onclick="send()">Enviar</button>

<audio id="bgm" autoplay loop></audio>

<script src="/socket.io/socket.io.js"></script>
<script src="app.js"></script>
</body>
</html>
EOF

########################
# style.css
########################
cat << 'EOF' > public/style.css
body {
  background: black;
  color: #00FF41;
  font-family: monospace;
}

#chat {
  height: 80vh;
  overflow: auto;
}

input, button {
  background: black;
  color: #00FF41;
  border: 1px solid #00FF41;
  padding: 10px;
}
EOF

########################
# app.js
########################
cat << 'EOF' > public/app.js
const socket = io();

function send() {
  const msg = document.getElementById("msg").value;
  socket.emit("chat", { user: "guest", message: msg });
}

socket.on("chat", (data) => {
  const div = document.getElementById("chat");
  div.innerHTML += `<p><b>${data.user}:</b> ${data.message}</p>`;
});
EOF

########################
# FINAL INSTRUCTIONS
########################
echo ""
echo "=============================="
echo "✅ INSTALAÇÃO FINALIZADA"
echo "=============================="
echo ""
echo "▶ Rodar servidor:"
echo "   node server.js"
echo ""
echo "▶ Rodar painel admin:"
echo "   node admin-cli.js"
echo ""
echo "▶ Expor online com Cloudflare:"
echo "   cloudflared tunnel --url localhost:3000"
echo ""
echo "🔥 CL TECH MATRIX PRONTO 🔥"