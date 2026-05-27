import os
from dotenv import load_dotenv

load_dotenv()

class Config:
    # Core Flask Config
    SECRET_KEY = os.environ.get('SECRET_KEY', 'uma-chave-secreta-incrivelmente-dificil-de-adivinhar')
    DEBUG = os.environ.get('FLASK_DEBUG', 'False').lower() in ('true', '1', 't')

    # Application Config
    APP_NAME = "Anti X Panel"
    APP_VERSION = "1.0.0-beta"

    # Redis Configuration
    REDIS_URL = os.environ.get('REDIS_URL', "redis://localhost:6379/0")
    REDIS_PUBSUB_CHANNEL = "antix-realtime"

    # WebSocket (SocketIO)
    SOCKETIO_MESSAGE_QUEUE = REDIS_URL
    SOCKETIO_ASYNC_MODE = 'eventlet'

    # Terminal Config
    TERMINAL_HISTORY_SIZE = 1000
    TERMINAL_COMMAND_BLACKLIST = ['rm -rf', 'reboot', 'shutdown'] # Example

    # Security Config
    RATE_LIMIT_ENABLED = True
    ALLOWED_HOSTS = ['*'] # Be more specific in production

    # Admin Access Levels (Permissions to be defined elsewhere)
    ACCESS_LEVELS = {
        'moderator': 10,
        'admin': 20,
        'superadmin': 30,
        'root': 40
    }

    # Cloud Integrations (Placeholders)
    CLOUDFLARE_API_KEY = os.environ.get('CLOUDFLARE_API_KEY')
    CLOUDFLARE_EMAIL = os.environ.get('CLOUDFLARE_EMAIL')
    CLOUDFLARE_ZONE_ID = os.environ.get('CLOUDFLARE_ZONE_ID')
    AWS_ACCESS_KEY_ID = os.environ.get('AWS_ACCESS_KEY_ID')
    AWS_SECRET_ACCESS_KEY = os.environ.get('AWS_SECRET_ACCESS_KEY')
    AWS_S3_BUCKET_NAME = os.environ.get('AWS_S3_BUCKET_NAME')

    # Logging
    LOG_LEVEL = os.environ.get('LOG_LEVEL', 'INFO')
    LOG_TO_FILE = True
    LOG_FILE_PATH = 'logs/antix_panel.log'
    LOG_ROTATION_SIZE = 10 * 1024 * 1024 # 10MB
    LOG_BACKUP_COUNT = 5

class DevelopmentConfig(Config):
    DEBUG = True

class ProductionConfig(Config):
    DEBUG = False
    # Add production specific configs here, e.g., different database URI, etc.

# Expose the correct config class
config_by_name = dict(
    dev=DevelopmentConfig,
    prod=ProductionConfig
)

key = os.environ.get("FLASK_ENV", "prod")
config = config_by_name[key]
