#!/bin/bash

# Script de Inicialização para o Servidor de Repositório

# --- Configurações ---
APP_NAME="reposerver"
ROOT_DIR=$(dirname "$0") # Diretório onde o script está
PID_FILE="/var/run/$APP_NAME.pid"
HOST="0.0.0.0"
PORT="5000"

# Para SocketIO com Gunicorn, precisamos usar os workers do eventlet
WORKER_CLASS="eventlet"
# Número de workers: 2 por núcleo de CPU é um bom começo
# Use `nproc` para obter o número de núcleos
WORKERS=$(($(nproc) * 2))

# Módulo e aplicação Flask (arquivo:aplicativo)
# Nosso arquivo principal é run.py e a variável é 'app'
APP_MODULE="run:app"

# --- Validação ---
echo "Iniciando o servidor $APP_NAME..."

# Navega para o diretório do projeto
cd "$ROOT_DIR"
echo "Diretório de trabalho: $(pwd)"

# Verifica se Gunicorn está instalado
if ! command -v gunicorn &> /dev/null
then
    echo "Erro: gunicorn não foi encontrado no PATH."
    echo "Por favor, instale as dependências com: pip install -r requirements.txt"
    exit 1
fi

# --- Execução ---
echo "Host: $HOST"
echo "Porta: $PORT"
echo "Workers: $WORKERS"
echo "Worker Class: $WORKER_CLASS"

# Inicia o Gunicorn
# --daemon: roda em background
# --pid: especifica o arquivo de PID, crucial para o supervisor
# --bind: define o host e porta
# --workers: número de processos worker
# --worker-class: tipo de worker (essencial para SocketIO)
exec gunicorn \
    --pid "$PID_FILE" \
    --bind "$HOST:$PORT" \
    --workers "$WORKERS" \
    --worker-class "$WORKER_CLASS" \
    $APP_MODULE
