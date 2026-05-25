import json
import os
import subprocess
import threading
import time
from datetime import datetime
from uuid import uuid4

from flask import (
    Flask,
    flash,
    get_flashed_messages,
    redirect,
    render_template_string,
    request,
    session,
    url_for,
)
from authlib.integrations.flask_client import OAuth
from yt_dlp import YoutubeDL

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATA_FILE = os.path.join(BASE_DIR, 'users.json')
CONFIG_FILE = os.path.join(BASE_DIR, 'config.json')
PAYMENTS_FILE = os.path.join(BASE_DIR, 'payments.json')
IP_LOG_FILE = os.path.join(BASE_DIR, 'ip_log.json')
STATUS_FILE = os.path.join(BASE_DIR, 'status.json')
LOG_FILE = os.path.join(BASE_DIR, 'server.log')

app = Flask(__name__)
app.config['SESSION_COOKIE_HTTPONLY'] = True

status_lock = threading.Lock()
playback_thread = None
player_process = None

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

DEFAULT_STATUS = {
    'current': None,
    'queue': [],
    'active_users': [],
    'recent_events': [],
    'last_update': None,
    'monitor_message': 'Ready for anime streaming',
}

LOGIN_TEMPLATE = '''<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Login Anime Server</title>
  <style>
    body { margin:0; min-height:100vh; display:flex; align-items:center; justify-content:center; background: radial-gradient(circle at top, #4c1d95, #090b1f 45%); color:#edf2f7; font-family: Inter, sans-serif; }
    .card { width:min(420px,96vw); background:rgba(15,23,42,0.92); border:1px solid rgba(255,255,255,0.08); border-radius:24px; box-shadow:0 40px 120px rgba(0,0,0,0.35); padding:32px; backdrop-filter:blur(12px); }
    h1 { margin-top:0; letter-spacing:0.06em; }
    label { display:block; margin:18px 0 6px; color:#cbd5e1; }
    input { width:100%; padding:14px 16px; border-radius:14px; border:1px solid rgba(148,163,184,0.18); background:#0f172a; color:#f8fafc; }
    button { width:100%; margin-top:20px; padding:14px; border:none; border-radius:14px; background:linear-gradient(135deg,#7c3aed,#ec4899); color:#fff; font-weight:700; cursor:pointer; transition:transform .22s ease; }
    button:hover { transform: translateY(-2px); }
    .info, .error { margin:0 0 14px; padding:12px 16px; border-radius:14px; }
    .error { background:rgba(248,113,113,0.18); color:#fecaca; }
    .info { background:rgba(56,189,248,0.18); color:#bfdbfe; }
    .anime-tag { margin-top:12px; color:#a78bfa; font-size:0.95rem; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Anime Pulse Login</h1>
    {% if error %}<div class="error">{{ error }}</div>{% endif %}
    {% for msg in messages %}<div class="info">{{ msg }}</div>{% endfor %}
    <form method="post">
      <label>Usuário</label>
      <input type="text" name="username" required autofocus>
      <label>Senha</label>
      <input type="password" name="password" required>
      <button type="submit">Entrar</button>
    </form>
    {% if google_enabled %}
      <a href="{{ url_for('google_login') }}" class="button" style="margin-top:10px; display:block; background: linear-gradient(135deg,#4285F4,#34A853);">Entrar com Google</a>
    {% endif %}
    <p class="anime-tag">Admin padrão: <strong>admin</strong> / <strong>admin123</strong></p>
  </div>
</body>
</html>'''

