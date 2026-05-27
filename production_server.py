
import sys
import os

# --- Injeção do Ambiente Virtual ---
# Esta é a lógica crucial. Ela permite que este script encontre as dependências
# (como o Flask) que estão instaladas dentro do ambiente virtual do projeto,
# sem a necessidade de "ativar" o venv da maneira tradicional.

VENV_DIR = ".venv_local"
# Construímos dinamicamente o caminho para o diretório site-packages.
PY_VERSION = f"python{sys.version_info.major}.{sys.version_info.minor}"
SITE_PACKAGES = os.path.abspath(os.path.join(VENV_DIR, "lib", PY_VERSION, "site-packages"))

# Inserimos o caminho no início do sys.path para garantir que ele tenha prioridade.
if os.path.isdir(SITE_PACKAGES):
    sys.path.insert(0, SITE_PACKAGES)
else:
    # Se não encontrarmos, é um erro fatal. Não adianta continuar.
    print(f"ERRO CRÍTICO: Não foi possível encontrar o diretório site-packages em \n{SITE_PACKAGES}")
    print("Execute o script de instalação local para criar o ambiente virtual.")
    sys.exit(1)

# --- Lógica do Servidor (como antes) ---
from wsgiref.simple_server import make_server
from reposerver_main import app

# Esta é a forma correta de servir uma aplicação WSGI em produção sem dependências externas.
# Usamos o servidor WSGI da biblioteca padrão do Python.

if __name__ == '__main__':
    # O Gunicorn não está disponível, então usamos o wsgiref como uma alternativa robusta.
    # Ele é mais estável para produção do que o servidor de desenvolvimento do Flask.
    with make_server('0.0.0.0', 8080, app) as httpd:
        print(f"Servidor iniciado com sucesso em http://0.0.0.0:8080/ usando o motor wsgiref.")
        print("Pressione Ctrl+C para parar o servidor.")
        httpd.serve_forever()
