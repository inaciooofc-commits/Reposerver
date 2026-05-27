#!/bin/bash

# ==============================================================================
# ||          Script de Inicialização Robusto para o RepoServer             ||
# ==============================================================================

# --- Configurações ---
APP_NAME="reposerver"

# Obtém o caminho real e absoluto do diretório onde o script está.
# Isso garante que ele funcione independentemente de onde for chamado.
ROOT_DIR=$(dirname "$(realpath "$0")")

VENV_DIR="$ROOT_DIR/venv"
PID_FILE="/var/run/$APP_NAME.pid"
HOST="0.0.0.0"
PORT="5000"
WORKER_CLASS="eventlet"
WORKERS=$(($(nproc) * 2))
APP_MODULE="run:app"

# --- Execução ---
echo "Iniciando o servidor $APP_NAME..."
echo "Diretório do projeto: $ROOT_DIR"

# O caminho para o executável do Gunicorn DENTRO do nosso ambiente virtual.
GUNICORN_EXEC="$VENV_DIR/bin/gunicorn"

# Muda para o diretório raiz do projeto. Se falhar, o script para.
cd "$ROOT_DIR" || exit 1

# --- Validação Crucial ---
# Verifica se o executável do Gunicorn específico do nosso venv existe.
if [ ! -f "$GUNICORN_EXEC" ]; then
    echo "[ERRO] O executável do Gunicorn não foi encontrado em: $GUNICORN_EXEC"
    echo "[AÇÃO] Isso geralmente significa que o ambiente virtual não foi criado ou as dependências não foram instaladas."
    echo "[AÇÃO] Por favor, execute o script 'sudo bash install.sh' para corrigir a instalação."
    exit 1
fi

# --- Início do Servidor ---
echo "Host: $HOST"
echo "Porta: $PORT"
echo "Workers: $WORKERS"
echo "Worker Class: $WORKER_CLASS"

# O comando 'exec' substitui o processo atual (o shell) pelo gunicorn.
# Isso é uma prática recomendada para scripts de inicialização usados pelo systemd.
exec "$GUNICORN_EXEC" \
    --pid "$PID_FILE" \
    --bind "$HOST:$PORT" \
    --workers "$WORKERS" \
    --worker-class "$WORKER_CLASS" \
    $APP_MODULE