DASHBOARD_TEMPLATE = '''<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{{ title }} - Dashboard</title>
  <style>
    :root { --accent: {{ accent }}; --second: {{ second }}; --bg: {{ bg }}; }
    * { box-sizing:border-box; }
    body { margin:0; min-height:100vh; font-family: Inter, sans-serif; color:#edf2f7; background: radial-gradient(circle at top, rgba(124,58,237,0.28), transparent 28%), linear-gradient(180deg, #0c1226 0%, #070b18 100%); }
    .page { width:min(1180px,96vw); margin:24px auto; padding:0 12px; }
    header { display:flex; flex-wrap:wrap; align-items:center; justify-content:space-between; gap:16px; }
    h1 { margin:0; font-size:clamp(2rem,3vw,3rem); letter-spacing:0.04em; }
    .card { background:rgba(15,23,42,0.9); border:1px solid rgba(255,255,255,0.08); border-radius:32px; padding:28px; box-shadow:0 30px 80px rgba(0,0,0,0.28); backdrop-filter:blur(16px); }
    .grid { display:grid; grid-template-columns:1fr 1fr; gap:24px; margin-top:24px; }
    .full { grid-column:1/-1; }
    .button { display:inline-flex; align-items:center; justify-content:center; gap:10px; padding:14px 22px; border:none; border-radius:18px; background:linear-gradient(135deg, var(--accent), var(--second)); color:#fff; text-decoration:none; font-weight:700; transition:transform .2s ease, box-shadow .2s ease; }
    .button:hover { transform:translateY(-2px); box-shadow:0 18px 40px rgba(124,58,237,0.28); }
    .panel { position:relative; overflow:hidden; }
    .panel::before { content:''; position:absolute; inset:0; background:radial-gradient(circle at top left, rgba(124,58,237,0.14), transparent 30%); pointer-events:none; }
    .panel-content { position:relative; }
    .label { color:#cbd5e1; font-size:0.95rem; margin:14px 0 4px; }
    input, select, textarea { width:100%; padding:14px 16px; border-radius:16px; border:1px solid rgba(148,163,184,0.16); background:#0f172a; color:#f8fafc; outline:none; }
    button.primary { width:100%; margin-top:16px; }
    table { width:100%; border-collapse:collapse; margin-top:18px; }
    th, td { padding:14px 12px; border-bottom:1px solid rgba(148,163,184,0.1); text-align:left; }
    th { color:#94a3b8; font-size:0.95rem; }
    td { font-size:0.98rem; }
    .tag { display:inline-flex; gap:8px; align-items:center; padding:6px 12px; border-radius:999px; background:rgba(124,58,237,0.14); color:#c4b5fd; font-size:0.85rem; }
    .small-grid { display:grid; grid-template-columns:1fr 1fr; gap:18px; }
    .notice { margin:16px 0; padding:16px; border-radius:18px; background:rgba(15,23,42,0.7); border:1px dashed rgba(148,163,184,0.18); }
    .footer { margin-top:32px; display:flex; flex-wrap:wrap; gap:12px; align-items:center; justify-content:space-between; color:#94a3b8; }
    .animated-ring { position:absolute; inset:0; border-radius:inherit; box-shadow:0 0 90px rgba(124,58,237,0.24); animation:pulseRing 8s infinite; }
    @keyframes pulseRing { 0% { transform:scale(0.94); opacity:0.65; } 50% { transform:scale(1.04); opacity:0.25; } 100% { transform:scale(0.94); opacity:0.65; } }
    .pulse { animation:pulseGlow 2.4s infinite ease-in-out; }
    @keyframes pulseGlow { 0%,100% { box-shadow:0 0 28px rgba(124,58,237,0.18); } 50% { box-shadow:0 0 42px rgba(124,58,237,0.35); } }
  </style>
</head>
<body>
  <div class="page">
    <header>
      <div>
        <h1>{{ title }}</h1>
        <p style="color:#cbd5e1; max-width:760px;">Interface premium anime com controle de reprodução de música, painel de gerenciamento e monitor de servidor.</p>
      </div>
      <div style="display:flex; gap:14px; flex-wrap:wrap; align-items:center;">
          {% if role == 'admin' %}
            <a class="button" href="{{ url_for('admin') }}">Painel Admin</a>
          {% endif %}
        <a class="button" href="{{ url_for('monitor_web') }}">Monitor Web</a>
        <a class="button" href="{{ url_for('logout') }}">Sair</a>
      </div>
    </header>

    <div class="grid">
      <div class="card panel">
        <div class="animated-ring"></div>
        <div class="panel-content">
          <h2>Agora tocando</h2>
          {% if current %}
            <p class="tag">{{ current.status }}</p>
            <p><strong>{{ current.title }}</strong></p>
            <p>Solicitado por: <strong>{{ current.requestor }}</strong></p>
          {% else %}
            <p class="notice">Nenhuma música em reprodução. Envie um link do YouTube para começar.</p>
          {% endif %}
          <form method="post" action="{{ url_for('play') }}">
            <label class="label">Link do YouTube</label>
            <input type="text" name="youtube_url" placeholder="https://www.youtube.com/watch?v=..." required>
            <button type="submit" class="button primary">Tocar agora</button>
          </form>
        </div>
      </div>

      {% if background_image %}
      <div class="card full">
        <h3>Imagem de fundo</h3>
        <div style="height:160px; border-radius:12px; overflow:hidden; background-size:cover; background-position:center; background-image:url('{{ background_image }}');"></div>
      </div>
      {% endif %}

      <div class="card panel">
        <div class="panel-content">
          <h2>Fila de músicas</h2>
          {% if queue|length %}
            <table>
              <thead><tr><th>Título</th><th>Pedido por</th></tr></thead>
              <tbody>
                {% for item in queue %}
                  <tr><td>{{ item.title }}</td><td>{{ item.requestor }}</td></tr>
                {% endfor %}
              </tbody>
            </table>
          {% else %}
            <p class="notice">A fila está vazia. Adicione músicas ao enviar um link do YouTube.</p>
          {% endif %}
        </div>
      </div>

      <div class="card full">
        <div class="panel-content">
          <div class="small-grid">
            <div>
              <h3>Seu usuário</h3>
              <p><strong>{{ username }}</strong> • {{ role }}</p>
              <p class="label">Créditos: {{ credits }}</p>
            </div>
            <div>
              <h3>Status do sistema</h3>
              <p>Usuários ativos: <strong>{{ active_count }}</strong></p>
              <p>Última atualização: <strong>{{ last_update or '---' }}</strong></p>
            </div>
          </div>
          <div class="notice" style="margin-top:18px;">
            <p>Configuração de música de fundo: <strong>{{ background_music }}</strong></p>
            <audio controls autoplay loop style="width:100%; margin-top:12px; border-radius:16px;">
              <source src="{{ background_music }}" type="audio/mpeg">
              Seu navegador não suporta áudio HTML.
            </audio>
          </div>
        </div>
      </div>
    </div>

    <div class="footer">
      <span>IP gravado: {{ client_ip }}</span>
      <span>Servidor antiX • Reposerver anime</span>
    </div>
  </div>
</body>
</html>'''

