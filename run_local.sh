#!/bin/bash
# ==============================================================================
# ||            Script de Execução Local da Plataforma Reposerver             ||
# ==============================================================================

# Fail Fast
set -e

# --- Constantes ---
APP_MODULE="reposerver_main:app"
VENV_DIR=".venv_local"

# Verifica se o ambiente virtual existe
if [ ! -d "$VENV_DIR" ]; then
    echo "ERRO: Ambiente virtual não encontrado em '$VENV_DIR'."
    echo "Por favor, execute o script 'install_local.sh' primeiro."
    exit 1
fi

# Ativa o ambiente virtual
source "$VENV_DIR/bin/activate"

echo "Iniciando o servidor Gunicorn em http://0.0.0.0:5000..."
echo "Pressione CTRL+C para parar o servidor."

# Inicia o Gunicorn
# Usamos 'eventlet' para performance e suporte a WebSocket
gunicorn --workers 3 --worker-class eventlet --bind 0.0.0.0:5000 "$APP_MODULE"

# O script irá terminar quando o Gunicorn for parado.
