#!/bin/bash

# ==============================================================================
# ||         Instalador de Dependências para o RepoServer (Modo Manual)     ||
# ==============================================================================

echo "[PASSO 1/4] Atualizando a lista de pacotes do sistema..."
sudo apt-get update

echo "[PASSO 2/4] Instalando pacotes essenciais (python3, pip, venv, nproc)..."
sudo apt-get install -y python3-pip python3-venv python3-dev build-essential libssl-dev libffi-dev

echo "[PASSO 3/4] Criando ambiente virtual em ./venv..."
python3 -m venv venv

echo "[PASSO 4/4] Instalando dependências Python do requirements.txt..."
# Ativa o venv, instala e desativa
source venv/bin/activate
pip install -r requirements.txt
deactivate

echo ""
echo "------------------------------------------------------------------"
echo "|| Instalação concluída com sucesso!                            ||"
echo "------------------------------------------------------------------"
echo "Para iniciar o servidor, execute o comando:"
echo "--> bash start.sh"
echo ""
echo "O servidor estará acessível em: http://<IP_DO_SERVIDOR>:5000"
echo "------------------------------------------------------------------"