ADMIN_TEMPLATE = '''<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Admin {{ title }}</title>
  <style>
    :root { --accent: {{ accent }}; --second: {{ second }}; --bg: {{ bg }}; }
    body { margin:0; min-height:100vh; font-family: Inter, sans-serif; color:#edf2f7; background: radial-gradient(circle at top right, rgba(248,113,113,0.18), transparent 26%), linear-gradient(180deg, #060814 0%, #090c1e 100%); }
    .page { width:min(1180px,96vw); margin:20px auto; padding:0 12px; }
    h1 { margin:0; font-size:2.6rem; }
    .header { display:flex; flex-wrap:wrap; justify-content:space-between; align-items:center; gap:14px; padding:24px 0; }
    .button { display:inline-flex; align-items:center; justify-content:center; gap:10px; padding:14px 22px; border:none; border-radius:18px; background:linear-gradient(135deg, var(--accent), var(--second)); color:#fff; text-decoration:none; cursor:pointer; }
    .card { background:rgba(15,23,42,0.92); border:1px solid rgba(255,255,255,0.08); border-radius:28px; padding:26px; box-shadow:0 26px 70px rgba(0,0,0,0.28); backdrop-filter:blur(18px); margin-bottom:24px; }
    label { display:block; margin-top:18px; color:#cbd5e1; }
    input, select { width:100%; padding:14px 16px; margin-top:8px; border-radius:16px; border:1px solid rgba(148,163,184,0.16); background:#0f172a; color:#f8fafc; }
    button.primary { width:100%; margin-top:18px; padding:14px; border:none; border-radius:18px; background:linear-gradient(135deg, #22c55e, #14b8a6); color:#fff; cursor:pointer; }
    table { width:100%; border-collapse:collapse; margin-top:18px; }
    th, td { padding:14px 12px; border-bottom:1px solid rgba(148,163,184,0.12); }
    th { color:#94a3b8; font-size:0.95rem; text-align:left; }
    td { color:#e2e8f0; }
    .error { background:rgba(248,113,113,0.16); color:#fecaca; padding:14px; border-radius:16px; }
    .success { background:rgba(34,197,94,0.16); color:#bbf7d0; padding:14px; border-radius:16px; }
    .grid { display:grid; grid-template-columns:1fr 1fr; gap:24px; }
    .small { display:grid; grid-template-columns:1fr 1fr; gap:16px; }
  </style>
</head>
<body>
  <div class="page">
    <div class="header">
      <div>
        <h1>Admin {{ title }}</h1>
        <p style="color:#cbd5e1;">Gerencie usuários, bans, créditos, pagamentos e a música de fundo.</p>
      </div>
      <div style="display:flex; gap:12px; flex-wrap:wrap;">
        <a class="button" href="{{ url_for('dashboard') }}">Voltar ao Dashboard</a>
        <form method="post" action="{{ url_for('git_update') }}" style="display:inline-block; margin:0;">
          <button type="submit" class="button" style="background:linear-gradient(135deg, #facc15, #f97316);">Atualizar do Git</button>
        </form>
        <a class="button" href="{{ url_for('logout') }}">Sair</a>
      </div>
    </div>

    {% if error %}<div class="card error">{{ error }}</div>{% endif %}
    {% for msg in messages %}<div class="card success">{{ msg }}</div>{% endfor %}

    <div class="grid">
      <div class="card">
        <h2>Criar novo usuário</h2>
        <form method="post" action="{{ url_for('admin_action') }}">
          <input type="hidden" name="action" value="create_user">
          <label>Usuário</label>
          <input type="text" name="new_username" required>
          <label>Senha</label>
          <input type="password" name="new_password" required>
          <label>Função</label>
          <select name="new_role">
            <option value="user">Usuário</option>
            <option value="admin">Administrador</option>
          </select>
          <button type="submit" class="primary">Criar usuário</button>
        </form>
      </div>

      <div class="card">
        <h2>Compra de créditos</h2>
        <form method="post" action="{{ url_for('buy_credits') }}">
          <label>Quantidade de créditos</label>
          <input type="number" name="amount" min="1" value="10" required>
          <button type="submit" class="primary">Adicionar créditos</button>
        </form>
        <div style="margin-top:18px;">
          <p>Pedidos de pagamento recentes: <strong>{{ payments|length }}</strong></p>
          <ul style="padding-left:18px; color:#cbd5e1;">
            {% for p in payments[-5:] %}
              <li>{{ p.timestamp }} • {{ p.user }} • {{ p.credits }} credits</li>
            {% endfor %}
          </ul>
        </div>
      </div>
    </div>

    <div class="card">
      <h2>Lista de usuários</h2>
      <table>
        <thead><tr><th>Usuário</th><th>Função</th><th>Créditos</th><th>Status</th><th>Ações</th></tr></thead>
        <tbody>
          {% for name, info in users.items() %}
            <tr>
              <td>{{ name }}</td>
              <td>{{ info.role }}</td>
              <td>{{ info.credits }}</td>
              <td>{{ 'Banido' if info.banned else 'Ativo' }}</td>
              <td>
                <form style="display:inline-block;" method="post" action="{{ url_for('admin_action') }}">
                  <input type="hidden" name="action" value="toggle_ban">
                  <input type="hidden" name="target_user" value="{{ name }}">
                  <button class="button" style="padding:8px 12px; background:rgba(124,58,237,0.18);">{{ 'Desbanir' if info.banned else 'Banir' }}</button>
                </form>
                <form style="display:inline-block;" method="post" action="{{ url_for('admin_action') }}">
                  <input type="hidden" name="action" value="grant_credits">
                  <input type="hidden" name="target_user" value="{{ name }}">
                  <input type="hidden" name="amount" value="10">
                  <button class="button" style="padding:8px 12px; background:rgba(34,197,94,0.18);">+10 créditos</button>
                </form>
              </td>
            </tr>
          {% endfor %}
        </tbody>
      </table>
    </div>

    <div class="card">
      <div class="small">
        <div>
          <h2>Configurações</h2>
          <form method="post" action="{{ url_for('admin_action') }}">
            <input type="hidden" name="action" value="update_config">
            <label>Música de fundo</label>
            <input type="text" name="background_music" value="{{ config.background_music }}" required>
            <label>Imagem de fundo (URL)</label>
            <input type="text" name="background_image" value="{{ config.background_image }}">
            <label>Título do painel</label>
            <input type="text" name="panel_title" value="{{ config.panel_title }}" required>
            <label>Habilitar login Google</label>
            <select name="enable_google_login">
              <option value="true" {% if config.enable_google_login %}selected{% endif %}>Sim</option>
              <option value="false" {% if not config.enable_google_login %}selected{% endif %}>Não</option>
            </select>
            <label>Google Client ID</label>
            <input type="text" name="google_client_id" value="{{ config.google_client_id }}">
            <label>Google Client Secret</label>
            <input type="text" name="google_client_secret" value="{{ config.google_client_secret }}">
            <label>Cloudflare API Token</label>
            <input type="text" name="cloudflare_api_token" value="{{ config.cloudflare_api_token }}">
            <label>Cloudflare Zone ID</label>
            <input type="text" name="cloudflare_zone_id" value="{{ config.cloudflare_zone_id }}">
            <button type="submit" class="primary">Salvar configurações</button>
          </form>
        </div>
        <div>
          <h2>Relatório</h2>
          <p>IPs registrados: <strong>{{ ip_count }}</strong></p>
          <p>Usuários ativos: <strong>{{ active_count }}</strong></p>
          <p>Fila de reprodução: <strong>{{ queue|length }}</strong></p>
          <p>Última atualização: <strong>{{ status.last_update or '---' }}</strong></p>
        </div>
      </div>
    </div>
  </div>
</body>
</html>'''

