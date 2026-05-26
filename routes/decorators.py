# routes/decorators.py

from functools import wraps
from flask import session, redirect, url_for, flash

def login_required(view):
    """Decorator to ensure the user is logged in."""
    @wraps(view)
    def wrapped_view(*args, **kwargs):
        if 'username' not in session:
            flash('Você precisa fazer login para acessar esta página.', 'warning')
            return redirect(url_for('auth_bp.login'))
        return view(*args, **kwargs)
    return wrapped_view

def admin_required(view):
    """Decorator to ensure the user is an administrator."""
    @wraps(view)
    def wrapped_view(*args, **kwargs):
        if session.get('role') != 'admin':
            flash('Acesso negado. Esta área é apenas para administradores.', 'danger')
            return redirect(url_for('dashboard_bp.dashboard'))
        return view(*args, **kwargs)
    return wrapped_vie