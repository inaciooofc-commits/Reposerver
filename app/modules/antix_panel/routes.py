from flask import Blueprint, render_template, current_app

# O Blueprint para o painel foi movido para cá para ser mais explícito
antix_panel_bp = Blueprint(
    'antix_panel',
    __name__,
    url_prefix='/antix',  # Todas as rotas aqui começarão com /antix
    template_folder='templates',
    static_folder='static'
)

@antix_panel_bp.route('/')
def dashboard():
    """Serve a página principal do painel (o shell)."""
    return render_template("antix_panel.html", title="Anti X Dashboard")

@antix_panel_bp.route('/components/<component_name>')
def load_component(component_name: str):
    """Carrega dinamicamente os componentes do painel para o HTMX."""
    try:
        template_path = f'components/{component_name}.html'
        return render_template(template_path)
    except Exception as e:
        current_app.logger.error(f"Componente do painel '{component_name}' não encontrado: {e}")
        return f'<div class="text-red-500">Erro: Componente do painel \'{component_name}\' não encontrado.</div>', 404
