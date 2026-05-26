# routes/api.py

import json
from uuid import uuid4
from datetime import datetime, timezone
from flask import Blueprint, request, redirect, url_for, flash, session

from utils import (
    save_users, load_users, save_payments, load_payments, write_log, write_central, 
    enqueue_track, start_playback_if_needed
)

# Centralized decorators
from .decorators import login_required, admin_required

api_bp = Blueprint('api_bp', __name__)


@api_bp.route('/play', methods=['POST'])
@login_required
def play():
    youtube_url = request.form.get('youtube_url', '').strip()
    if not youtube_url:
        flash('Cole um link do YouTube para reproduzir.', 'warning')
    # Use the refactored enqueue and start functions
    elif enqueue_track(youtube_url, session['username']):
        flash('Música adicionada à fila.', 'success')
        start_playback_if_needed()
    else:
        flash('Não foi possível adicionar a música. Verifique o link.', 'danger')
    return redirect(url_for('dashboard_bp.dashboard'))


@api_bp.route('/buy-credits', methods=['POST'])
@login_required
def buy_credits():
    try:
        amount = int(request.form.get('amount') or 0)
    except (ValueError, TypeError):
        flash('Quantidade inválida.', 'danger')
        return redirect(url_for('dashboard_bp.dashboard'))

    if amount <= 0:
        flash('Informe uma quantidade válida de créditos.', 'warning')
        return redirect(url_for('dashboard_bp.dashboard'))

    users = load_users()
    username = session['username']
    
    # Placeholder for payment integration
    users[username]['credits'] = users[username].get('credits', 0) + amount
    save_users(users)
    
    payments = load_payments()
    payments.append({
        'id': str(uuid4()),
        'user': username,
        'credits': amount,
        'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC'),
        'status': 'paid', # Mock status
    })
    save_payments(payments)
    
    write_log(f'Créditos comprados: {amount} por {username}')
    flash(f'Você recebeu {amount} créditos com sucesso.', 'success')
    return redirect(url_for('dashboard_bp.dashboard'))


@api_bp.route('/bot-command', methods=['POST'])
@login_required
@admin_required
def bot_command():
    payload = request.get_json() or {}
    try:
        import urllib.request
        data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request('http://127.0.0.1:6000/command', data=data, method='POST')
        req.add_header('Content-Type', 'application/json')
        with urllib.request.urlopen(req, timeout=5) as resp:
            resp_data = resp.read().decode('utf-8')
            write_central(f'bot_command by {session.get("username")} payload={payload} resp={resp_data}')
            return resp_data
    except Exception as exc:
        write_log(f'Erro ao enviar comando ao bot: {exc}')
        return {'ok': False, 'error': str(exc)}, 500
