#!/bin/bash

# install_antix.sh
# Um instalador interativo e inteligente para configurar o servidor no Antix/Debian.

# --- Verificação de Dependência Essencial (dialog) ---
if ! command -v dialog &> /dev/null; then
    echo "O pacote 'dialog' é necessário para a interface gráfica, mas não está instalado."
    read -p "Deseja instalá-lo agora? (s/n) " choice
    if [[ "$choice" == "s" || "$choice" == "S" ]]; then
        echo "Instalando 'dialog'... Por favor, insira sua senha de superusuário se solicitado."
        sudo apt-get update && sudo apt-get install -y dialog
    else
        echo "Instalação cancelada. O 'dialog' é obrigatório para continuar."
        exit 1
    fi
fi

# --- Funções de Coleta de Informação ---
get_system_info() {
    CURRENT_DATETIME=$(date +"%A, %d de %B de %Y, %H:%M:%S")
    HOSTNAME=$(hostname)
    OS_INFO=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"' || uname -a)
    USER_NAME=$(whoami)
}

# --- Lógica de Instalação ---
install_dependencies() {
    ( 
      echo "XXX"; echo "Atualizando a lista de pacotes (apt-get update)..."; sudo apt-get update; sleep 2;
      echo "XXX"; echo "Instalando Python 3 e Pip..."; sudo apt-get install -y python3 python3-pip; sleep 2;
      echo "XXX"; echo "Instalando Node.js e NPM..."; sudo apt-get install -y nodejs npm; sleep 2;
      echo "XXX"; echo "Instalando Gunicorn via Pip..."; sudo pip3 install gunicorn; sleep 2;
      echo "XXX"; echo "Instalando dependências Python do projeto (requirements.txt)..."; sudo pip3 install -r requirements.txt; sleep 2;
      echo "XXX"; echo "Instalação concluída!"; sleep 2;
    ) | dialog --title "Instalando Dependências" --gauge "Iniciando..." 8 75 0

    dialog --title "Sucesso" --msgbox "Todas as dependências do sistema e do projeto foram instaladas com sucesso." 8 50
}


# --- Telas da Interface ---
show_welcome_screen() {
    get_system_info
    dialog --title "Assistente de Instalação do Servidor" --colors --cr-wrap \
           --msgbox "Bem-vindo ao assistente de configuração para o seu servidor no {\Zb\Z1$OS_INFO}\Zn.\n\nEste script irá guiá-lo na instalação e configuração dos serviços necessários.\n\n- \Zb\Z1Hostname:\Zn $HOSTNAME
- \Zb\Z1Usuário Atual:\Zn $USER_NAME
- \Zb\Z1Data e Hora:\Zn $CURRENT_DATETIME" \
           15 75
}

show_main_menu() {
    dialog --title "Menu Principal" --colors \
           --menu "Escolha uma opção usando as {\Zb\Z1setas}\Zn e pressione {\Zb\Z1Enter}\Zn:" \
           15 60 4 \
           1 "Instalar Dependências do Sistema" \
           2 "Configurar e Ativar Serviços (systemd)" \
           3 "Verificar Status dos Serviços" \
           4 "Sair" 2> /tmp/menu_choice
}

# --- Lógica Principal ---
show_welcome_screen

while true; do
    show_main_menu
    choice=$(cat /tmp/menu_choice)
    clear # Limpa a tela após o menu do dialog
    
    case $choice in
        1)
            install_dependencies
            ;;
        2)
            # Aqui entrará a lógica para criar os arquivos .service
            dialog --title "Configurar Serviços" --infobox "Lógica de configuração de serviços a ser implementada..." 5 40
            sleep 2
            ;;
        3)
            # Aqui entrará a lógica para rodar 'systemctl status ...'
            dialog --title "Status dos Serviços" --infobox "Lógica de verificação de status a ser implementada..." 5 40
            sleep 2
            ;;
        4)
            echo "Saindo do assistente. Até logo!"
            rm -f /tmp/menu_choice
            exit 0
            ;;
        *)
            # Ação para ESC ou Cancelar
            echo "Instalação cancelada. Até logo!"
            rm -f /tmp/menu_choice
            exit 0
            ;;
    esac
done
