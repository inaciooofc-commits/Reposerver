import os
import time
import eventlet

# Garante a compatibilidade com WebSocket
eventlet.monkey_patch()

from flask import Flask, render_template
from flask_socketio import SocketIO
from flask_cors import CORS
from config import Config, config_by_name

# Inicializa as extensões
socketio = SocketIO(
    async_mode=Config.SOCKETIO_ASYNC_MODE, 
    message_queue=Config.SOCKETIO_MESSAGE_QUEUE,
    cors_allowed_origins="*" # TODO: Restringir em produção
)

def create_app(config_name='prod'):
    """Application factory: cria e configura a aplicação Flask."""
    app = Flask(__name__, template_folder='app/templates', static_folder='app/static')
    app.config.from_object(config_by_name[config_name])
    
    # Habilita CORS para todos os domínios (deve ser mais restrito em produção)
    CORS(app)

    # Inicializa o SocketIO com a aplicação
    socketio.init_app(app)

    # --- Registro dos Blueprints (módulos da aplicação) ---
    from app.modules.antix_panel.routes import antix_panel_bp
    app.register_blueprint(antix_panel_bp, url_prefix='/')

    # --- [NOVO] Registro do Blueprint para endpoints personalizados ---
    from app.modules.custom_endpoints.routes import custom_endpoints_bp
    app.register_blueprint(custom_endpoints_bp)
    # --------------------------------------------------------

    # A rota principal agora é gerenciada pelo 'antix_panel_bp'
    # não sendo mais necessária uma rota de índice aqui.

    return app

# Obtém o nome da configuração do ambiente ou usa 'prod' como padrão
config_name = os.getenv('FLASK_ENV', 'prod')
app = create_app(config_name)

# Importa os handlers do WebSocket para registrá-los
from app.modules.antix_panel.websocket import handlers

if __name__ == '__main__':
    # Cria o arquivo PID para o supervisor
    with open(f"/var/run/{Config.APP_NAME}.pid", "w") as f:
        f.write(str(os.getpid()))
    
    print(f"Iniciando {Config.APP_NAME} v{Config.APP_VERSION} na porta 5000...")
    socketio.run(app, host='0.0.0.0', port=5000)
