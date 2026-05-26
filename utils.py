# utils.py

import json
import os
import subprocess
import threading
from datetime import datetime
from flask import current_app

# Import the centralized configuration
from config import AppConfig

# --- Constants ---
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_FILE = os.path.join(BASE_DIR, 'users.json')
PAYMENTS_FILE = os.path.join(BASE_DIR, 'payments.json')
IP_LOG_FILE = os.path.join(BASE_DIR, 'ip_log.json')
STATUS_FILE = os.path.join(BASE_DIR, 'status.json')
LOG_FILE = os.path.join(BASE_DIR, 'server.log')
CENTRAL_LOG = os.path.join(BASE_DIR, 'central.log')
CONFIG_FILE = os.path.join(BASE_DIR, 'config.json')

DEFAULT_STATUS = {
    'current': None,
    'queue': [],
    'active_users': [],
    'last_update': None,
}

# --- Core Utility Functions ---

def write_json(path, payload):
    """Writes a Python object to a JSON file."""
    with open(path, 'w', encoding='utf-8') as handle:
        json.dump(payload, handle, indent=2, ensure_ascii=False)

def load_json(path, default=None):
    """Loads a JSON file, returning a default if it fails or doesn't exist."""
    if not os.path.exists(path):
        if default is not None:
            write_json(path, default)
        return default
    try:
        with open(path, 'r', encoding='utf-8') as handle:
            return json.load(handle)
    except (json.JSONDecodeError, IOError):
        if default is not None:
            write_json(path, default)
        return default

def ensure_initial_files():
    """Ensures that all necessary data files exist on startup."""
    load_json(DATA_FILE, {})
    load_json(PAYMENTS_FILE, [])
    load_json(IP_LOG_FILE, [])
    load_json(STATUS_FILE, DEFAULT_STATUS)
    if not os.path.exists(LOG_FILE):
        open(LOG_FILE, 'a', encoding='utf-8').close()

def write_log(message):
    """Writes a message to the server log file."""
    timestamp = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{timestamp}] {message}'
    with open(LOG_FILE, 'a', encoding='utf-8') as handle:
        handle.write(line + '\n')

def write_central(message):
    """Writes a message to the central log file."""
    ts = datetime.utcnow().isoformat()
    with open(CENTRAL_LOG, 'a', encoding='utf-8') as f:
        f.write(f'[{ts}] {message}\n')

def record_ip(username, ip):
    """Records a user's IP address on login."""
    ip_log = load_json(IP_LOG_FILE, [])
    ip_log.append({'time': datetime.utcnow().isoformat(), 'user': username, 'ip': ip})
    write_json(IP_LOG_FILE, ip_log)

def pull_from_git():
    """Pulls the latest code from the Git repository."""
    try:
        result = subprocess.run(
            ['git', 'pull'],
            cwd=BASE_DIR,
            capture_output=True,
            text=True,
            check=False,
        )
        output = result.stdout.strip() or result.stderr.strip()
        write_log(f'Git pull executed: returncode={result.returncode} output={output}')
        return result.returncode == 0, output
    except Exception as exc:
        write_log(f'Falha ao atualizar do Git: {exc}')
        return False, str(exc)

def purge_cloudflare_cache(files=None):
    """Purges specified files from the Cloudflare cache."""
    token = AppConfig.get('cloudflare_api_token')
    zone = AppConfig.get('cloudflare_zone_id')
    
    if not token or not zone or not files:
        return False, 'Cloudflare não configurado ou nenhum arquivo fornecido.'
    
    try:
        import urllib.request
        url = f'https://api.cloudflare.com/client/v4/zones/{zone}/purge_cache'
        data = json.dumps({'files': files}).encode('utf-8')
        req = urllib.request.Request(url, data=data, method='POST')
        req.add_header('Content-Type', 'application/json')
        req.add_header('Authorization', f'Bearer {token}')
        
        with urllib.request.urlopen(req, timeout=8) as resp:
            resp_data = resp.read().decode('utf-8')
            js_resp = json.loads(resp_data)
            success = js_resp.get('success', False)
            return success, js_resp
            
    except Exception as exc:
        return False, str(exc)

# --- User and Payment Data Functions ---

def load_users():
    """Loads the user data from users.json."""
    return load_json(DATA_FILE, {})

def save_users(users):
    """Saves the user data to users.json."""
    write_json(DATA_FILE, users)

def add_active_user(username):
    """Adds a user to the active user list in the status."""
    status = load_json(STATUS_FILE, DEFAULT_STATUS)
    if username not in status['active_users']:
        status['active_users'].append(username)
    save_status()


def remove_active_user(username):
    """Removes a user from the active user list."""
    status = load_json(STATUS_FILE, DEFAULT_STATUS)
    if username in status['active_users']:
        status['active_users'].remove(username)
    save_status()

def create_google_user(user_info):
    """Creates a new user from Google OAuth info if they don't already exist."""
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

def load_payments():
    """Loads the payment data from payments.json."""
    return load_json(PAYMENTS_FILE, [])

def save_payments(payments):
    """Saves the payment data to payments.json."""
    write_json(PAYMENTS_FILE, payments)

# --- Music Playback and Queue Management ---

def save_status():
    """Saves the current playback status and queue to status.json."""
    status = {
        'current': getattr(current_app, 'current_track', None),
        'queue': getattr(current_app, 'queue', []),
        'active_users': load_json(STATUS_FILE, DEFAULT_STATUS).get('active_users', []),
        'last_update': datetime.utcnow().isoformat(),
    }
    write_json(STATUS_FILE, status)

def enqueue_track(url, requestor):
    """Adds a track to the global queue."""
    if 'youtube.com' not in url and 'youtu.be' not in url:
        return False
    
    current_app.queue.append({'url': url, 'requestor': requestor})
    save_status()
    return True

def start_playback_if_needed():
    """Checks if the playback thread is running and starts it if necessary."""
    if not (current_app.playback_thread and current_app.playback_thread.is_alive()) and current_app.queue:
        write_log("Starting playback thread.")
        current_app.playback_thread = threading.Thread(target=current_app.playback_worker, daemon=True)
        current_app.playback_thread.start()
