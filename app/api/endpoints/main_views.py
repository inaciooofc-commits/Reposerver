# -*- coding: utf-8 -*-

from flask import Blueprint, render_template, current_app

# O Blueprint 'main_bp' servirá as rotas principais e os componentes da UI.
main_bp = Blueprint('main', __name__, template_folder='../../../frontend/templates')

@main_bp.route('/')
def index():
    """Serve a página principal (o shell da aplicação)."""
    return render_template('index.html')

@main_bp.route('/components/<component_name>')
def load_component(component_name: str):
    """Carrega e serve dinamicamente os componentes HTML para o HTMX."""
    try:
        # Constrói o caminho para o template do componente de forma segura
        template_path = f'components/{component_name}.html'
        return render_template(template_path)
    except Exception as e:
        current_app.logger.error(f"Componente '{component_name}' não encontrado: {e}")
        # Retorna um erro 404 para o HTMX, que pode ser tratado no frontend.
        return f'<div class="text-red-500">Erro: Componente \'{component_name}\' não encontrado.</div>', 404

