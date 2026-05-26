#!/bin/bash

# Script de Instalação para o Painel Ninja

# 1. Atualizar os pacotes do sistema
sudo apt-get update

# 2. Instalar o Node.js e o npm
# O Antix é baseado no Debian, então estes comandos devem funcionar.
# Se o Antix não tiver o curl, instale com: sudo apt-get install curl
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# 3. Instalar o PM2 globalmente
# O PM2 é um gerenciador de processos que manterá o painel online.
sudo npm install -g pm2

# 4. Instalar as dependências do projeto
# Este comando lerá o package.json e instalará tudo o que o projeto precisa.
npm install

# 5. Iniciar a aplicação com o PM2
# O PM2 cuidará de reiniciar a aplicação se ela cair e a manterá rodando em segundo plano.
pm2 start server.js --name "painel-ninja"

# 6. Salvar a configuração do PM2
# Isso garante que o painel inicie automaticamente com o sistema.
pm2 save

echo "\n\nPainel Ninja instalado com sucesso!"
echo "Para gerenciar o painel, use os seguintes comandos:"
echo "  pm2 status          # Ver o status"
echo "  pm2 stop painel-ninja # Parar o painel"
echo "  pm2 restart painel-ninja# Reiniciar o painel"
echo "  pm2 logs painel-ninja # Ver os logs em tempo real"

echo "\nAcesse seu painel em: http://localhost:3000"
