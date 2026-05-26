# routes/dashboard.py

from flask import Blueprint, render_template, session, redirect, url_for, get_flashed_messages, flash

from utils import load_users, load_json, STATUS_FILE, write_log
from config import AppConfig

dashboard_bp = Blueprint(
    'dashboard_bp',
    __name__,
    template_folder='../templates'
)

# --- Helper Functions ---

def get_client_ip():
    from flask import request
    if request.headers.get('X-Forwarded-For'):
        return request.headers.get('X-Forwarded-For').split(',')[0].strip()
    return request.remote_addr or '127.0.0.1'

# --- Routes ---

@dashboard_bp.route('/dashboard')
def dashboard():
    if not session.get('username'):
        return redirect(url_for('auth_bp.login'))

    user_data = load_users().get(session['username'], {})
    server_status = load_json(STATUS_FILE, default={})

    # Calculate required XP and percentage
    level = user_data.get('level', 1)
    current_xp = user_data.get('xp', 0)
    required_xp = 100 * (level ** 2)
    xp_percentage = (current_xp / required_xp) * 100 if required_xp > 0 else 0

    user = {
        'username': session['username'],
        'role': session.get('role'),
        'credits': user_data.get('credits', 0),
        'gold': user_data.get('gold', 0),
        'level': level,
        'xp': current_xp,
        'required_xp': required_xp,
        'xp_percentage': xp_percentage
    }

    return render_template(
        'dashboard.html',
        panel_title=AppConfig.get('panel_title'),
        background_image=AppConfig.get('background_image'),
        user=user,
        current=server_status.get('current'),
        queue=server_status.get('queue', []),
        active_count=len(server_status.get('active_users', [])),
        last_update=server_status.get('last_update'),
        background_music=AppConfig.get('background_music'),
        client_ip=get_client_ip(),
        messages=get_flashed_messages(),
    )

@dashboard_bp.route('/apply-for-staff', methods=['POST'])
def apply_for_staff():
    username = session.get('username')
    if not username:
        return redirect(url_for('auth_bp.login'))

    write_log(f"STAFF APPLICATION: User '{username}' applied for a staff position.")

    flash(
        'Obrigado pelo seu interesse! Sua solicitação foi registrada. Para agilizar, envie uma mensagem para +5511951289502.',
        'info'
    )
    return redirect(url_for('.dashboard'))