MONITOR_TEMPLATE = '''---
'''

STATUS_TEMPLATE = ''''''

PAYMENTS_TEMPLATE = ''''''


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

    users = load_json(DATA_FILE, {})
    if 'admin' not in users:
        users['admin'] = {'password': 'admin123', 'role': 'admin', 'credits': 100, 'banned': False}
        write_json(DATA_FILE, users)

    load_json(PAYMENTS_FILE, [])
    load_json(IP_LOG_FILE, [])
    load_json(STATUS_FILE, DEFAULT_STATUS)
    if not os.path.exists(LOG_FILE):
        open(LOG_FILE, 'a', encoding='utf-8').close()


class SafeUser:
    def __init__(self, name, data):
        self.name = name
        self.role = data.get('role', 'user')
        self.credits = data.get('credits', 0)
        self.banned = data.get('banned', False)


ensure_files()
config = load_json(CONFIG_FILE, DEFAULT_CONFIG)
app.secret_key = config.get('secret_key', DEFAULT_CONFIG['secret_key'])

oauth = OAuth(app)
if config.get('google_client_id') and config.get('google_client_secret'):
    oauth.register(
        name='google',
        client_id=config.get('google_client_id'),
        client_secret=config.get('google_client_secret'),
        access_token_url='https://oauth2.googleapis.com/token',
        access_token_params=None,
        authorize_url='https://accounts.google.com/o/oauth2/v2/auth',
        authorize_params=None,
        api_base_url='https://www.googleapis.com/oauth2/v1/',
        client_kwargs={'scope': 'openid email profile'},
    )

