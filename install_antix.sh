#!/bin/bash

# install_antix.sh
# Um instalador interativo e inteligente para configurar o servidor no Antix/Debian (SysVinit).

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

# --- Variáveis Globais ---
PROJECT_DIR=$(pwd)
USER_NAME=$(whoami)

# --- Funções de Coleta de Informação ---
get_system_info() {
    CURRENT_DATETIME=$(date +"%A, %d de %B de %Y, %H:%M:%S")
    HOSTNAME=$(hostname)
    OS_INFO=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2 | tr -d '"' || uname -a)
}

# --- Lógica de Instalação de Dependências ---
install_dependencies() {
    ( 
      echo "XXX"; echo "Atualizando a lista de pacotes..."; sudo apt-get update; sleep 1;
      echo "XXX"; echo "Instalando Python 3, Pip, Psutil..."; sudo apt-get install -y python3 python3-pip python3-psutil; sleep 2;
      echo "XXX"; echo "Instalando Gunicorn via Pip..."; sudo pip3 install gunicorn; sleep 2;
      echo "XXX"; echo "Instalando dependências do projeto (requirements.txt)..."; sudo pip3 install -r requirements.txt; sleep 2;
      echo "XXX"; echo "Instalação concluída!"; sleep 2;
    ) | dialog --title "Instalando Dependências" --gauge "Iniciando..." 8 75 0
    dialog --title "Sucesso" --msgbox "Dependências instaladas." 6 40
}

# --- Lógica Genérica de Criação de Serviço (SysVinit) ---
create_sysvinit_service() {
    local service_name=$1
    local service_description=$2
    local start_command=$3
    local service_user=$4
    local pid_file=$5

    local service_script_path="/etc/init.d/$service_name"

    local script_content="#!/bin/bash
### BEGIN INIT INFO
# Provides:          $service_name
# Required-Start:    \$remote_fs \$syslog \$network
# Required-Stop:     \$remote_fs \$syslog \$network
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: $service_description
### END INIT INFO

NAME=$service_name
PIDFILE=$pid_file
LOGFILE=/var/log/\$NAME.log
USER=$service_user
CMD=\"$start_command\"

. /lib/lsb/init-functions

start() {
    log_daemon_msg \"Iniciando \"\$NAME\"\" \"\$NAME\"
    start-stop-daemon --start --quiet --pidfile \$PIDFILE --chuid \$USER --background --make-pidfile --exec /bin/bash -- -c \"exec \$CMD >> \$LOGFILE 2>&1\"
    log_end_msg \$?
}

stop() {
    log_daemon_msg \"Parando \"\$NAME\"\" \"\$NAME\"
    start-stop-daemon --stop --quiet --pidfile \$PIDFILE --retry 5
    log_end_msg \$?
    rm -f \$PIDFILE
}

status() {
    status_of_proc -p \$PIDFILE \"\$NAME\" \"\$NAME\" && exit 0 || exit \$?
}

case \"\$1\" in
    start|stop|restart|status)
        \$1
        ;;
    *)
        echo \"Uso: \$0 {start|stop|restart|status}\"
        exit 1
        ;;
esac
exit 0
"

    echo "$script_content" | sudo tee "$service_script_path" > /dev/null
    sudo chmod +x "$service_script_path"
    sudo update-rc.d "$service_name" defaults

    dialog --msgbox "Serviço '$service_name' criado e habilitado.\nPara iniciar agora, execute: sudo service $service_name start" 10 60
}

# --- Funções Específicas para cada Serviço ---
configure_main_server() {
    local gunicorn_exec
    gunicorn_exec=$(sudo which gunicorn)
    if [[ -z "$gunicorn_exec" ]]; then
        dialog --msgbox "Gunicorn não encontrado. Instale as dependências primeiro." 6 50
        return
    fi
    local cmd="$gunicorn_exec --workers 3 --bind 0.0.0.0:5000 run:app"
    create_sysvinit_service "reposerver" "Servidor principal da aplicação" "$cmd" "$USER_NAME" "/var/run/reposerver.pid"
}

configure_dashboard() {
    local gunicorn_exec
    gunicorn_exec=$(sudo which gunicorn)
    if [[ -z "$gunicorn_exec" ]]; then
        dialog --msgbox "Gunicorn não encontrado. Instale as dependências primeiro." 6 50
        return
    fi
    local cmd="$gunicorn_exec --workers 1 --bind 0.0.0.0:5001 dashboard:app"
    create_sysvinit_service "dashboard" "Painel de controle web" "$cmd" "$USER_NAME" "/var/run/dashboard.pid"
}

configure_supervisor() {
    local python_exec
    python_exec=$(sudo which python3)
    local supervisor_script="$PROJECT_DIR/supervisor.py"
    local cmd="$python_exec $supervisor_script"
    # Supervisor precisa rodar como root para poder gerenciar outros serviços
    create_sysvinit_service "supervisor" "Supervisor inteligente de serviços" "$cmd" "root" "/var/run/supervisor.pid"
}

show_status() {
    services=$(ls /etc/init.d | grep -E '(reposerver|dashboard|supervisor)')
    if [ -z "$services" ]; then
        dialog --msgbox "Nenhum serviço relevante foi configurado ainda." 6 50
        return
    fi
    
    status_text=""
    for s in $services; do
        status_output=$(sudo service "$s" status 2>&1)
        status_text="$status_text\nServiço: $s\nStatus: $status_output\n---------------------"
    done

    dialog --title "Status dos Serviços" --msgbox "$status_text" 20 75
}

# --- Telas da Interface ---
show_welcome_screen() {
    get_system_info
    dialog --title "Assistente de Instalação" --msgbox "Bem-vindo ao assistente de configuração para o seu servidor no Antix.\n\n- Hostname: $HOSTNAME\n- Usuário: $USER_NAME\n- Data/Hora: $CURRENT_DATETIME" 12 75
}

show_main_menu() {
    dialog --title "Menu Principal" --cancel-label "Sair" --menu "Escolha uma opção:" 18 70 6 \
           1 "Instalar Dependências do Sistema" \
           2 "Criar/Habilitar Serviço: Servidor Principal" \
           3 "Criar/Habilitar Serviço: Painel de Controle" \
           4 "Criar/Habilitar Serviço: Supervisor" \
           5 "Verificar Status de Todos os Serviços" \
           6 "Sair do Assistente" 2> /tmp/menu_choice
    return $?
}

# --- Lógica Principal ---
show_welcome_screen

while true; do
    show_main_menu
    exit_status=$?
    choice=$(cat /tmp/menu_choice)

    if [ $exit_status -ne 0 ]; then
      choice=6 # Trata ESC e Cancelar como Sair
    fi
    
    clear
    case $choice in
        1) install_dependencies ;; 
        2) configure_main_server ;; 
        3) configure_dashboard ;; 
        4) configure_supervisor ;; 
        5) show_status ;; 
        6) 
            rm -f /tmp/menu_choice
            echo "Assistente finalizado."
            break
            ;;
    esac
done
