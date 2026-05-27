#!/bin/bash
# ==============================================================================
# ||                 Reposerver Doctor & Smart Installer                      ||
# ||          Diagnostica o ambiente e executa a instalação ideal.            ||
# ==============================================================================

# --- Configurações e Cores ---
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_NC='\033[0m' # No Color

LOG_FILE="/tmp/reposerver_doctor.log"

# Limpa o log a cada execução
> "$LOG_FILE"

echo_info() { echo -e "${C_BLUE}INFO:${C_NC} $1"; }
echo_success() { echo -e "${C_GREEN}SUCCESS:${C_NC} $1"; }
echo_warn() { echo -e "${C_YELLOW}WARN:${C_NC} $1"; }
echo_error() { echo -e "${C_RED}ERROR:${C_NC} $1"; }

# --- Funções de Diagnóstico ---

check_privileges() {
    echo_info "1. Verificando privilégios de execução..."
    if [ "$(id -u)" -eq 0 ]; then
        echo_success "Script está sendo executado como ROOT. Instalação completa do serviço será tentada."
        INSTALL_MODE="service"
    elif command -v sudo &> /dev/null; then
        echo_error "Este script precisa de privilégios de administrador para uma instalação completa."
        echo_info "Por favor, execute novamente usando: sudo bash $0"
        exit 1
    else
        echo_warn "Nem ROOT nem SUDO foram detectados."
        echo_info "A instalação prosseguirá em modo LOCAL (sem serviço de sistema).
"
        INSTALL_MODE="local"
    fi
}

check_dependencies() {
    echo_info "2. Verificando dependências..."
    DEPS="python3 python3-venv g++ make"
    MISSING_DEPS=""
    for dep in $DEPS; do
        if ! command -v $dep &> /dev/null; then
            MISSING_DEPS+="$dep "
        fi
    done

    if [ -n "$MISSING_DEPS" ]; then
        if [ "$INSTALL_MODE" == "service" ]; then
            echo_warn "Dependências faltando: $MISSING_DEPS. Tentando instalar..."
            apt-get update -y >> "$LOG_FILE" 2>&1
            apt-get install -y $MISSING_DEPS >> "$LOG_FILE" 2>&1
            echo_success "Dependências instaladas."
        else
            echo_error "Dependências cruciais faltando: $MISSING_DEPS"
            echo_info "Por favor, peça a um administrador para instalar: apt-get install $MISSING_DEPS"
            exit 1
        fi
    else
        echo_success "Todas as dependências necessárias estão presentes."
    fi
}

# --- Funções de Instalação ---

fix_service_script() {
    if [ -f "reposerver_service_script" ]; then
        # Garante que o script usa finais de linha Unix (LF) e não Windows (CRLF)
        sed -i 's/\r$//' reposerver_service_script
        # Garante que o shebang está correto para sistemas baseados em Debian/Antix
        sed -i '1s|.*|#!/bin/sh|' reposerver_service_script
        chmod +x reposerver_service_script
        echo_success "Script de serviço 'reposerver_service_script' foi limpo e preparado."
    fi
}

install_service() {
    echo_info "--- Iniciando Instalação como Serviço de Sistema ---"
    
    fix_service_script
    
    echo_info "Executando o instalador final... (Veja /tmp/reposerver_install_final.log para detalhes)"
    bash install_antix_final.sh
    
    # Verificação Pós-Instalação
    if service reposerver status &>/dev/null; then
        echo_success "O serviço Reposerver foi instalado e está em execução!"
    else
        echo_error "A instalação terminou, mas o serviço não iniciou."
        echo_info "Analisando a falha..."
        if [ -f "/tmp/reposerver_debug.log" ]; then
            echo_warn "!!! Log de depuração do serviço encontrado. Isso é bom! Aqui está o conteúdo:"
            echo -e "${C_YELLOW}"
            cat /tmp/reposerver_debug.log
            echo -e "${C_NC}"
            echo_error "ANÁLISE: O script de serviço executou mas falhou. O log acima mostra o erro exato."
        else
            echo_error "ANÁLISE: O serviço falhou ANTES de executar. Isso quase sempre indica um problema de permissão ou de formato do script de serviço que a limpeza automática não resolveu."
            echo_info "Solução: Verifique se o arquivo /etc/init.d/reposerver tem permissões de execução e pertence ao root."
        fi
    fi
}

install_local() {
    echo_info "--- Iniciando Instalação Local ---"
    
    echo_info "Executando instalador local... (Veja /tmp/reposerver_install_local.log para detalhes)"
    bash install_local.sh >> "$LOG_FILE" 2>&1
    
    if [ -d ".venv_local" ]; then
        echo_success "Ambiente local preparado com sucesso."
        echo_info "Para iniciar sua aplicação, execute o seguinte comando:"
        echo -e "${C_GREEN}bash run_local.sh${C_NC}"
        echo_warn "Lembre-se: a aplicação irá parar quando você fechar o terminal."
    else
        echo_error "A preparação do ambiente local falhou."
        echo_info "Verifique o log em /tmp/reposerver_install_local.log para a causa do erro."
    fi
}

# --- Ponto de Entrada do Script ---
echo "======================================================"
echo "||         Reposerver Doctor & Smart Installer      ||"
echo "======================================================"

check_privileges
check_dependencies

if [ "$INSTALL_MODE" == "service" ]; then
    install_service
else
    install_local
fi

echo_info "Diagnóstico concluído."
