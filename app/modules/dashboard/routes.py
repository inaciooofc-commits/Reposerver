from flask import Blueprint, render_template, current_app

dashboard_bp = Blueprint(
    'dashboard',
    __name__,
    url_prefix='/dashboard',
    template_folder='templates',
    static_folder='static'
)

@dashboard_bp.route('/')
@dashboard_bp.route('/<page>')
def dashboard(page=None):
    """Serve a página principal do hub do usuário (o shell)."""
    if not page:
        page = 'player'  # O player será a página padrão
    return render_template("dashboard.html", title="User Dashboard", page=page)

@dashboard_bp.route('/components/<component_name>')
def load_component(component_name: str):
    """Carrega dinamicamente os componentes do hub do usuário para o HTMX."""
    try:
        template_path = f'components/{component_name}.html'
        return render_template(template_path)
    except Exception as e:
        current_app.logger.error(f"Componente do dashboard '{component_name}' não encontrado: {e}")
        return f'<div class="error-message">Erro: Componente \'{component_name}\' não encontrado.</div>', 404
