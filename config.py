import os
import json
import warnings

# Define the path to the config file and the default values
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(BASE_DIR, 'config.json')

DEFAULT_CONFIG = {
    'background_music': 'https://cdn.pixabay.com/download/audio/2021/10/19/audio_4a93807111.mp3?filename=anime-ambience-9832.mp3',
    'panel_title': 'Anime Pulse Server',
    'secret_key': 'reposerver_anime_secret_2026', # Default, should be overridden
    'theme_accent': '#7c4dff',
    'theme_second': '#ff6cd7',
    'theme_bg': '#090b1f',
    'google_client_id': '',
    'google_client_secret': '',
    'google_redirect_uri': '',
    'enable_google_login': False,
    'auto_update_on_start': False,
    'youtube_api_key': '',
    'background_image': '',
    'cloudflare_api_token': '',
    'cloudflare_zone_id': '',
}

# Mapping between config keys and environment variables
SECRET_KEYS_MAP = {
    'secret_key': 'SECRET_KEY',
    'google_client_id': 'GOOGLE_CLIENT_ID',
    'google_client_secret': 'GOOGLE_CLIENT_SECRET',
    'youtube_api_key': 'YOUTUBE_API_KEY',
    'cloudflare_api_token': 'CLOUDFLARE_API_TOKEN',
    'cloudflare_zone_id': 'CLOUDFLARE_ZONE_ID',
}

def _load_base_config():
    """Loads the base configuration from config.json, creating it if it doesn't exist."""
    if not os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(DEFAULT_CONFIG, f, indent=2, ensure_ascii=False)
        return DEFAULT_CONFIG
    try:
        with open(CONFIG_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        # In case of a corrupted file, rewrite with defaults
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(DEFAULT_CONFIG, f, indent=2, ensure_ascii=False)
        return DEFAULT_CONFIG

def load_config():
    """
    Loads configuration with a secure-first approach.
    1. Loads the base config from config.json.
    2. Overrides any sensitive keys with values from environment variables.
    3. Issues a warning if a secret is found in the JSON file but not in the environment.
    """
    config = _load_base_config()

    # Ensure all default keys exist in the loaded config
    config_updated = False
    for key, value in DEFAULT_CONFIG.items():
        if key not in config:
            config[key] = value
            config_updated = True
    if config_updated:
        with open(CONFIG_FILE, 'w', encoding='utf-8') as f:
            json.dump(config, f, indent=2, ensure_ascii=False)


    for key, env_var in SECRET_KEYS_MAP.items():
        env_value = os.environ.get(env_var)
        if env_value:
            # Environment variable takes precedence
            config[key] = env_value
        elif config.get(key) and config.get(key) != DEFAULT_CONFIG.get(key):
            # If the value in the file is not the default, it's a user-set secret.
            # This is a security risk.
            warnings.warn(
                f"Security Warning: Secret '{key}' is being loaded from 'config.json'. "
                f"For better security, please set it as an environment variable: '{env_var}'.",
                UserWarning
            )

    return config

# Load the configuration once to be used by other modules
AppConfig = load_config()
