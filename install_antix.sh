#!/bin/bash

# ==============================================================================
# ||         Instalador e Gerenciador da Plataforma Híbrida Reposerver        ||
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

LOG_FILE="/tmp/reposerver_install.log"

# Limpa o log de instalações anteriores
> $LOG_FILE

# --- Funções de UI com 'dialog' ---

# Verifica se o dialog está instalado, se não, tenta instalar ou sai com erro.
check_dialog() {
    if ! command -v dialog &> /dev/null; then
        echo "O utilitário 'dialog' não está instalado. Tentando instalar..." | tee -a $LOG_FILE
        sudo apt-get update && sudo apt-get install -y dialog || {
            echo "Falha ao instalar o 'dialog'. Por favor, instale-o manualmente ('sudo apt-get install dialog') e execute o script novamente." >&2
            exit 1
        }
    fi
}

# Função principal de instalação
install_platform() {
    (
    # 1. Instalar dependências do sistema (Python, G++, make, etc)
    echo 10; echo "XXX\nAtualizando pacotes e instalando dependências base (python3, pip, g++, make)...\nXXX"
    sudo apt-get update >> $LOG_FILE 2>&1
    sudo apt-get install -y python3 python3-pip python3-venv g++ make >> $LOG_FILE 2>&1

    # 2. Criar usuário de sistema dedicado para segurança
    echo 25; echo "XXX\nCriando usuário de sistema dedicado '$APP_USER'...\nXXX"
    if ! id "$APP_USER" &>/dev/null; then
        sudo adduser --system --no-create-home --group $APP_USER >> $LOG_FILE 2>&1
    else
        echo "Usuário '$APP_USER' já existe, pulando." >> $LOG_FILE
    fi

    # 3. Preparar diretório de instalação
    echo 40; echo "XXX\nConfigurando diretório de instalação em $APP_DIR...\nXXX"
    sudo mkdir -p $APP_DIR
    # Copia a nova estrutura de arquivos
    sudo cp -r app config cpp_engine frontend scripts services data docs reposerver_main.py requirements.txt .env.example reposerver_service_script $APP_DIR/
    sudo chown -R $APP_USER:$APP_USER $APP_DIR

    # 4. Criar ambiente virtual e instalar dependências Python
    echo 60; echo "XXX\nCriando ambiente Python e instalando dependências via pip...\nXXX"
    sudo -u $APP_USER python3 -m venv $APP_DIR/venv >> $LOG_FILE 2>&1
    sudo $APP_DIR/venv/bin/pip install --upgrade pip >> $LOG_FILE 2>&1
    sudo $APP_DIR/venv/bin/pip install -r $APP_DIR/requirements.txt >> $LOG_FILE 2>&1

    # 5. Instalar o serviço SysVinit
    echo 75; echo "XXX\nInstalando e habilitando o serviço de sistema ($SERVICE_SCRIPT_NAME)...\nXXX"
    sudo cp $APP_DIR/reposerver_service_script $SERVICE_FILE_DST
    sudo chmod +x $SERVICE_FILE_DST
    sudo update-rc.d $SERVICE_SCRIPT_NAME defaults >> $LOG_FILE 2>&1

    # 6. Iniciar o serviço
    echo 90; echo "XXX\nIniciando o serviço $SERVICE_SCRIPT_NAME pela primeira vez...\nXXX"
    sudo service $SERVICE_SCRIPT_NAME start >> $LOG_FILE 2>&1

    echo 100; echo "XXX\nInstalação concluída! Verificando status final...\nXXX"
    sleep 2
    ) | dialog --title "Instalação da Plataforma Reposerver" --gauge "Instalando e configurando o sistema..." 10 75 0

    # Verificação Final
    if sudo service $SERVICE_SCRIPT_NAME status &>/dev/null; then
        dialog --title "Sucesso" --msgbox "A plataforma Reposerver foi instalada e iniciada com sucesso!\n\nUse 'sudo service reposerver status' para verificar." 8 60
    else
        ERROR_MSG="A instalação terminou, mas o serviço não pôde ser iniciado.\n\nCausas comuns:\n- Erro na aplicação (verifique $APP_DIR/logs/reposerver.log)\n- Problema com Gunicorn (verifique $APP_DIR/logs/gunicorn.log)\n- Erro de permissão.\n\nVerifique os logs para detalhes." 
        dialog --title "ERRO NA INICIALIZAÇÃO" --msgbox "$ERROR_MSG" 15 70
    fi
}

# --- Ponto de Entrada ---
check_dialog
install_platform
clear
echo "Instalação finalizada. Verifique os logs em $LOG_FILE para detalhes."
