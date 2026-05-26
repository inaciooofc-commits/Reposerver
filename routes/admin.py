# routes/admin.py

from flask import (
    Blueprint, render_template, request, redirect, url_for, flash, session, get_flashed_messages
)
from werkzeug.security import generate_password_hash

# Centralized decorators
from .decorators import login_required, admin_required

from utils import (
    load_users, save_users, load_payments, write_log, write_json, load_json, IP_LOG_FILE, STATUS_FILE, CONFIG_FILE, pull_from_git, purge_cloudflare_cache
)
from config import AppConfig

admin_bp = Blueprint(
    'admin_bp',
    __name__,
    template_folder='../templates'
)

# --- Read-only User Class for Templates ---

class SafeUser:
    def __init__(self, name, data):
        self.name = name
        self.role = data.get('role', 'user')
        self.credits = data.get('credits', 0)
        self.banned = data.get('banned', False)

# --- Admin Panel Route ---

@admin_bp.route('/admin')
@login_required
@admin_required
def admin():
    users = load_users()
    safe_users = {name: SafeUser(name, data) for name, data in users.items()}
    server_status = load_json(STATUS_FILE, default={})
    
    return render_template(
        'admin.html',
        title=AppConfig.get('panel_title'),
        accent=AppConfig.get('theme_accent'),
        second=AppConfig.get('theme_second'),
        bg=AppConfig.get('theme_bg'),
        users=safe_users,
        payments=load_payments(),
        config=AppConfig, # Pass the entire config object
        ip_count=len(load_json(IP_LOG_FILE, [])),
        active_count=len(server_status.get('active_users', [])),
        queue=server_status.get('queue', []),
        status=server_status,
        messages=get_flashed_messages(),
    )

# --- Admin Action Handlers ---

def handle_admin_action_create_user(form, users):
    username = form.get('new_username', '').strip()
    password = form.get('new_password', '')
    role = form.get('new_role', 'user')
    if not username or not password:
        flash('Preencha nome de usuário e senha para criar.', 'warning')
        return
    if username in users:
        flash('Usuário já existe.', 'warning')
        return
    if role == 'admin' and not username.startswith('admin@'):
        flash('Admins devem começar com "admin@".', 'warning')
        return

    users[username] = {'password': generate_password_hash(password), 'role': role, 'credits': 0, 'banned': False}
    save_users(users)
    write_log(f'Novo usuário criado: {username} por {session.get("username")}')
    flash('Usuário criado com sucesso.', 'success')

def handle_admin_action_toggle_ban(form, users):
    target_user = form.get('target_user')
    if target_user in users and users[target_user].get('role') != 'admin':
        users[target_user]['banned'] = not users[target_user].get('banned', False)
        save_users(users)
        status = "banido" if users[target_user]['banned'] else "desbanido"
        write_log(f'{target_user} foi {status} por {session.get("username")}')
        flash(f'Status de ban para {target_user} alterado.', 'success')
    else:
        flash('Não é possível banir um admin ou o usuário não existe.', 'danger')

def handle_admin_action_grant_credits(form, users):
    target_user = form.get('target_user')
    try:
        amount = int(form.get('amount') or 0)
    except (ValueError, TypeError):
        flash('Quantidade de créditos inválida.', 'danger')
        return

    if target_user in users and amount > 0:
        users[target_user]['credits'] = users[target_user].get('credits', 0) + amount
        save_users(users)
        write_log(f'{amount} créditos adicionados para {target_user} por {session.get("username")}')
        flash('Créditos adicionados.', 'success')
    else:
        flash('Erro ao adicionar créditos. Verifique o usuário e o valor.', 'danger')

def handle_admin_action_update_config(form):
    current_config = load_json(CONFIG_FILE, AppConfig)
    prev_bg = current_config.get('background_image')

    # Update config from form
    current_config.update({
        'background_music': form.get('background_music', '').strip(),
        'background_image': form.get('background_image', '').strip(),
        'panel_title': form.get('panel_title', '').strip() or 'Anime Pulse Server',
        'enable_google_login': form.get('enable_google_login') == 'true',
        'google_client_id': form.get('google_client_id', '').strip(),
        'google_client_secret': form.get('google_client_secret', '').strip(),
        'cloudflare_api_token': form.get('cloudflare_api_token', '').strip(),
        'cloudflare_zone_id': form.get('cloudflare_zone_id', '').strip(),
    })

    write_json(CONFIG_FILE, current_config)
    write_log(f'Configurações atualizadas por {session.get("username")}')

    new_bg = current_config.get('background_image')
    if new_bg and prev_bg != new_bg and current_config.get('cloudflare_api_token'):
        success, resp = purge_cloudflare_cache([new_bg])
        if success:
            flash('Cache do Cloudflare purgado para a nova imagem de fundo.', 'info')
        else:
            flash(f'Erro ao purgar cache do Cloudflare: {resp}', 'danger')

    flash('Configurações atualizadas. Pode ser necessário reiniciar.', 'success')

def handle_admin_action_git_update():
    success, message = pull_from_git()
    if success:
        flash('Atualização do Git concluída. Reinicie para aplicar.', 'success')
    else:
        flash(f'Falha na atualização do Git: {message}', 'danger')


@admin_bp.route('/admin-action', methods=['POST'])
@login_required
@admin_required
def admin_action():
    action = request.form.get('action')
    users = load_users()

    action_handlers = {
        'create_user': lambda: handle_admin_action_create_user(request.form, users),
        'toggle_ban': lambda: handle_admin_action_toggle_ban(request.form, users),
        'grant_credits': lambda: handle_admin_action_grant_credits(request.form, users),
        'update_config': lambda: handle_admin_action_update_config(request.form),
        'git_update': handle_admin_action_git_update # No args needed
    }

    handler = action_handlers.get(action)
    if handler:
        handler()
    else:
        flash('Ação desconhecida.', 'danger')

    return redirect(url_for('.admin'))