server_status = load_json(STATUS_FILE, DEFAULT_STATUS)
queue = server_status.get('queue', [])


def save_status():
    with status_lock:
        server_status['queue'] = queue
        server_status['last_update'] = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')
        write_json(STATUS_FILE, server_status)


def write_log(message):
    timestamp = datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S')
    line = f'[{timestamp}] {message}'
    with open(LOG_FILE, 'a', encoding='utf-8') as handle:
        handle.write(line + '\n')

    server_status.setdefault('recent_events', []).insert(0, line)
    server_status['recent_events'] = server_status['recent_events'][:12]
    save_status()


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


def get_client_ip():
    if request.headers.get('X-Forwarded-For'):
        return request.headers.get('X-Forwarded-For').split(',')[0].strip()
    return request.remote_addr or '127.0.0.1'


def is_banned(username):
    users = load_users()
    user = users.get(username)
    return bool(user and user.get('banned', False))


def add_active_user(username):
    active = set(server_status.get('active_users', []))
    active.add(username)
    server_status['active_users'] = list(active)
    save_status()


def remove_active_user(username):
    active = set(server_status.get('active_users', []))
    active.discard(username)
    server_status['active_users'] = list(active)
    save_status()


def resolve_youtube_stream(url):
    try:
        ydl_opts = {'format': 'bestaudio/best', 'quiet': True, 'no_warnings': True, 'skip_download': True}
        with YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
      title = info.get('title', url)
            stream = info.get('url')
            if not stream and info.get('formats'):
                stream = info['formats'][-1].get('url')
      # If API key is present, try to fetch nicer title via YouTube Data API
      try:
        api_key = config.get('youtube_api_key')
        if api_key and ('youtube.com' in url or 'youtu.be' in url):
          # extract video id
          vid = None
          if 'v=' in url:
            vid = url.split('v=')[1].split('&')[0]
          elif 'youtu.be/' in url:
            vid = url.split('youtu.be/')[1].split('?')[0]
          if vid:
            import urllib.request as _urlreq
            import urllib.parse as _parse
            api_url = f'https://www.googleapis.com/youtube/v3/videos?part=snippet&id={_parse.quote(vid)}&key={_parse.quote(api_key)}'
            try:
              with _urlreq.urlopen(api_url, timeout=5) as resp:
                resp_data = resp.read().decode('utf-8')
                js = json.loads(resp_data)
                items = js.get('items', [])
                if items:
                  title = items[0].get('snippet', {}).get('title') or title
            except Exception:
              pass
      except Exception:
        pass
            return stream, title
    except Exception as exc:
        write_log(f'Falha ao resolver YouTube: {exc}')
        return None, None


