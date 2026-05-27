# app/modules/custom_endpoints/routes.py
from flask import Blueprint, jsonify
from .services import obter_status_api

# Cria um "Blueprint". Pense nisso como um mini-app ou um grupo de rotas relacionadas.
custom_endpoints_bp = Blueprint(
    'custom_endpoints_bp',
    __name__,
    url_prefix='/api/custom' # Todas as rotas neste arquivo começarão com /api/custom
)

@custom_endpoints_bp.route('/status', methods=['GET'])
def rota_status():
    """Endpoint de verificação de saúde (health check)."""
    dados = obter_status_api()
    return jsonify(dados)
