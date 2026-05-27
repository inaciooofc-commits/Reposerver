import os
import eventlet

# Monkey patch for WebSocket compatibility
eventlet.monkey_patch()

from flask import Flask, render_template
from flask_socketio import SocketIO
from flask_cors import CORS
from config import config, Config, config_by_name

# Initialize extensions
socketio = SocketIO(
    async_mode=Config.SOCKETIO_ASYNC_MODE, 
    message_queue=Config.SOCKETIO_MESSAGE_QUEUE,
    cors_allowed_origins="*" # Restrict in production
)

def create_app(config_name='prod'):
    """Application factory."""
    app = Flask(__name__, template_folder='app/templates', static_folder='app/static')
    app.config.from_object(config_by_name[config_name])
    
    # Enable CORS for all domains, you might want to restrict this in production
    CORS(app)

    # Initialize SocketIO with the app
    socketio.init_app(app)

    # Register Blueprints
    from app.modules.antix_panel.routes import antix_panel_bp
    app.register_blueprint(antix_panel_bp, url_prefix='/')
    
    # A simple route for now to confirm the app is running
    @app.route('/')
    def index():
        return render_template('index.html', app_name=Config.APP_NAME)

    return app

# Get config name from environment or default to production
config_name = os.getenv('FLASK_ENV', 'prod')
app = create_app(config_name)

# Import the websocket handlers to register them
from app.modules.antix_panel.websocket import handlers

if __name__ == '__main__':
    print(f"Starting {Config.APP_NAME} v{Config.APP_VERSION} on port 5000...")
    socketio.run(app, host='0.0.0.0', port=5000)