def playback_worker():
    global player_process
    while queue:
        track = queue.pop(0)
        save_status()
        write_log(f"Iniciando reprodução: {track['url']} solicitado por {track['requestor']}")
        stream_url, title = resolve_youtube_stream(track['url'])
        if not stream_url:
            write_log('Falha ao obter stream do YouTube, pulando faixa.')
            continue
        current = {
            'title': title,
            'url': track['url'],
            'requestor': track['requestor'],
            'status': 'playing',
            'started_at': datetime.utcnow().isoformat(),
        }
        server_status['current'] = current
        save_status()
        try:
            player_process = subprocess.Popen([
                'mpv',
                '--no-video',
                '--really-quiet',
                '--audio-display=no',
                '--volume=72',
                stream_url,
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            player_process.wait()
            write_log(f'Faixa finalizada: {title}')
        except FileNotFoundError:
            write_log('mpv não encontrado. Instale mpv para tocar áudio.')
            server_status['current']['status'] = 'error'
            break
        except Exception as exc:
            write_log(f'Erro durante reprodução: {exc}')
            server_status['current']['status'] = 'error'
            break

    server_status['current'] = None
    save_status()


def enqueue_track(url, requestor):
    if not url:
        return False
    if not url.startswith('http'):
        url = 'https://' + url
    title = url
    track = {'id': str(uuid4()), 'url': url, 'title': title, 'requestor': requestor}
    queue.append(track)
    server_status['queue'] = queue
    save_status()
    write_log(f'Nova música adicionada: {url} por {requestor}')
    return True


def start_playback():
    global playback_thread
    if playback_thread and playback_thread.is_alive():
        return
    if not queue:
        return
    playback_thread = threading.Thread(target=playback_worker, daemon=True)
    playback_thread.start()


def login_required(view):
    def wrapped(*args, **kwargs):
        if session.get('username') is None:
            return redirect(url_for('login'))
        return view(*args, **kwargs)
    wrapped.__name__ = view.__name__
    return wrapped


def admin_required(view):
    def wrapped(*args, **kwargs):
        if session.get('role') != 'admin':
            flash('Acesso negado.')
            return redirect(url_for('dashboard'))
        return view(*args, **kwargs)
    wrapped.__name__ = view.__name__
    return wrapped


@app.route('/')
def home():
    if session.get('username'):
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))


@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        users = load_users()
        user = users.get(username)
        if not user or user.get('password') != password:
            error = 'Usuário ou senha inválidos.'
        elif user.get('banned'):
            error = 'Conta banida. Entre em contato com o administrador.'
        else:
            session['username'] = username
            session['role'] = user.get('role', 'user')
            add_active_user(username)
            record_ip(username, get_client_ip())
            write_log(f'Login: {username} ({get_client_ip()})')
            return redirect(url_for('dashboard'))

    return render_template_string(
        LOGIN_TEMPLATE,
        error=error,
        messages=get_flashed_messages(),
        google_enabled=bool(config.get('google_client_id') and config.get('google_client_secret') and config.get('enable_google_login')),
    )


@app.route('/login/google')
def google_login():
    if not (config.get('google_client_id') and config.get('google_client_secret') and config.get('enable_google_login')):
        flash('Login com Google não está habilitado.')
        return redirect(url_for('login'))
    redirect_uri = url_for('google_callback', _external=True)
    return oauth.google.authorize_redirect(redirect_uri)


@app.route('/login/google/callback')
def google_callback():
    token = oauth.google.authorize_access_token()
    user_info = oauth.google.get('userinfo').json()
    if not user_info or not user_info.get('email'):
        flash('Não foi possível obter dados do Google.')
        return redirect(url_for('login'))
    username = create_google_user(user_info)
    if not username:
        flash('Falha ao criar usuário Google.')
        return redirect(url_for('login'))
    session['username'] = username
    session['role'] = load_users().get(username, {}).get('role', 'user')
    add_active_user(username)
    record_ip(username, get_client_ip())
    write_log(f'Login Google: {username} ({get_client_ip()})')
    return redirect(url_for('dashboard'))


@app.route('/git-update', methods=['POST'])
@login_required
@admin_required
def git_update():
    success, message = pull_from_git()
    flash('Atualização do Git concluída.' if success else f'Falha na atualização do Git: {message}')
    return redirect(url_for('admin'))


@app.route('/dashboard')
@login_required
def dashboard():
    users = load_users()
    user = users.get(session['username'], {})
    current = server_status.get('current')
    return render_template_string(
        DASHBOARD_TEMPLATE,
        title=config.get('panel_title'),
        accent=config.get('theme_accent'),
        second=config.get('theme_second'),
        bg=config.get('theme_bg'),
        username=session['username'],
        role=session.get('role'),
        credits=user.get('credits', 0),
        current=current,
        queue=server_status.get('queue', []),
        active_count=len(server_status.get('active_users', [])),
        last_update=server_status.get('last_update'),
        background_music=config.get('background_music'),
        client_ip=get_client_ip(),
    )


