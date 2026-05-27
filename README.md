# 🎵 Anime Pulse Music Server (Reposerver)

**Servidor de música compartilhada com AntiX Panel**

Uma aplicação Flask completa para streaming de música via YouTube, fila em tempo real e painel administrativo otimizado.

![Python](https://img.shields.io/badge/Python-3.9+-blue) ![Flask](https://img.shields.io/badge/Flask-3.x-black) ![Antix](https://img.shields.io/badge/Antix-Linux-green)

## ✨ Principais Funcionalidades

- Fila compartilhada com Socket.IO
- Download e streaming do YouTube (yt-dlp + mpv)
- Sistema de créditos e pagamentos
- Painel administrativo completo (AntiX Panel)
- Suporte nativo ao **Antix Linux**

## 🚀 Instalação Rápida no Antix

```bash
# Clone o repositório
git clone https://github.com/inaciooofc-commits/Reposerver.git
cd Reposerver

# Dê permissão e rode o instalador
chmod +x install_antix.sh
./install_antix.sh

# Inicie o servidor
python3 reposerver_main.py
```

Acesse no navegador: `http://localhost:5000` ou `http://seu-ip:5000`

## 📋 Pré-requisitos (Antix)

- mpv
- redis-server
- yt-dlp
- python3-pip
- build-essential

## 🛠 Comandos Úteis

- `./install_antix.sh` → Instalação completa
- `python3 reposerver_main.py --debug` → Modo debug
- `python3 reposerver_main.py` → Modo produção

## 📁 Estrutura Principal

- `app/` → Código principal (módulos organizados)
- `frontend/` → Templates e assets
- `cpp_engine/` → Componentes de performance
- `data/` → Banco de dados e arquivos locais

---

**Desenvolvido para rodar leve no Antix Linux.**
