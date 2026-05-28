from app import create_app
from flask_socketio import SocketIO

app = create_app()
socketio = SocketIO(app, async_mode='threading') # Usando threading para compatibilidade

# Importa os handlers de socket para registrá-los.
# A importação deve ocorrer depois da inicialização do `socketio`.
from app.modules.dashboard import sockets

if __name__ == '__main__':
    # Este bloco é para desenvolvimento local.
    # Em produção, um servidor WSGI como Gunicorn será usado.
    socketio.run(app, debug=True, host='0.0.0.0', port=5000)
