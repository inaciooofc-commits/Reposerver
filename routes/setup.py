# routes/setup.py

from flask import Blueprint, render_template, request, flash, redirect, url_for, session
from config import AppConfig

setup_bp = Blueprint(
    'setup_bp',
    __name__,
    template_folder='../templates'
)

@setup_bp.route('/setup', methods=['GET', 'POST'])
def setup():
    """Handles the initial registration of the application."""
    # If already registered, redirect away from setup
    if AppConfig.get('is_registered'):
        return redirect(url_for('auth_bp.login'))

    if request.method == 'POST':
        submitted_key = request.form.get('master_key')
        master_key = AppConfig.get('master_key')

        if submitted_key == master_key:
            # Correct key, update config and redirect to login
            AppConfig.set('is_registered', True)
            flash('Aplicação registrada com sucesso! Faça o login para continuar.', 'success')
            return redirect(url_for('auth_bp.login'))
        else:
            # Incorrect key, flash error and re-render setup page
            flash('Chave mestra inválida. Tente novamente.', 'danger')

    # Render the setup page for GET requests or after a failed POST
    return render_template(
        'setup.html',
        panel_title=AppConfig.get('panel_title'),
        background_image=AppConfig.get('background_image'),
    )


def register_setup_routes(app):
    """Registers the setup blueprint and a before_request handler."""
    app.register_blueprint(setup_bp)

    @app.before_request
    def check_registration():
        # Allow access to setup and static assets if not registered
        if not AppConfig.get('is_registered'):
            if request.endpoint and request.endpoint not in ['setup_bp.setup', 'static']:
                return redirect(url_for('setup_bp.setup'))
