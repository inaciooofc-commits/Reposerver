#!/bin/bash

# ==============================================================================
# ||         Script de Instalação e Configuração para o RepoServer          ||
# ==============================================================================

# --- Configurações ---
APP_NAME="reposerver"
PROJECT_DIR="/opt/reposerver"
SERVICE_USER="root" # O usuário que rodará o serviço. Root é necessário para a porta < 1024 e acesso geral.
PYTHON_ALIAS="python3"

# --- Cores para Saída ---
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[0;33m'
C_BLUE='\033[0;34m'
C_NC='\033[0m' # No Color

# --- Funções Auxiliares ---
info() { echo -e "${C_BLUE}[INFO]${C_NC} $1"; }
success() { echo -e "${C_GREEN}[SUCESSO]${C_NC} $1"; }
warning() { echo -e "${C_YELLOW}[AVISO]${C_NC} $1"; }
error() { echo -e "${C_RED}[ERRO]${C_NC} $1"; exit 1; }

# --- Início do Script ---
info "Iniciando a instalação do $APP_NAME..."

# 1. Verificação de Root
if [ "$(id -u)" -ne 0 ]; then
    error "Este script precisa ser executado como root. Por favor, use 'sudo bash install.sh'."
fi

# 2. Instalação de Dependências do Sistema (Debian/Ubuntu)
info "Instalando dependências do sistema (python3, pip, venv)..."
apt-get update > /dev/null
apt-get install -y $PYTHON_ALIAS python3-pip python3-venv > /dev/null || error "Falha ao instalar pacotes base."

# 3. Preparando o Diretório da Aplicação
info "Configurando o diretório do projeto em $PROJECT_DIR..."
# Para o caso de uma reinstalação, para o serviço primeiro
if systemctl is-active --quiet "$APP_NAME.service"; then
    info "Serviço existente encontrado. Parando antes da atualização..."
    systemctl stop "$APP_NAME.service"
fi

mkdir -p $PROJECT_DIR
# Copia todos os arquivos da aplicação para o diretório de destino
# O rsync é melhor que o cp para isso
info "Copiando arquivos da aplicação para $PROJECT_DIR..."
rsync -a --exclude='install.sh' --exclude='.git/' . "$PROJECT_DIR/"

cd $PROJECT_DIR || error "Não foi possível entrar no diretório $PROJECT_DIR."

# 4. Configuração do Ambiente Virtual Python
info "Criando e ativando ambiente virtual (venv)..."
$PYTHON_ALIAS -m venv venv || error "Falha ao criar o ambiente virtual."
source venv/bin/activate || error "Falha ao ativar o ambiente virtual."

# 5. Instalação das Dependências Python
info "Instalando dependências Python a partir do requirements.txt..."
pip install --upgrade pip > /dev/null
pip install -r requirements.txt || error "Falha ao instalar dependências do Python."

# Desativa o venv. O serviço o ativará conforme necessário.
deactivate

# 6. Configuração do Serviço systemd
info "Configurando o serviço systemd: $APP_NAME.service..."
SERVICE_FILE="/etc/systemd/system/$APP_NAME.service"

# Usamos um heredoc para escrever o arquivo de serviço.
# Isso é mais limpo e seguro que múltiplos 'echo'.
cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Servidor de Repositório e Painel de Controle
After=network.target

[Service]
User=$SERVICE_USER
Group=www-data
WorkingDirectory=$PROJECT_DIR

# O comando de execução agora aponta para o nosso script start.sh
# Ele já contém a lógica para encontrar o venv e executar gunicorn
ExecStart=$PROJECT_DIR/start.sh

# Configurações de reinicialização
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 7. Permissões e Finalização
info "Ajustando permissões..."
chmod +x "$PROJECT_DIR/start.sh"
chown -R $SERVICE_USER:www-data $PROJECT_DIR

info "Recarregando o daemon do systemd..."
systemctl daemon-reload

info "Habilitando o serviço $APP_NAME para iniciar no boot..."
systemctl enable $APP_NAME.service

info "Iniciando o serviço $APP_NAME agora..."
systemctl start $APP_NAME.service

# 8. Verificação de Status
info "Verificando o status do serviço..."
sleep 3 # Dá um tempo para o serviço iniciar
if systemctl is-active --quiet "$APP_NAME.service"; then
    success "Instalação concluída! O serviço '$APP_NAME' está ativo e rodando."
    echo "----------------------------------------------------------------------"
    systemctl status "$APP_NAME.service" --no-pager
    echo "----------------------------------------------------------------------"
    success "Acesse o painel no seu navegador (geralmente http://<IP_DO_SERVIDOR>:5000)"
else
    error "O serviço '$APP_NAME' falhou ao iniciar. Use 'journalctl -u $APP_NAME' para investigar."
fi
