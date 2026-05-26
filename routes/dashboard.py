# routes/dashboard.py

from flask import Blueprint, render_template, session, redirect, url_for, get_flashed_messages

from utils import load_users, load_json, STATUS_FILE
from config import AppConfig

dashboard_bp = Blueprint(
    'dashboard_bp',
    __name__,
    template_folder='../templates'
)

# --- Helper Functions ---

def get_client_ip():
    # This is a simplified version. A more robust implementation might be needed.
    # For now, we are repeating it here for simplicity.
    from flask import request
    if request.headers.get('X-Forwarded-For'):
        return request.headers.get('X-Forwarded-For').split(',')[0].strip()
    return request.remote_addr or '127.0.0.1'

# --- Dashboard Route ---

@dashboard_bp.route('/dashboard')
def dashboard():
    if not session.get('username'):
        return redirect(url_for('auth_bp.login'))

    user = load_users().get(session['username'], {})
    server_status = load_json(STATUS_FILE, default={}) # Ensure we have a default

    return render_template(
        'dashboard.html',
        title=AppConfig.get('panel_title'),
        accent=AppConfig.get('theme_accent'),
        second=AppConfig.get('theme_second'),
        bg=AppConfig.get('theme_bg'),
        username=session['username'],
        role=session.get('role'),
        credits=user.get('credits', 0),
        current=server_status.get('current'),
        queue=server_status.get('queue', []),
        active_count=len(server_status.get('active_users', [])),
        last_update=server_status.get('last_update'),
        background_music=AppConfig.get('background_music'),
        client_ip=get_client_ip(),
        messages=get_flashed_messages(),
    )
