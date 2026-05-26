# routes/auth.py

import os
from flask import (
    Blueprint, flash, get_flashed_messages, redirect, render_template, request, session, url_for, current_app
)
from werkzeug.security import generate_password_hash, check_password_hash

from utils import (
    load_users,
    save_users,
    write_log,
    record_ip,
    create_google_user,
    add_active_user,
    remove_active_user,
)
from config import AppConfig

# Create a Blueprint
auth_bp = Blueprint(
    'auth_bp',
    __name__,
    template_folder='../templates', # Point to the main templates folder
    static_folder='../static' # Point to the main static folder
)

# --- Helper Functions (specific to auth) ---

def get_client_ip():
    """Gets the client IP address from the request."""
    if request.headers.get('X-Forwarded-For'):
        return request.headers.get('X-Forwarded-For').split(',')[0].strip()
    return request.remote_addr or '127.0.0.1'

# --- Core Authentication Routes ---

@auth_bp.route('/setup', methods=['GET', 'POST'])
def setup():
    if load_users(): # If users exist, setup is done
        return redirect(url_for('.login'))
    
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        confirm_password = request.form.get('confirm_password', '')
        if not username or not password or not confirm_password:
            flash('Preencha todos os campos.', 'warning')
        elif password != confirm_password:
            flash('As senhas não coincidem.', 'warning')
        else:
            users = {
                username: {
                    'password': generate_password_hash(password),
                    'role': 'admin',
                    'credits': 999,
                    'banned': False,
                }
            }
            save_users(users)
            write_log(f'Administrador inicial criado: {username}')
            flash('Conta de administrador criada. Faça o login.', 'success')
            return redirect(url_for('.login'))

    return render_template('setup.html', messages=get_flashed_messages())

@auth_bp.route('/')
def home():
    if session.get('username'):
        return redirect(url_for('dashboard_bp.dashboard'))
    return redirect(url_for('.login'))

@auth_bp.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username', '').strip()
        password = request.form.get('password', '')
        users = load_users()
        user = users.get(username)

        if not user:
            flash('Usuário ou senha inválidos.', 'danger')
            return redirect(url_for('.login'))

        stored_password = user.get('password', '')
        is_hashed = '$' in stored_password
        password_ok = check_password_hash(stored_password, password) if is_hashed else (stored_password == password)

        if user and not user.get('banned') and password_ok:
            if not is_hashed:
                user['password'] = generate_password_hash(password)
                save_users(users)
                write_log(f'Senha para {username} atualizada para hash.')

            session['username'] = username
            session['role'] = user.get('role', 'user')
            add_active_user(username)
            record_ip(username, get_client_ip())
            write_log(f'Login: {username} ({get_client_ip()})')
            return redirect(url_for('dashboard_bp.dashboard')) # Redirect to the dashboard blueprint
        elif user and user.get('banned'):
            flash('Conta banida. Entre em contato com o administrador.', 'danger')
        else:
            flash('Usuário ou senha inválidos.', 'danger')

    return render_template(
        'login.html',
        messages=get_flashed_messages(),
        google_enabled=AppConfig.get('enable_google_login')
    )

@auth_bp.route('/logout')
def logout():
    username = session.get('username')
    if username:
        remove_active_user(username)
    session.clear()
    flash('Você saiu da sua conta.', 'info')
    return redirect(url_for('.login'))

# --- Google OAuth Routes ---

@auth_bp.route('/login/google')
def google_login():
    if not AppConfig.get('enable_google_login'):
        flash('Login com Google não está habilitado.', 'warning')
        return redirect(url_for('.login'))
    
    # The oauth object is retrieved from the application context
    oauth = current_app.extensions['authlib.integrations.flask_client']
    redirect_uri = url_for('.google_callback', _external=True)
    return oauth.google.authorize_redirect(redirect_uri)

@auth_bp.route('/login/google/callback')
def google_callback():
    try:
        oauth = current_app.extensions['authlib.integrations.flask_client']
        token = oauth.google.authorize_access_token()
        user_info = oauth.google.get('userinfo').json()
    except Exception as e:
        flash(f'Falha na autenticação com Google: {e}', 'danger')
        return redirect(url_for('.login'))

    if not user_info or not user_info.get('email'):
        flash('Não foi possível obter dados do Google.', 'danger')
        return redirect(url_for('.login'))
    
    username = create_google_user(user_info)
    if not username:
        flash('Falha ao criar usuário Google.', 'danger')
        return redirect(url_for('.login'))

    user_data = load_users().get(username, {})
    session['username'] = username
    session['role'] = user_data.get('role', 'user')
    add_active_user(username)
    record_ip(username, get_client_ip())
    write_log(f'Login Google: {username} ({get_client_ip()})')
    return redirect(url_for('dashboard_bp.dashboard')) # Redirect to the dashboard blueprint