@app.route('/play', methods=['POST'])
@login_required
def play():
    youtube_url = request.form.get('youtube_url', '').strip()
    if not youtube_url:
        flash('Cole um link do YouTube para reproduzir.')
        return redirect(url_for('dashboard'))

    if enqueue_track(youtube_url, session['username']):
        flash('Música adicionada à fila. Aguarde o início da reprodução.')
        start_playback()
    else:
        flash('Não foi possível adicionar a música.')
    return redirect(url_for('dashboard'))


@app.route('/admin')
@login_required
@admin_required
def admin():
    users = load_users()
    safe = {name: SafeUser(name, data) for name, data in users.items()}
    payments = load_payments()
    ip_log = load_json(IP_LOG_FILE, [])
    return render_template_string(
        ADMIN_TEMPLATE,
        title=config.get('panel_title'),
        accent=config.get('theme_accent'),
        second=config.get('theme_second'),
        bg=config.get('theme_bg'),
        users=safe,
        payments=payments,
        config=config,
        ip_count=len(ip_log),
        active_count=len(server_status.get('active_users', [])),
        queue=server_status.get('queue', []),
        status=server_status,
        error=None,
        messages=get_flashed_messages(),
    )


@app.route('/admin-action', methods=['POST'])
@login_required
@admin_required
def admin_action():
    action = request.form.get('action')
    users = load_users()

    if action == 'create_user':
        username = request.form.get('new_username', '').strip()
        password = request.form.get('new_password', '')
        role = request.form.get('new_role', 'user')
        if not username or not password:
            flash('Preencha todos os dados para criar um usuário.')
            return redirect(url_for('admin'))
        if username in users:
            flash('Usuário já existe.')
            return redirect(url_for('admin'))
      if role == 'admin' and not username.startswith('admin@'):
        flash('Para criar um administrador, o nome deve começar com "admin@" seguido do nome do usuário.')
        return redirect(url_for('admin'))
        users[username] = {
            'password': password,
            'role': role,
            'credits': 0,
            'banned': False,
        }
        save_users(users)
        write_log(f'Novo usuário criado: {username}')
        flash('Usuário criado com sucesso.')
        return redirect(url_for('admin'))

    if action == 'toggle_ban':
        target = request.form.get('target_user')
        if target in users and target != 'admin':
            users[target]['banned'] = not users[target].get('banned', False)
            save_users(users)
            write_log(f"Ban status alterado: {target} = {users[target]['banned']}")
            flash('Status de ban alterado.')
        else:
            flash('Não é possível alterar o admin ou usuário inválido.')
        return redirect(url_for('admin'))

    if action == 'grant_credits':
        target = request.form.get('target_user')
        amount = int(request.form.get('amount') or 0)
        if target in users and amount > 0:
            users[target]['credits'] = users[target].get('credits', 0) + amount
            save_users(users)
            write_log(f'Créditos adicionados: {amount} para {target}')
            flash('Créditos adicionados com sucesso.')
        else:
            flash('Erro ao adicionar créditos.')
        return redirect(url_for('admin'))

    if action == 'update_config':
        background_music = request.form.get('background_music', '').strip()
      background_image = request.form.get('background_image', '').strip()
        panel_title = request.form.get('panel_title', '').strip()
        enable_google_login = request.form.get('enable_google_login', 'false') == 'true'
        google_client_id = request.form.get('google_client_id', '').strip()
        google_client_secret = request.form.get('google_client_secret', '').strip()
      cloudflare_api_token = request.form.get('cloudflare_api_token', '').strip()
      cloudflare_zone_id = request.form.get('cloudflare_zone_id', '').strip()
        if background_music:
            config['background_music'] = background_music
      # if background image changed, attempt purge via Cloudflare
      prev_bg = config.get('background_image')
      if background_image:
        config['background_image'] = background_image
        if panel_title:
            config['panel_title'] = panel_title
        config['enable_google_login'] = enable_google_login
        config['google_client_id'] = google_client_id
        config['google_client_secret'] = google_client_secret
      if cloudflare_api_token:
        config['cloudflare_api_token'] = cloudflare_api_token
      if cloudflare_zone_id:
        config['cloudflare_zone_id'] = cloudflare_zone_id
        write_json(CONFIG_FILE, config)
        if enable_google_login and google_client_id and google_client_secret:
            oauth.register(
                name='google',
                client_id=google_client_id,
                client_secret=google_client_secret,
                access_token_url='https://oauth2.googleapis.com/token',
                access_token_params=None,
                authorize_url='https://accounts.google.com/o/oauth2/v2/auth',
                authorize_params=None,
                api_base_url='https://www.googleapis.com/oauth2/v1/',
                client_kwargs={'scope': 'openid email profile'},
            )
        write_log('Configurações atualizadas pelo administrador.')
        # If background image changed and Cloudflare configured, purge cache
        try:
          if background_image and prev_bg != background_image:
            success, resp = purge_cloudflare_cache([background_image])
            write_log(f'Cloudflare purge result: success={success} resp={resp}')
        except Exception as e:
          write_log(f'Erro ao purgar Cloudflare: {e}')
        flash('Configurações atualizadas.')
        return redirect(url_for('admin'))

    flash('Ação desconhecida.')
    return redirect(url_for('admin'))


