#!/bin/bash
# ==============================================================================
# ||         Instalador Silencioso e Automatizado da Plataforma Reposerver    ||
# ||                    Otimizado para Antix Linux (SysVinit)                 ||
# ==============================================================================

# Fail Fast: O script irá parar se qualquer comando falhar.
set -e

# --- Constantes ---
APP_NAME="reposerver"
APP_USER="reposerver" # Usuário de sistema dedicado
APP_DIR="/opt/$APP_NAME"
SRC_DIR=$(pwd)

SERVICE_SCRIPT_NAME="$APP_NAME"
SERVICE_FILE_DST="/etc/init.d/$SERVICE_SCRIPT_NAME"

LOG_FILE="/tmp/reposerver_install_auto.log"

# Limpa e prepara o arquivo de log
> "$LOG_FILE"
echo "Iniciando instalação automatizada do Reposerver..." | tee -a "$LOG_FILE"

# --- Função de Instalação Automatizada ---
install_platform_auto() {
    echo "[1/6] Atualizando pacotes e instalando dependências do sistema..." | tee -a "$LOG_FILE"
    sudo apt-get update -y >> "$LOG_FILE" 2>&1
    sudo apt-get install -y python3 python3-pip python3-venv g++ make dialog >> "$LOG_FILE" 2>&1

    echo "[2/6] Criando usuário de sistema dedicado '$APP_USER'..." | tee -a "$LOG_FILE"
    if ! id "$APP_USER" &>/dev/null; then
        sudo adduser --system --no-create-home --group "$APP_USER" >> "$LOG_FILE" 2>&1
    else
        echo "Usuário '$APP_USER' já existe, pulando." | tee -a "$LOG_FILE"
    fi

    echo "[3/6] Configurando diretório de instalação em $APP_DIR..." | tee -a "$LOG_FILE"
    sudo mkdir -p "$APP_DIR"
    # Copia os arquivos da aplicação para o diretório de destino
    sudo cp -r app config cpp_engine frontend scripts services data docs reposerver_main.py requirements.txt reposerver_service_script "$APP_DIR/"
    sudo chown -R "$APP_USER":"$APP_USER" "$APP_DIR"

    echo "[4/6] Criando ambiente virtual Python e instalando dependências..." | tee -a "$LOG_FILE"
    sudo -u "$APP_USER" python3 -m venv "$APP_DIR/venv" >> "$LOG_FILE" 2>&1
    sudo "$APP_DIR/venv/bin/pip" install --upgrade pip >> "$LOG_FILE" 2>&1
    sudo "$APP_DIR/venv/bin/pip" install -r "$APP_DIR/requirements.txt" >> "$LOG_FILE" 2>&1

    echo "[5/6] Instalando e habilitando o serviço SysVinit..." | tee -a "$LOG_FILE"
    sudo cp "$APP_DIR/reposerver_service_script" "$SERVICE_FILE_DST"
    sudo chmod +x "$SERVICE_FILE_DST"
    sudo update-rc.d "$SERVICE_SCRIPT_NAME" defaults >> "$LOG_FILE" 2>&1

    echo "[6/6] Iniciando o serviço $SERVICE_SCRIPT_NAME..." | tee -a "$LOG_FILE"
    sudo service "$SERVICE_SCRIPT_NAME" start >> "$LOG_FILE" 2>&1
}

# --- Ponto de Entrada ---
install_platform_auto

# --- Verificação Final ---
sleep 5 # Espera um momento para o serviço inicializar
if sudo service "$SERVICE_SCRIPT_NAME" status &>/dev/null; then
    echo "----------------------------------------------------" | tee -a "$LOG_FILE"
    echo "SUCESSO: A plataforma Reposerver foi instalada e iniciada." | tee -a "$LOG_FILE"
    echo "Use 'sudo service $SERVICE_SCRIPT_NAME status' para verificar." | tee -a "$LOG_FILE"
    echo "Log de instalação disponível em: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "----------------------------------------------------" | tee -a "$LOG_FILE"
else
    echo "----------------------------------------------------" | tee -a "$LOG_FILE"
    echo "ERRO: A instalação terminou, mas o serviço não pôde ser iniciado." | tee -a "$LOG_FILE"
    echo "Verifique os logs da aplicação em $APP_DIR/logs/ para detalhes." | tee -a "$LOG_FILE"
    echo "Log de instalação disponível em: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "----------------------------------------------------" | tee -a "$LOG_FILE"
    exit 1
fi
