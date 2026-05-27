#!/bin/bash
# ==============================================================================
# ||       Instalador Final para Antix (Executar como ROOT)                   ||
# ==============================================================================

set -e

APP_NAME="reposerver"
APP_USER="reposerver"
APP_DIR="/opt/$APP_NAME"
SERVICE_FILE_DST="/etc/init.d/$APP_NAME"
LOG_FILE="/tmp/reposerver_install_final.log"

> "$LOG_FILE"
echo "Iniciando instalação (executando como ROOT)..." | tee -a "$LOG_FILE"

echo "[1/6] Atualizando pacotes e instalando dependências..." | tee -a "$LOG_FILE"
apt-get update -y >> "$LOG_FILE" 2>&1
apt-get install -y python3 python3-pip python3-venv g++ make dialog >> "$LOG_FILE" 2>&1

echo "[2/6] Criando usuário de sistema '$APP_USER'..." | tee -a "$LOG_FILE"
if ! id "$APP_USER" &>/dev/null; then
    adduser --system --no-create-home --group "$APP_USER" >> "$LOG_FILE" 2>&1
else
    echo "Usuário '$APP_USER' já existe." | tee -a "$LOG_FILE"
fi

echo "[3/6] Configurando diretório de instalação $APP_DIR..." | tee -a "$LOG_FILE"
mkdir -p "$APP_DIR"
cp -r app config cpp_engine frontend scripts services data docs reposerver_main.py reposerver_service_script "$APP_DIR/"
chown -R "$APP_USER":"$APP_USER" "$APP_DIR"

# Usa o script de serviço com depuração
cp reposerver_service_script "$APP_DIR/"

echo "[4/6] Criando ambiente virtual e instalando dependências Python..." | tee -a "$LOG_FILE"
# Executa os comandos de venv e pip como o usuário da aplicação
su -s /bin/bash -c "python3 -m venv '$APP_DIR/venv'" "$APP_USER" >> "$LOG_FILE" 2>&1
su -s /bin/bash -c "'$APP_DIR/venv/bin/pip' install --upgrade pip" "$APP_USER" >> "$LOG_FILE" 2>&1
su -s /bin/bash -c "'$APP_DIR/venv/bin/pip' install -r '$APP_DIR/requirements.txt'" "$APP_USER" >> "$LOG_FILE" 2>&1

echo "[5/6] Instalando e habilitando o serviço SysVinit..." | tee -a "$LOG_FILE"
cp "$APP_DIR/reposerver_service_script" "$SERVICE_FILE_DST"
chmod +x "$SERVICE_FILE_DST"
update-rc.d "$APP_NAME" defaults >> "$LOG_FILE" 2>&1

echo "[6/6] Tentando iniciar o serviço $APP_NAME..." | tee -a "$LOG_FILE"
service "$APP_NAME" start >> "$LOG_FILE" 2>&1 || echo "Falha ao iniciar o serviço. Verificando logs..."

sleep 5
echo "Verificação final do status do serviço..." | tee -a "$LOG_FILE"
if service "$APP_NAME" status &>/dev/null; then
    echo "SUCESSO: O serviço Reposerver está em execução." | tee -a "$LOG_FILE"
else
    echo "ERRO: O serviço não iniciou." | tee -a "$LOG_FILE"
    echo "O log de depuração do serviço deve estar em /tmp/reposerver_debug.log" | tee -a "$LOG_FILE"
    exit 1
fi
