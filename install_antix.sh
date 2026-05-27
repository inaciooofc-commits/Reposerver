#!/bin/bash

# ==============================================================================
# ||          Instalador Interativo e Gerenciador para o RepoServer           ||
# ||                    Otimizado para Antix Linux (SysVinit)                 ||
# ==============================================================================

# --- Constantes ---
APP_NAME="reposerver"
APP_DIR="/opt/$APP_NAME"
SRC_DIR=$(pwd)
SERVICE_SCRIPT_NAME="$APP_NAME"
SERVICE_FILE_SRC="$SRC_DIR/reposerver_service_script"
SERVICE_FILE_DST="/etc/init.d/$SERVICE_SCRIPT_NAME"
LOG_FILE="/tmp/reposerver_install.log"

# --- Funções de UI com 'dialog' ---

# Exibe o menu principal
show_main_menu() {
    dialog --title "Painel de Controle - RepoServer" \
           --cancel-label "Sair" \
           --menu "Selecione uma opção:" 15 55 5 \
           1 "Instalar/Atualizar o RepoServer" \
           2 "Iniciar o Serviço" \
           3 "Parar o Serviço" \
           4 "Verificar Status do Serviço" \
           5 "Remover o RepoServer" 2> /tmp/menu.choice

    case $? in
        0) handle_choice $(cat /tmp/menu.choice);;
        1) clear; echo "Operação cancelada.";; # Cancelar
        255) clear; echo "ESC pressionado. Saindo.";; # ESC
    esac
}

# Lida com a escolha do menu
handle_choice() {
    case $1 in
        1) install_or_update ;; # Instalar/Atualizar
        2) sudo service $SERVICE_SCRIPT_NAME start ; show_main_menu;; # Iniciar
        3) sudo service $SERVICE_SCRIPT_NAME stop ; show_main_menu;; # Parar
        4) sudo service $SERVICE_SCRIPT_NAME status ; sleep 3; show_main_menu;; # Status
        5) uninstall_app ;; # Remover
        *) show_main_menu;;
    esac
}

# --- Funções de Instalação ---

install_or_update() {
    (
    # 1. Instalar dependências do sistema
    echo 10; echo "XXX\nAtualizando o sistema e instalando dependências (dialog, python3, pip)...\nXXX"
    sudo apt-get update >> $LOG_FILE 2>&1
    sudo apt-get install -y dialog python3 python3-pip python3-venv >> $LOG_FILE 2>&1

    # 2. Criar diretório do aplicativo
    echo 30; echo "XXX\nCriando diretório de instalação em $APP_DIR...\nXXX"
    sudo mkdir -p $APP_DIR >> $LOG_FILE 2>&1
    sudo cp -r $SRC_DIR/* $APP_DIR/

    # 3. Criar e popular ambiente virtual
    echo 50; echo "XXX\nConfigurando ambiente Python em $APP_DIR/venv...\nXXX"
    sudo python3 -m venv $APP_DIR/venv >> $LOG_FILE 2>&1
    sudo $APP_DIR/venv/bin/pip install -r $APP_DIR/requirements.txt >> $LOG_FILE 2>&1

    # 4. Instalar o serviço SysVinit
    echo 70; echo "XXX\nInstalando serviço de inicialização...\nXXX"
    sudo cp $APP_DIR/reposerver_service_script $SERVICE_FILE_DST
    sudo chmod +x $SERVICE_FILE_DST

    # 5. Habilitar e iniciar o serviço
    echo 90; echo "XXX\nHabilitando e iniciando o serviço $SERVICE_SCRIPT_NAME...\nXXX"
    sudo update-rc.d $SERVICE_SCRIPT_NAME defaults >> $LOG_FILE 2>&1
    sudo service $SERVICE_SCRIPT_NAME start >> $LOG_FILE 2>&1

    echo 100; echo "XXX\nInstalação concluída!\nXXX"
    sleep 2
    ) | dialog --title "Instalação do RepoServer" --gauge "Por favor, aguarde..." 10 70 0

    dialog --title "Sucesso" --msgbox "O RepoServer foi instalado e iniciado com sucesso!" 6 50
    show_main_menu
}

# --- Função de Desinstalação ---
uninstall_app() {
    dialog --yesno "Tem certeza que deseja remover completamente o RepoServer?" 8 50
    if [ $? -eq 0 ]; then # Se 'Yes' for selecionado
        (
        echo 20; echo "XXX\nParando e desabilitando o serviço...\nXXX"
        sudo service $SERVICE_SCRIPT_NAME stop >> $LOG_FILE 2>&1
        sudo update-rc.d -f $SERVICE_SCRIPT_NAME remove >> $LOG_FILE 2>&1

        echo 50; echo "XXX\nRemovendo arquivos de serviço...\nXXX"
        sudo rm -f $SERVICE_FILE_DST

        echo 80; echo "XXX\nRemovendo diretório do aplicativo $APP_DIR...\nXXX"
        sudo rm -rf $APP_DIR
        
        echo 100; echo "XXX\nDesinstalação completa!\nXXX"
        sleep 2
        ) | dialog --title "Desinstalação" --gauge "Removendo o RepoServer..." 10 70 0
        dialog --title "Concluído" --msgbox "RepoServer foi removido com sucesso." 6 50
    fi
    clear
}

# --- Ponto de Entrada ---
if ! command -v dialog &> /dev/null; then
    echo "O utilitário 'dialog' não está instalado. Tentando instalar..."
    sudo apt-get update && sudo apt-get install -y dialog
    if ! command -v dialog &> /dev/null; then
        echo "Falha ao instalar o 'dialog'. Por favor, instale-o manualmente e execute o script novamente."
        exit 1
    fi
fi

show_main_menu
clear
