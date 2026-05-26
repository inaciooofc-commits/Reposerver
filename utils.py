import json
import os
import subprocess
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_FILE = os.path.join(BASE_DIR, 'users.json')
CONFIG_FILE = os.path.join(BASE_DIR, 'config.json')
PAYMENTS_FILE = os.path.join(BASE_DIR, 'payments.json')
IP_LOG_FILE = os.path.join(BASE_DIR, 'ip_log.json')
STATUS_FILE = os.path.join(BASE_DIR, 'status.json')
LOG_FILE = os.path.join(BASE_DIR, 'server.log')
CENTRAL_LOG = os.path.join(BASE_DIR, 'central.log')

DEFAULT_CONFIG = {
    'background_music': 'https://cdn.pixabay.com/download/audio/2021/10/19/audio_4a93807111.mp3?filename=anime-ambience-9832.mp3',
    'panel_title': 'Anime Pulse Server',
    'secret_key': 'reposerver_anime_secret_2026',
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

def write_json(path, payload):
    with open(path, 'w', encoding='utf-8') as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)

def load_json(path, default):
    if not os.path.exists(path):
        write_json(path, default)
        return default
    try:
        with open(path, 'r', encoding='utf-8') as handle:
            return json.load(handle)
    except (json.JSONDecodeError, IOError):
        write_json(path, default)
        return default

def ensure_files():
    config = load_json(CONFIG_FILE, DEFAULT_CONFIG)
    config_updated = False
    for key, value in DEFAULT_CONFIG.items():
        if key not in config:
            config[key] = value
            config_updated = True
    if config_updated:
        write_json(CONFIG_FILE, config)

    load_json(DATA_FILE, {})
    load_json(PAYMENTS_FILE, [])
    load_json(IP_LOG_FILE, [])
    load_json(STATUS_FILE, {})
    if not os.path.exists(LOG_FILE):
        open(LOG_FILE, 'a', encoding='utf-8').close()

def write_log(message):
    timestamp = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{timestamp}] {message}'
    with open(LOG_FILE, 'a', encoding='utf-8') as handle:
        handle.write(line + '\n')

def write_central(message):
    ts = datetime.utcnow().isoformat()
    with open(CENTRAL_LOG, 'a', encoding='f-8') as f:
        f.write(f'[{ts}] {message}\n')

def record_ip(username, ip):
    ip_log = load_json(IP_LOG_FILE, [])
    ip_log.append({'time': datetime.utcnow().isoformat(), 'user': username, 'ip': ip})
    write_json(IP_LOG_FILE, ip_log)

def pull_from_git():
    try:
        result = subprocess.run(
            ['git', 'pull'],
            cwd=BASE_DIR,
            capture_output=True,
            text=True,
            check=False,
        )
        output = result.stdout.strip() or result.stderr.strip()
        write_log(f'Git pull executado: returncode={result.returncode} output={output}')
        return result.returncode == 0, output
    except Exception as exc:
        write_log(f'Falha ao atualizar do Git: {exc}')
        return False, str(exc)

def purge_cloudflare_cache(files=None):
    config = load_json(CONFIG_FILE, DEFAULT_CONFIG)
    token = config.get('cloudflare_api_token')
    zone = config.get('cloudflare_zone_id')
    if not token or not zone or not files:
        return False, 'Cloudflare não configurado ou nenhum arquivo fornecido.'
    try:
        import urllib.request as _urlreq
        import json as _json
        url = f'https://api.cloudflare.com/client/v4/zones/{zone}/purge_cache'
        data = _json.dumps({'files': files}).encode('utf-8')
        req = _urlreq.Request(url, data=data, method='POST')
        req.add_header('Content-Type', 'application/json')
        req.add_header('Authorization', f'Bearer {token}')
        with _urlreq.urlopen(req, timeout=8) as resp:
            resp_data = resp.read().decode('utf-8')
            js = _json.loads(resp_data)
            success = js.get('success', False)
            return success, js
    except Exception as exc:
        return False, str(exc)

def create_google_user(user_info):
    users = load_users()
    email = user_info.get('email')
    if not email:
        return None
    username = email.split('@')[0]
    if username in users:
        return username
    users[username] = {
        'password': '',
        'role': 'user',
        'credits': 10,
        'banned': False,
        'email': email,
    }
    save_users(users)
    write_log(f'Usuário Google criado: {username}')
    return username

def load_users():
    return load_json(DATA_FILE, {})

def save_users(users):
    write_json(DATA_FILE, users)

def load_payments():
    return load_json(PAYMENTS_FILE, [])

def save_payments(payments):
    write_json(PAYMENTS_FILE, payments)