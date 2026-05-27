#!/bin/bash
# ==============================================================================
# ||         Instalador Local da Plataforma Reposerver (Sem Sudo)             ||
# ==============================================================================

# Fail Fast: O script irá parar se qualquer comando falhar.
set -e

# --- Constantes ---
VENV_DIR=".venv_local"
LOG_FILE="/tmp/reposerver_install_local.log"

# Limpa e prepara o arquivo de log
> "$LOG_FILE"
echo "Iniciando instalação local do Reposerver..." | tee -a "$LOG_FILE"

echo "[1/3] Verificando se Python 3 e venv estão disponíveis..." | tee -a "$LOG_FILE"
if ! command -v python3 &> /dev/null; then
    echo "ERRO: O comando 'python3' não foi encontrado. Por favor, instale o Python 3." | tee -a "$LOG_FILE"
    exit 1
fi

echo "[2/3] Criando ambiente virtual Python em '$VENV_DIR'..." | tee -a "$LOG_FILE"
python3 -m venv "$VENV_DIR" >> "$LOG_FILE" 2>&1

echo "[3/3] Instalando dependências do Python com pip..." | tee -a "$LOG_FILE"
# Ativa o ambiente virtual, instala os pacotes e desativa.
source "$VENV_DIR/bin/activate"
pip install --upgrade pip >> "$LOG_FILE" 2>&1
pip install -r requirements.txt >> "$LOG_FILE" 2>&1
deactivate

echo "----------------------------------------------------" | tee -a "$LOG_FILE"
echo "SUCESSO: A preparação local foi concluída." | tee -a "$LOG_FILE"
echo "O ambiente está pronto em: $VENV_DIR" | tee -a "$LOG_FILE"
echo "Log de instalação disponível em: $LOG_FILE" | tee -a "$LOG_FILE"
echo "----------------------------------------------------" | tee -a "$LOG_FILE"