@app.route('/buy-credits', methods=['POST'])
@login_required
def buy_credits():
    amount = int(request.form.get('amount') or 0)
    if amount <= 0:
        flash('Informe uma quantidade válida de créditos.')
        return redirect(url_for('admin') if session.get('role') == 'admin' else url_for('dashboard'))

    users = load_users()
    username = session['username']
    user = users.get(username)
    if user is None:
        flash('Usuário não encontrado.')
        return redirect(url_for('dashboard'))

    user['credits'] = user.get('credits', 0) + amount
    save_users(users)
    payments = load_payments()
    payments.append({
        'id': str(uuid4()),
        'user': username,
        'credits': amount,
        'timestamp': datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC'),
        'status': 'paid',
    })
    save_payments(payments)
    write_log(f'Créditos comprados: {amount} por {username}')
    flash(f'Você recebeu {amount} créditos com sucesso.')
    return redirect(url_for('dashboard'))


@app.route('/monitor')
def monitor_web():
    data = {
        'status': server_status,
        'logs': open(LOG_FILE, 'r', encoding='utf-8').read().splitlines()[-12:],
        'config': config,
    }
    return render_template_string('''<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Monitor Web</title>
  <style>
    body { margin:0; min-height:100vh; font-family: Inter, sans-serif; background: #020617; color:#f8fafc; }
    .page { width:min(1160px,96vw); margin:24px auto; }
    h1 { margin:0 0 14px; }
    .card { background: rgba(15,23,42,0.92); border:1px solid rgba(255,255,255,0.08); border-radius:24px; padding:24px; margin-bottom:18px; }
    .grid { display:grid; grid-template-columns:1fr 1fr; gap:18px; }
    pre { margin:0; white-space:pre-wrap; word-break:break-word; font-family:monospace; }
    .tag { display:inline-block; padding:8px 14px; border-radius:999px; background:rgba(124,58,237,0.16); color:#c4b5fd; }
  </style>
</head>
<body>
  <div class="page">
    <h1>Monitor Web</h1>
    <div class="card grid">
      <div>
        <h2>Status de reprodução</h2>
        {% if status.current %}
          <p><strong>{{ status.current.title }}</strong></p>
          <p>Status: <span class="tag">{{ status.current.status }}</span></p>
          <p>Pedido por: {{ status.current.requestor }}</p>
        {% else %}
          <p>Nenhuma reprodução ativa.</p>
        {% endif %}
      </div>
      <div>
        <h2>Fila e usuários</h2>
        <p>Fila atual: <strong>{{ status.queue|length }}</strong></p>
        <p>Usuários ativos: <strong>{{ status.active_users|length }}</strong></p>
        <p>Última atualização: <strong>{{ status.last_update or '---' }}</strong></p>
      </div>
    </div>
    <div class="card">
      <h2>Eventos recentes</h2>
      <pre>{{ status.recent_events|join('\n') }}</pre>
    </div>
    <div class="card">
      <h2>Logs</h2>
      <pre>{{ logs|join('\n') }}</pre>
    </div>
  </div>
</body>
</html>''', **data)


@app.route('/logout')
@login_required
def logout():
    username = session.get('username')
    session.clear()
    remove_active_user(username)
    return redirect(url_for('login'))


if __name__ == '__main__':
    ensure_files()
    config = load_json(CONFIG_FILE, DEFAULT_CONFIG)
    app.secret_key = config.get('secret_key', DEFAULT_CONFIG['secret_key'])
    if config.get('auto_update_on_start'):
        success, message = pull_from_git()
        if success:
            write_log('Atualização automática do Git concluída.')
        else:
            write_log(f'Falha na atualização automática do Git: {message}')
    server_status.update(load_json(STATUS_FILE, DEFAULT_STATUS))
    queue[:] = server_status.get('queue', [])
    save_status()
    app.run(host='0.0.0.0', port=5000, debug=False)
